import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @StateObject private var aiTaskViewModel = AITaskViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingHabitDetails = false
    @State private var showingAddHabitSheet = false
    @State private var showMotivationAbilityModal = false
    @State private var showAITaskGeneration = false
    @State private var showAITaskDisplay = false
    @State private var motivationAnswer: String? = nil
    @State private var abilityAnswer: String? = nil
    @State private var isLoadingMotivation = false
    @State private var isLoadingAbility = false
    @State private var showToast: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Carousel for Habits
                ScrollView(.horizontal, showsIndicators: false) {
                    let habitCards = viewModel.habits.map { habit in
                        HabitCardView(
                            habit: habit,
                            isSelected: viewModel.selectedHabit?.id == habit.id,
                            onTap: {
                                viewModel.selectHabit(habit)
                                Task {
                                    await checkAndHandleHabitSelection(habit)
                                }
                            },
                            onLongPress: {
                                print("Long press detected for habit: \(habit.name)")
                                showingHabitDetails = true
                            }
                        )
                    }
                    HStack(spacing: 15) {
                        ForEach(Array(habitCards.enumerated()), id: \.element.habit.id) { _, card in
                            card
                        }
                        AddHabitCardView(onTap: {
                            showingAddHabitSheet = true
                        })
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
                .padding(.top)

                // Dynamic Bottom Section based on selected habit and task state
                if let selectedHabit = viewModel.selectedHabit {
                    bottomSection(for: selectedHabit)
                } else {
                    placeholderSection
                }

                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewModel.fetchHabits()
                    // After fetching, check if modal should show for default habit
                    if let habit = viewModel.selectedHabit {
                        await checkAndHandleHabitSelection(habit)
                    }
                }
            }
            .navigationDestination(isPresented: $showingHabitDetails) {
                if let selectedHabit = viewModel.selectedHabit {
                    HabitDetailsView(habit: selectedHabit)
                        .environmentObject(viewModel)
                }
            }
            .sheet(isPresented: $showingAddHabitSheet) {
                AddHabitView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showMotivationAbilityModal) {
                if let habit = viewModel.selectedHabit {
                    MotivationAbilityModal(
                        isPresented: $showMotivationAbilityModal,
                        isLoading: $isLoadingMotivation,
                        habitName: habit.name,
                        todayMotivation: viewModel.todayMotivation,
                        onSubmitMotivation: { answer in
                            if let existing = viewModel.todayMotivation, existing.level.capitalized != answer {
                                return await viewModel.updateMotivationEntry(for: habit.id, level: answer.lowercased())
                            } else if viewModel.todayMotivation == nil {
                                return await viewModel.submitMotivationEntry(for: habit.id, level: answer.lowercased())
                            }
                            return true
                        },
                        onSubmitAbility: { answer in
                            await viewModel.submitAbilityEntry(for: habit.id, level: answer.replacingOccurrences(of: " ", with: "_").lowercased())
                        }
                    )
                    .presentationDetents([.fraction(0.65)])
                }
            }
            .sheet(isPresented: $showAITaskGeneration) {
                if let habit = viewModel.selectedHabit {
                    AITaskGenerationView(habit: habit)
                        .onDisappear {
                            // Check for today's task after generation
                            if let habit = viewModel.selectedHabit {
                                Task {
                                    await checkTodayTask(for: habit)
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showAITaskDisplay) {
                if let task = aiTaskViewModel.currentTask {
                    AITaskDisplayView(task: task)
                        .onDisappear {
                            // Refresh task state after display
                            if let habit = viewModel.selectedHabit {
                                Task {
                                    await checkTodayTask(for: habit)
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func checkAndHandleHabitSelection(_ habit: Habit) async {
        // Check if today is an interval day for this habit
        if viewModel.isTodayIntervalDay(for: habit) {
            let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
            let ability = await viewModel.getTodayAbilityEntry(for: habit.id)

            if motivation == nil || ability == nil {
                showMotivationAbilityModal = true
            } else {
                showMotivationAbilityModal = false
                // Check for today's task
                await checkTodayTask(for: habit)
            }
        } else {
            showMotivationAbilityModal = false
            // Check for today's task even if not interval day
            await checkTodayTask(for: habit)
        }
    }

    private func checkTodayTask(for habit: Habit) async {
        do {
            let task = try await aiTaskViewModel.checkTodayTask(for: habit)
            aiTaskViewModel.currentTask = task
        } catch {
            // Task not found or error - this is expected for new habits
            aiTaskViewModel.currentTask = nil
        }
    }

    // MARK: - UI Sections

    private func bottomSection(for habit: Habit) -> some View {
        VStack(spacing: 16) {
            if aiTaskViewModel.isLoading {
                loadingSection
            } else if let currentTask = aiTaskViewModel.currentTask {
                taskSection(for: currentTask)
            } else if viewModel.isTodayIntervalDay(for: habit) {
                noTaskSection(for: habit)
            } else {
                notIntervalDaySection(for: habit)
            }
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading today's task...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func taskSection(for task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Task Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Task")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Circle()
                            .fill(aiTaskViewModel.getStatusColor(task.status))
                            .frame(width: 8, height: 8)
                        Text(TaskStatus(rawValue: task.status)?.displayName ?? task.status.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    showAITaskDisplay = true
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }

            // Task Description
            Text(task.taskDescription)
                .font(.body)
                .lineLimit(3)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            // Task Metadata
            HStack(spacing: 20) {
                VStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.orange)
                    Text(aiTaskViewModel.formatDifficulty(task.difficultyLevel))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Difficulty")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                    Text(aiTaskViewModel.formatDuration(task.estimatedDuration))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Action Buttons
            if task.status == "pending" {
                HStack(spacing: 12) {
                    Button(action: {
                        showAITaskDisplay = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Submit Proof")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        aiTaskViewModel.updateTaskStatus(.failed)
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Failed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            } else if task.status == "completed" {
                VStack(spacing: 8) {
                    Image(systemName: "party.popper.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)

                    Text(task.celebrationMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func noTaskSection(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready for Today's Task?")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Let AI create a personalized task for you")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundColor(.blue)
            }

            Button(action: {
                showAITaskGeneration = true
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate AI Task")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func notIntervalDaySection(for habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not Today")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This habit is scheduled for \(habit.frequency) intervals")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "calendar.badge.clock")
                    .font(.title)
                    .foregroundColor(.gray)
            }

            Text("Come back on your scheduled day to get your AI-generated task!")
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .padding(.horizontal)
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
        .padding(.horizontal)
    }
}
