import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @StateObject private var aiTaskViewModel = AITaskViewModel()
    @StateObject private var state = HabitsViewState()
    @StateObject private var logic = HabitsViewLogic()
    @StateObject private var stateManager = HabitStateManager()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.habits.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                                .frame(height: 300)

                            Text("No habits yet")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Add your first habit to get started!")
                                .font(.body)
                                .foregroundColor(.secondary)

                            Button(action: {
                                state.showingAddHabitSheet = true
                            }) {
                                Text("Add Habit")
                                    .font(.headline)
                                    .frame(minHeight: 48)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    } else {
                        habitCarouselSection

                        if let selectedHabit = viewModel.selectedHabit {
                            bottomSection(for: selectedHabit)
                        } else {
                            placeholderSection
                        }
                    }
                    Spacer()
                }
            }
            .refreshable {
                await logic.refreshData(viewModel: viewModel, aiTaskViewModel: aiTaskViewModel, state: state)
            }
            .padding(.horizontal)
            .navigationBarHidden(true)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewModel.fetchHabits()
                    // After fetching, check if modal should show for default habit
                    if let habit = viewModel.selectedHabit {
                        await logic.checkAndHandleHabitSelection(habit, viewModel: viewModel, aiTaskViewModel: aiTaskViewModel, state: state)
                    }
                }
            }
            .navigationDestination(isPresented: $state.showingHabitDetails) {
                if let selectedHabit = viewModel.selectedHabit {
                    HabitDetailsView(habit: selectedHabit)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $state.showingAddHabitSheet) {
                AddHabitView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $state.showMotivationAbilityModal) {
                if let habit = viewModel.selectedHabit {
                    motivationAbilityModal(for: habit)
                }
            }
        }
    }

    // MARK: - UI Sections

    private var habitCarouselSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            let habitCards = viewModel.habits.map { habit in
                HabitCardView(
                    habit: habit,
                    isSelected: viewModel.selectedHabit?.id == habit.id,
                    onTap: {
                        // Use async dispatch to avoid publishing changes during view updates
                        Task { @MainActor in
                            // Don't clear task if we're switching to a habit that already has the current task
                            if let currentTask = aiTaskViewModel.currentTask,
                               currentTask.habitId != habit.id {
                                print("🔄 Switching from habit \(viewModel.selectedHabit?.id ?? -1) to \(habit.id)")
                                print("🗑️ Clearing task \(currentTask.id) (belongs to habit \(currentTask.habitId), not \(habit.id))")
                                aiTaskViewModel.currentTask = nil
                            }

                            // Always select the habit first
                            viewModel.selectHabit(habit)

                            await logic.checkAndHandleHabitSelection(habit, viewModel: viewModel, aiTaskViewModel: aiTaskViewModel, state: state)

                            if let currentTask = aiTaskViewModel.currentTask {
                                print("✅ Found task \(currentTask.id) for habit \(habit.id)")
                            } else {
                                print("❌ No task found for habit \(habit.id)")
                            }
                        }
                    },
                    onLongPress: {
                        // Use async dispatch to avoid publishing changes during view updates
                        Task { @MainActor in
                            print("Long press detected for habit: \(habit.name)")
                            viewModel.selectHabit(habit)
                            state.showingHabitDetails = true
                        }
                    },
                    width: 150,
                    height: 100
                )
            }
            HStack(spacing: 6) {
                ForEach(Array(habitCards.enumerated()), id: \.offset) { index, card in
                    card
                }
                AddHabitCardView(onTap: {
                    Task { @MainActor in
                        state.showingAddHabitSheet = true
                    }
                })
                .frame(width: 150, height: 100)
            }
        }
        .frame(height: 100)
        .clipped()
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .padding(.top)
    }

    private func bottomSection(for habit: Habit) -> some View {
        // Calculate current state for this habit
        let currentTask = aiTaskViewModel.currentTask?.habitId == habit.id ? aiTaskViewModel.currentTask : nil
        let habitState = stateManager.calculateState(
            for: habit,
            currentTask: currentTask,
            motivation: viewModel.todayMotivation,
            ability: viewModel.todayAbility,
            logic: logic
        )

        return VStack(spacing: 12) {
            // Show UI based on calculated state
            if habitState == .waitingForValidationTime {
                waitingForValidationSection(for: habit)
            } else if habitState == .needsMotivationAbility || habitState == .readyToGenerate {
                TaskGenerationSection(
                    habit: habit,
                    viewModel: viewModel,
                    aiTaskViewModel: aiTaskViewModel,
                    state: state,
                    logic: logic,
                    onShowMotivationAbility: {
                        state.showMotivationAbilityModal = true
                    }
                )
                .id("task-generation-\(habit.id)")
            } else if habitState == .taskActive || habitState == .taskCompleted {
                // Check if upload proof section should handle display exclusively
                let shouldUploadProofHandleDisplay = shouldUploadProofSectionTakeControl(for: habit)

                VStack(spacing: 12) {
                    // Only show task generation section if upload proof isn't taking control
                    if !shouldUploadProofHandleDisplay {
                        TaskGenerationSection(
                            habit: habit,
                            viewModel: viewModel,
                            aiTaskViewModel: aiTaskViewModel,
                            state: state,
                            logic: logic,
                            onShowMotivationAbility: {
                                state.showMotivationAbilityModal = true
                            }
                        )
                        .id("task-generation-\(habit.id)")
                    }

                    // Always show upload proof section (it will handle its own display logic)
                    UploadProofSection(
                        habit: habit,
                        aiTaskViewModel: aiTaskViewModel
                    )
                    .id("upload-proof-\(habit.id)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            } else {
                // Fallback for any unhandled states
                Text("State: \(habitState.displayName)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .id("bottom-section-\(habit.id)")
    }

    private func waitingForValidationSection(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.gray)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Validation time hasn't arrived yet")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Come back at \(formatValidationTime(habit.validationTime)) to start today's challenge")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Countdown to validation time
            if let timeUntilValidation = timeUntilValidation(for: habit) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time until validation:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Text(timeUntilValidation)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            // Allow users to set motivation and ability early
            VStack(alignment: .leading, spacing: 12) {
                Text("Get ready early!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                let hasMotivation = viewModel.todayMotivation != nil
                let hasAbility = viewModel.todayAbility != nil

                Button(action: {
                    state.showMotivationAbilityModal = true
                }) {
                    HStack {
                        Image(systemName: "heart.circle")

                        if !hasMotivation && !hasAbility {
                            Text("Set Motivation & Ability")
                                .fontWeight(.semibold)
                        } else if hasMotivation && !hasAbility {
                            Text("Set Ability")
                                .fontWeight(.semibold)
                        } else if !hasMotivation && hasAbility {
                            Text("Set Motivation")
                                .fontWeight(.semibold)
                        } else {
                            Text("Update Motivation & Ability")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())

                if hasMotivation || hasAbility {
                    HStack(spacing: 20) {
                        // Motivation display
                        if hasMotivation {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(HabitsViewHelpers.motivationEmoji(viewModel.todayMotivation?.level))
                                        .font(.caption)
                                    Text("Motivation")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(viewModel.todayMotivation?.level.capitalized ?? "")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }

                        // Ability display
                        if hasAbility {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(HabitsViewHelpers.abilityEmoji(viewModel.todayAbility?.level))
                                        .font(.caption)
                                    Text("Ability")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(viewModel.todayAbility?.level.capitalized ?? "")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private var placeholderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select a Habit")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose a habit from above to see today's AI-generated task")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal, 0)
    }

    private func motivationAbilityModal(for habit: Habit) -> some View {
        MotivationAbilityModal(
            isPresented: $state.showMotivationAbilityModal,
            isLoading: $state.isLoadingMotivation,
            habitName: habit.name,
            todayMotivation: viewModel.todayMotivation,
            todayAbility: viewModel.todayAbility,
            onSubmitMotivation: { answer in
                if let existing = viewModel.todayMotivation, existing.level.capitalized != answer {
                    return await viewModel.updateMotivationEntry(for: habit.id, level: answer.lowercased())
                } else if viewModel.todayMotivation == nil {
                    return await viewModel.submitMotivationEntry(for: habit.id, level: answer.lowercased())
                }
                return true
            },
            onSubmitAbility: { answer in
                let normalized = answer.replacingOccurrences(of: " ", with: "_").lowercased()
                if let existing = viewModel.todayAbility, existing.level.lowercased() == normalized {
                    // No change needed
                    return true
                } else if viewModel.todayAbility != nil {
                    // Update existing entry
                    let success = await viewModel.updateAbilityEntry(for: habit.id, level: normalized)
                    if success {
                        await logic.refreshMotivationAbilityEntries(for: habit, viewModel: viewModel)
                    }
                    return success
                } else {
                    // Create new entry
                    let success = await viewModel.submitAbilityEntry(for: habit.id, level: normalized)
                    if success {
                        await logic.refreshMotivationAbilityEntries(for: habit, viewModel: viewModel)
                    }
                    return success
                }
            }
        )
        .presentationDetents([.fraction(0.7)])
    }

    // MARK: - Helper Functions

    private func formatValidationTime(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        guard let time = formatter.date(from: timeString) else { return timeString }

        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    private func timeUntilValidation(for habit: Habit) -> String? {
        let calendar = Calendar.current
        let now = Date()

        // Parse validation time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        guard let validationTime = formatter.date(from: habit.validationTime) else { return nil }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: validationTime)

        guard let validationToday = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                minute: timeComponents.minute ?? 0,
                                                second: 0,
                                                of: now) else { return nil }

        if validationToday > now {
            let timeInterval = validationToday.timeIntervalSince(now)
            let hours = Int(timeInterval) / 3600
            let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60

            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }

        return nil
    }

    private func shouldUploadProofSectionTakeControl(for habit: Habit) -> Bool {
        guard let currentTask = aiTaskViewModel.currentTask, currentTask.habitId == habit.id else {
            return false
        }

        // Calculate if task is expired
        let timeRemaining = timeRemainingForTask(task: currentTask)
        let isExpired = timeRemaining <= 0 && currentTask.status == "pending"

        // Upload proof section takes control when:
        // 1. Task is expired (to show expired notification)
        // 2. Any comeback message scenario
        return isExpired
    }

    private func timeRemainingForTask(task: TaskEntry) -> TimeInterval {
        var dueDateString = task.dueDate
        if !dueDateString.contains("Z") && !dueDateString.contains("+") {
            dueDateString += "Z"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let dueDate = formatter.date(from: dueDateString) else {
            return 0
        }
        return dueDate.timeIntervalSince(Date())
    }
}
