import SwiftUI

@MainActor
class HabitsViewLogic: ObservableObject {

    // MARK: - Helper Methods

    func checkAndHandleHabitSelection(_ habit: Habit, viewModel: HabitViewModel, aiTaskViewModel: AITaskViewModel, state: HabitsViewState? = nil) async {
        // Don't automatically show motivation/ability modal anymore
        // Just check for existing entries and tasks
        if viewModel.isTodayIntervalDay(for: habit) && isValidationTimeReached(for: habit) {
            let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
            let ability = await viewModel.getTodayAbilityEntry(for: habit.id)

            // Store the entries for display without showing modal
            viewModel.todayMotivation = motivation
            viewModel.todayAbility = ability
        }

        // Always check for today's task
        await checkTodayTask(for: habit, aiTaskViewModel: aiTaskViewModel, state: state)
    }

    func isValidationTimeReached(for habit: Habit) -> Bool {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let validationTime = formatter.date(from: habit.validationTime) else {
            return true // If we can't parse, assume it's time
        }

        let now = Date()
        let calendar = Calendar.current

        // Create today's validation time
        let todayValidation = calendar.date(bySettingHour: calendar.component(.hour, from: validationTime),
                                          minute: calendar.component(.minute, from: validationTime),
                                          second: 0,
                                          of: now) ?? now

        return now >= todayValidation
    }

    func timeUntilValidation(for habit: Habit) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let validationTime = formatter.date(from: habit.validationTime) else {
            return "Soon"
        }

        let now = Date()
        let calendar = Calendar.current

        // Create today's validation time
        let todayValidation = calendar.date(bySettingHour: calendar.component(.hour, from: validationTime),
                                          minute: calendar.component(.minute, from: validationTime),
                                          second: 0,
                                          of: now) ?? now

        let timeInterval = todayValidation.timeIntervalSince(now)

        if timeInterval <= 0 {
            return "Now"
        }

        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func checkTodayTask(for habit: Habit, aiTaskViewModel: AITaskViewModel, state: HabitsViewState? = nil) async {
        do {
            let task = try await aiTaskViewModel.checkTodayTask(for: habit)
            aiTaskViewModel.currentTask = task
        } catch {
            // Task not found or error - this is expected for new habits
            aiTaskViewModel.currentTask = nil
        }
    }

    func refreshMotivationAbilityEntries(for habit: Habit, viewModel: HabitViewModel) async {
        let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
        let ability = await viewModel.getTodayAbilityEntry(for: habit.id)

        viewModel.todayMotivation = motivation
        viewModel.todayAbility = ability
    }

    func refreshData(viewModel: HabitViewModel, aiTaskViewModel: AITaskViewModel, state: HabitsViewState? = nil) async {
        await viewModel.fetchHabits()
        if let habit = viewModel.selectedHabit {
            await checkAndHandleHabitSelection(habit, viewModel: viewModel, aiTaskViewModel: aiTaskViewModel, state: state)
        }
    }

    // MARK: - Task Generation Methods

    func generateTask(for habit: Habit, viewModel: HabitViewModel, aiTaskViewModel: AITaskViewModel, state: HabitsViewState) async {
        guard let motivation = viewModel.todayMotivation?.level,
              let ability = viewModel.todayAbility?.level else {
            return
        }

        state.startTaskGeneration(for: habit.id)

        // Simulate typing animation
        let placeholderText = "Generating your personalized task..."
        await animateText(placeholderText, for: habit, state: state)

        // Set the motivation and ability levels in the viewModel
        aiTaskViewModel.selectedMotivationLevel = motivation
        aiTaskViewModel.selectedAbilityLevel = ability

        // Use the existing generateTaskForHabit method
        aiTaskViewModel.generateTaskForHabit(habit)

        // Wait for the task to be generated or timeout
        var attempts = 0
        let maxAttempts = 100 // 10 second timeout

        while attempts < maxAttempts {
            // Check if we have a task (success case)
            if let task = aiTaskViewModel.currentTask {
                // Clear placeholder and show real task
                state.generatedTaskText[habit.id] = ""
                await animateText(task.taskDescription, for: habit, state: state)
                state.taskDifficulty[habit.id] = "original"

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        state.showTaskAnimation[habit.id] = false // Reset animation state
                    }
                }

                state.isGeneratingTask[habit.id] = false
                return
            }

            // Check if generation is complete but failed
            if !aiTaskViewModel.isGeneratingTask {
                break
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }

        // If we get here, either timed out or generation failed
        state.generatedTaskText[habit.id] = ""
        if aiTaskViewModel.currentTask != nil {
            // Task exists but we somehow missed it in the loop
            await animateText(aiTaskViewModel.currentTask!.taskDescription, for: habit, state: state)
            state.taskDifficulty[habit.id] = "original"
            state.showTaskAnimation[habit.id] = false
        } else {
            // No task found
            await animateText("Failed to generate task. Please try again.", for: habit, state: state)
            state.showTaskAnimation[habit.id] = false
        }

        state.isGeneratingTask[habit.id] = false
    }

    func generateEasierTask(for habit: Habit, aiTaskViewModel: AITaskViewModel, state: HabitsViewState) async {
        guard let currentTask = aiTaskViewModel.currentTask,
              let easierAlternative = currentTask.easierAlternative,
              !easierAlternative.isEmpty else { return }

        state.isGeneratingTask[habit.id] = true
        state.showTaskAnimation[habit.id] = true
        state.generatedTaskText[habit.id] = ""

        // Check current difficulty to determine what to show
        let currentDifficulty = state.taskDifficulty[habit.id] ?? "original"

        if currentDifficulty == "harder" {
            // If currently showing harder, go back to original
            await animateText(currentTask.taskDescription, for: habit, state: state)
            state.taskDifficulty[habit.id] = "original"
        } else {
            // If currently showing original, go to easier
            await animateText(easierAlternative, for: habit, state: state)
            state.taskDifficulty[habit.id] = "easier"
        }

        state.showTaskAnimation[habit.id] = false // Reset animation state
        state.isGeneratingTask[habit.id] = false
    }

    func generateHarderTask(for habit: Habit, aiTaskViewModel: AITaskViewModel, state: HabitsViewState) async {
        guard let currentTask = aiTaskViewModel.currentTask,
              let harderAlternative = currentTask.harderAlternative,
              !harderAlternative.isEmpty else { return }

        state.isGeneratingTask[habit.id] = true
        state.showTaskAnimation[habit.id] = true
        state.generatedTaskText[habit.id] = ""

        // Check current difficulty to determine what to show
        let currentDifficulty = state.taskDifficulty[habit.id] ?? "original"

        if currentDifficulty == "easier" {
            // If currently showing easier, go back to original
            await animateText(currentTask.taskDescription, for: habit, state: state)
            state.taskDifficulty[habit.id] = "original"
        } else {
            // If currently showing original, go to harder
            await animateText(harderAlternative, for: habit, state: state)
            state.taskDifficulty[habit.id] = "harder"
        }

        state.showTaskAnimation[habit.id] = false // Reset animation state
        state.isGeneratingTask[habit.id] = false
    }

    private func animateText(_ text: String, for habit: Habit, state: HabitsViewState) async {
        let words = text.components(separatedBy: " ")

        for (index, word) in words.enumerated() {
            await MainActor.run {
                if index == 0 {
                    state.generatedTaskText[habit.id] = word
                } else {
                    state.generatedTaskText[habit.id] = (state.generatedTaskText[habit.id] ?? "") + " " + word
                }
            }

            // Vary the delay for more natural typing
            let delay = Double.random(in: 0.05...0.15)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}