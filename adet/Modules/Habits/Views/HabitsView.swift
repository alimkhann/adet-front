import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddHabitSheet = false
    @State private var showingHabitDetails = false
    @State private var editingHabit: Habit? = nil
    @State private var lastDateChecked: Date = Calendar.current.startOfDay(for: Date())
    @State private var hasLoadedHabits = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Carousel or Empty State
                if viewModel.isLoading {
                    ShimmerHabitsListView()
                } else if viewModel.habits.isEmpty {
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
                        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))

                    // Main Task Section (always present)
                    HabitTaskSectionView(
                        state: viewModel.currentTaskState,
                        isTaskInProgress: viewModel.isTaskInProgress,
                        onSetMotivation: { level in Task { await viewModel.setMotivation(level) } },
                        onSetAbility: { level in Task { await viewModel.setAbility(level) } },
                        onGenerateTask: { Task { await viewModel.generateTask() } },
                        onSubmitProof: { type, data, text in Task { await viewModel.submitProof(type: type, data: data, text: text) } },
                        onRetry: {
                            Task {
                                await viewModel.retryAfterFailure()
                            }
                        },
                        onShowMotivationStep: { viewModel.currentTaskState = .setMotivation(current: viewModel.todayMotivation?.level, timeLeft: nil) },
                        viewModel: viewModel
                    )
                    .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.clear, lineWidth: 1)
                            .padding()
                    )
                }
                Spacer(minLength: 0)
            }
            .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
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
                if !hasLoadedHabits {
                    viewModel.startCountdownTimer()
                    Task {
                        if let habit = viewModel.selectedHabit {
                            await viewModel.fetchTodayTask(for: habit)
                            viewModel.updateTaskState()
                        } else {
                            await viewModel.fetchUserAndHabits()
                            // Auto-select first habit if available and none selected
                            if viewModel.selectedHabit == nil, let firstHabit = viewModel.habits.first {
                                viewModel.selectHabit(firstHabit)
                                await viewModel.fetchTodayTask(for: firstHabit)
                                viewModel.updateTaskState()
                            } else if let habit = viewModel.selectedHabit {
                                await viewModel.fetchTodayTask(for: habit)
                                viewModel.updateTaskState()
                            }
                        }
                        await viewModel.fetchStreakFreezers()
                    }
                    hasLoadedHabits = true
                }
            }
            .onDisappear {
                viewModel.cancelCountdownTimer()
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
                            #if DEBUG
                            return true
                            #else
                            switch viewModel.currentTaskState {
                            case .notToday, .successDone:
                                return true
                            default:
                                return false
                            }
                            #endif
                        }()
                    )
                    .environmentObject(viewModel)
                }
            }
            .refreshable {
                HapticManager.shared.selection()
                await viewModel.fetchHabits()
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
                            viewModel.selectHabit(habit)
                            Task {
                                await viewModel.fetchTodayTask(for: habit)
                                _ = await viewModel.getTodayMotivationEntry(for: habit.id)
                                _ = await viewModel.getTodayAbilityEntry(for: habit.id)
                                viewModel.updateTaskState()
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
                AddHabitCardView(
                    onTap: {
                        showingAddHabitSheet = true
                    },
                    isLocked: viewModel.userPlan == "free" && viewModel.habits.count >= 2
                )
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
