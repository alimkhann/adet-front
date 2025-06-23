import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingHabitDetails = false
    @State private var showingAddHabitSheet = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Carousel for Habits
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(viewModel.habits) { habit in
                            HabitCardView(
                                habit: habit,
                                isSelected: viewModel.selectedHabit?.id == habit.id,
                                onTap: {
                                    viewModel.selectHabit(habit)
                                },
                                onLongPress: {
                                    print("Long press detected for habit: \(habit.name)")
                                    showingHabitDetails = true
                                }
                            )
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
        }
    }
}
