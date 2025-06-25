import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingHabitDetails = false
    @State private var showingAddHabitSheet = false
    @State private var showMotivationAbilityModal = false
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
                                    // Check if today is an interval day for this habit
                                    if viewModel.isTodayIntervalDay(for: habit) {
                                        let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
                                        let ability = await viewModel.getTodayAbilityEntry(for: habit.id)
                                        if motivation == nil || ability == nil {
                                            showMotivationAbilityModal = true
                                        } else {
                                            showMotivationAbilityModal = false
                                        }
                                    } else {
                                        showMotivationAbilityModal = false
                                    }
                                }
                            },
                            onLongPress: {
                                print("Long press detected for habit: \(habit.name)")
                                showingHabitDetails = true
                            }
                        )
                    }
                    HStack(spacing: 15) {
                        ForEach(Array(habitCards.enumerated()), id: \ .element.habit.id) { _, card in
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

                // Today's Task Section (Dummy)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Today's Task:")
                        .font(.title2).bold()

                    Text("AI-Generated Tasks to validate the habit recurring based on users set intervals")
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Easier/Harder Buttons (Dummy)
                    HStack {
                        Button {} label: {
                            Text("Easier")
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {} label: {
                            Text("Harder")
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? .zinc900 : .zinc100)
                .cornerRadius(10)
                .padding(.horizontal)

                // Proof Submission Section (Dummy)
                VStack(alignment: .center, spacing: 10) {
                    Text("Based on the AI-Gen Task:")
                        .font(.headline)

                    Text("You either upload a photo/video/audio/text")
                        .font(.body)

                    Button {} label: {
                        Text("Upload Proof")
                            .frame(minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? .zinc900 : .zinc100)
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewModel.fetchHabits()
                    // After fetching, check if modal should show for default habit
                    if let habit = viewModel.selectedHabit, viewModel.isTodayIntervalDay(for: habit) {
                        let motivation = await viewModel.getTodayMotivationEntry(for: habit.id)
                        let ability = await viewModel.getTodayAbilityEntry(for: habit.id)
                        if (motivation == nil || ability == nil) && !showMotivationAbilityModal {
                            showMotivationAbilityModal = true
                        }
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
        }
    }
}
