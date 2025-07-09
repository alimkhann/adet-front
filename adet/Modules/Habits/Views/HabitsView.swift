import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddHabitSheet = false
    @State private var showingHabitDetails = false
    @State private var editingHabit: Habit? = nil
    @State private var lastDateChecked: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Carousel or Empty State
                if viewModel.habits.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        EmptyHabitsView(onAddHabit: {
                            showingAddHabitSheet = true
                        })
                        Spacer()
                    }
                } else {
                    habitCarouselSection
                        .padding(.horizontal)

                    // Main Task Section (always present)
                    HabitTaskSectionView(
                        state: viewModel.currentTaskState,
                        isTaskInProgress: viewModel.isTaskInProgress,
                        onSetMotivation: { level in Task { await viewModel.setMotivation(level) } },
                        onSetAbility: { level in Task { await viewModel.setAbility(level) } },
                        onGenerateTask: { Task { await viewModel.generateTask() } },
                        onSubmitProof: { type, data, text in Task { await viewModel.submitProof(type: type, data: data, text: text) } },
                        onRetry: { Task { await viewModel.updateTaskStateAsync() } },
                        onShowMotivationStep: { viewModel.currentTaskState = .setMotivation(current: viewModel.todayMotivation?.level) },
                        viewModel: viewModel
                    )
                }
                Spacer(minLength: 0)
            }
            .background(Color(.systemGray6))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("ädet")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.leading)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showStreakFreezerInfo() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake.circle.fill")
                                .foregroundColor(.blue)
                            Text("\(viewModel.streakFreezers)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                Task { @MainActor in
                    await viewModel.fetchHabits()
                    await viewModel.fetchStreakFreezers()
                    if let habit = viewModel.selectedHabit {
                        await viewModel.fetchTodayTask(for: habit)
                        _ = await viewModel.getTodayMotivationEntry(for: habit.id)
                        _ = await viewModel.getTodayAbilityEntry(for: habit.id)
                        viewModel.updateTaskState()
                    }
                    lastDateChecked = Calendar.current.startOfDay(for: Date())
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    if let habit = viewModel.selectedHabit {
                        await viewModel.fetchTodayTask(for: habit)
                        viewModel.updateTaskState()
                    }
                    lastDateChecked = Calendar.current.startOfDay(for: Date())
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                let currentDate = Calendar.current.startOfDay(for: Date())
                if currentDate != lastDateChecked {
                    Task {
                        if let habit = viewModel.selectedHabit {
                            await viewModel.fetchTodayTask(for: habit)
                            viewModel.updateTaskState()
                        }
                        lastDateChecked = currentDate
                    }
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
            // Add Habit Sheet
            .sheet(isPresented: $showingAddHabitSheet) {
                AddHabitView()
                    .environmentObject(viewModel)
            }
            // Habit Details Navigation
            .navigationDestination(isPresented: $showingHabitDetails) {
                if let habit = editingHabit {
                    HabitDetailsView(
                        habit: habit,
                        canEdit: {
                            switch viewModel.currentTaskState {
                            case .generatingTask, .showTask:
                                return false
                            default:
                                return true
                            }
                        }()
                    )
                    .environmentObject(viewModel)
                }
            }
            .onDisappear {
                viewModel.cancelPolling()
            }
        }
    }

    // MARK: - Habit Carousel Section
    private var habitCarouselSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.habits) { habit in
                    HabitCardView(
                        habit: habit,
                        isSelected: viewModel.selectedHabit?.id == habit.id,
                        onTap: {
                            if !viewModel.isTaskInProgress {
                                viewModel.selectHabit(habit)
                                Task {
                                    await viewModel.fetchTodayTask(for: habit)
                                    _ = await viewModel.getTodayMotivationEntry(for: habit.id)
                                    _ = await viewModel.getTodayAbilityEntry(for: habit.id)
                                    viewModel.updateTaskState()
                                }
                            }
                        },
                        onLongPress: {
                            // Only allow edit if not in progress
                            if !viewModel.isTaskInProgress {
                                editingHabit = habit
                                showingHabitDetails = true
                            }
                        },
                        width: 150,
                        height: 100,
                        isTaskInProgress: viewModel.isTaskInProgress
                    )
                }
                AddHabitCardView(onTap: {
                    showingAddHabitSheet = true
                })
                .frame(width: 150, height: 100)
            }
        }
        .frame(height: 100)
        .clipped()
        .padding(.top)
    }

    private func showStreakFreezerInfo() {
        // Show an alert or tooltip with info about streak freezers
        // For now, use a simple alert
        let alert = UIAlertController(title: "Streak Freezers", message: "Streak Freezers: \(viewModel.streakFreezers) left. Used automatically if you miss a task.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
}
