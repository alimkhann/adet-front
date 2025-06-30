import SwiftUI

struct TaskGenerationSection: View {
    let habit: Habit
    let viewModel: HabitViewModel
    let aiTaskViewModel: AITaskViewModel
    @ObservedObject var state: HabitsViewState
    @ObservedObject var logic: HabitsViewLogic
    let onShowMotivationAbility: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    // Animation states for loading dots
    @State private var generationDots = "."
    @State private var generationTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Debug logging
            let _ = print("📋 TaskGenerationSection for \(habit.name): currentTask=\(aiTaskViewModel.currentTask?.id ?? -1), hasValidTaskForHabit=\(hasValidTaskForHabit)")

            // Header with motivation and ability levels - moved higher
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Task")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Only show status text when no task exists
                    if aiTaskViewModel.currentTask == nil {
                        if viewModel.isTodayIntervalDay(for: habit) {
                            if logic.isValidationTimeReached(for: habit) {
                                Text("Ready to generate your task")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Available in \(logic.timeUntilValidation(for: habit))")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("This habit is scheduled for \(habit.frequency)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Motivation & Ability Display - Always show when it's the habit day
                if viewModel.isTodayIntervalDay(for: habit) {
                    HStack(spacing: 20) {
                        // Motivation
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text(HabitsViewHelpers.motivationEmoji(viewModel.todayMotivation?.level))
                                    .font(.caption)
                                Text("Motivation")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(viewModel.todayMotivation?.level.capitalized ?? "Not Set")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.todayMotivation != nil ? .primary : .secondary)
                        }

                        // Ability
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text(HabitsViewHelpers.abilityEmoji(viewModel.todayAbility?.level))
                                    .font(.caption)
                                Text("Ability")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(viewModel.todayAbility?.level.capitalized ?? "Not Set")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.todayAbility != nil ? .primary : .secondary)
                        }
                    }
                }
            }

            // Task Display or Generation
            if state.showTaskAnimation[habit.id] == true {
                // AI Chat Animation with breathing effect
                taskAnimationView
            } else if let currentTask = aiTaskViewModel.currentTask, currentTask.habitId == habit.id {
                // Generated Task Display (current task)
                taskDisplayView(currentTask: currentTask)
            }

            // Action Buttons
            actionButtonsView
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal, 0)
        .onAppear {
            if state.isGeneratingTask[habit.id] == true {
                startGenerationAnimation()
            }
        }
        .onDisappear {
            stopGenerationAnimation()
        }
        .onChange(of: state.isGeneratingTask[habit.id]) { _, isGenerating in
            if isGenerating == true {
                startGenerationAnimation()
            } else {
                stopGenerationAnimation()
            }
        }
    }

    private func startGenerationAnimation() {
        generationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            switch generationDots {
            case ".":
                generationDots = ".."
            case "..":
                generationDots = "..."
            case "...":
                generationDots = "."
            default:
                generationDots = "."
            }
        }
    }

    private func stopGenerationAnimation() {
        generationTimer?.invalidate()
        generationTimer = nil
        generationDots = "."
    }

    // MARK: - Subviews

    private var taskAnimationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Loading indicator when generating
                if state.isGeneratingTask[habit.id] == true && state.generatedTaskText[habit.id]?.isEmpty == true {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("AI is crafting your perfect task\(generationDots)")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Text(state.generatedTaskText[habit.id] ?? "")
                        .font(.body)
                        .foregroundColor(.primary)
                        .animation(.easeInOut, value: state.generatedTaskText[habit.id])
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .overlay(
                    // Subtle shimmer effect when generating
                    state.isGeneratingTask[habit.id] == true ?
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    (colorScheme == .dark ? Color.white : Color.black).opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: false),
                            value: state.isGeneratingTask[habit.id]
                        )
                    : nil
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(state.isGeneratingTask[habit.id] == true ? 1.02 : 1.0)
        .opacity(state.isGeneratingTask[habit.id] == true ? 0.9 : 1.0)
        .animation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true),
            value: state.isGeneratingTask[habit.id]
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }

    private func taskDisplayView(currentTask: TaskEntry) -> some View {
        // Calculate values outside the VStack
        let currentDifficulty = state.taskDifficulty[habit.id] ?? "original"
        let displayText: String

        switch currentDifficulty {
        case "easier":
            displayText = currentTask.easierAlternative ?? currentTask.taskDescription
        case "harder":
            displayText = currentTask.harderAlternative ?? currentTask.taskDescription
        default:
            displayText = currentTask.taskDescription
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(displayText)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(colorScheme == .dark ? Color.black : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.4), value: state.showTaskAnimation[habit.id])
    }

    private var actionButtonsView: some View {
        Group {
            if viewModel.isTodayIntervalDay(for: habit) && logic.isValidationTimeReached(for: habit) {
                // Check if we have both motivation and ability for this specific habit
                let hasMotivation = viewModel.todayMotivation != nil
                let hasAbility = viewModel.todayAbility != nil
                let hasBothMotivationAndAbility = hasMotivation && hasAbility

                if hasBothMotivationAndAbility {
                    let hasTaskForThisHabit = aiTaskViewModel.currentTask?.habitId == habit.id

                    if !hasValidTaskForHabit && !(state.isGeneratingTask[habit.id] ?? false) {
                        Button(action: {
                            Task {
                                await logic.generateTask(for: habit, viewModel: viewModel, aiTaskViewModel: aiTaskViewModel, state: state)
                            }
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text(hasTaskForThisHabit ? "Generate New Task" : "Generate AI Task")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .scaleEffect(state.generateButtonPulse ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: state.generateButtonPulse
                        )
                        .onAppear {
                            state.generateButtonPulse = true
                        }
                    } else if hasValidTaskForHabit && !(state.isGeneratingTask[habit.id] ?? false) {
                        // Easier/Harder Buttons
                        difficultyButtonsView
                    }
                } else {
                    // Need Motivation & Ability
                    motivationAbilityButtonView
                }
            } else if !viewModel.isTodayIntervalDay(for: habit) {
                // Not Today - styled like primary button
                notTodayView
            } else {
                // Waiting for validation time
                motivationAbilityButtonView
            }
        }
    }

    // MARK: - Helper Properties

    private var hasValidTaskForHabit: Bool {
        guard let currentTask = aiTaskViewModel.currentTask, currentTask.habitId == habit.id else {
            return false
        }
        // Task is valid if it's any active status (not expired or completely done)
        return ["pending", "completed", "failed", "pending_review"].contains(currentTask.status)
    }

    private var difficultyButtonsView: some View {
        let currentDifficulty = state.taskDifficulty[habit.id] ?? "original"

        return HStack(spacing: 12) {
            if currentDifficulty == "original" {
                // Show both buttons when at original difficulty
                if aiTaskViewModel.currentTask?.easierAlternative != nil && !(aiTaskViewModel.currentTask?.easierAlternative?.isEmpty ?? true) {
                    Button(action: {
                        Task {
                            await logic.generateEasierTask(for: habit, aiTaskViewModel: aiTaskViewModel, state: state)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Easier")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }

                if aiTaskViewModel.currentTask?.harderAlternative != nil && !(aiTaskViewModel.currentTask?.harderAlternative?.isEmpty ?? true) {
                    Button(action: {
                        Task {
                            await logic.generateHarderTask(for: habit, aiTaskViewModel: aiTaskViewModel, state: state)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle")
                            Text("Harder")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            } else {
                // Show single "Original" button when at easier or harder difficulty
                Button(action: {
                    Task {
                        if currentDifficulty == "easier" {
                            await logic.generateHarderTask(for: habit, aiTaskViewModel: aiTaskViewModel, state: state) // This will go back to original
                        } else if currentDifficulty == "harder" {
                            await logic.generateEasierTask(for: habit, aiTaskViewModel: aiTaskViewModel, state: state) // This will go back to original
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .resizable()
                            .frame(width: 20, height: 20)

                        Text("Original")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentDifficulty)
    }

    private var motivationAbilityButtonView: some View {
        let hasMotivation = viewModel.todayMotivation != nil
        let hasAbility = viewModel.todayAbility != nil

        return Button(action: {
            onShowMotivationAbility()
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
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var notTodayView: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
            Text("Come back soon!")
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(colorScheme == .dark ? Color.white : Color.black)
        .foregroundColor(colorScheme == .dark ? .black : .white)
        .cornerRadius(12)
    }
}
