import SwiftUI

struct HabitsView: View {
    @StateObject private var viewModel = HabitViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {

            VStack(alignment: .leading, spacing: 20) {
                // Carousel for Habits
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(viewModel.habits) { habit in
                            HabitCardView(habit: habit)
                        }
                        AddHabitCardView()
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
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color("Zinc900") : Color("Zinc100"))
                .cornerRadius(10)
                .padding(.horizontal)

                // Easier/Harder Buttons (Dummy)
                HStack {
                    Button {} label: {
                        Text("Easier")
                            .frame(minHeight: 48)
                    }
                        .buttonStyle(SecondaryButtonStyle())

                    Button {} label: {
                        Text("Harder")
                            .frame(minHeight: 48)
                    }
                        .buttonStyle(SecondaryButtonStyle())
                }
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
                .background(colorScheme == .dark ? Color("Zinc900") : Color("Zinc100"))
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    // Add a short delay to ensure the auth token is ready
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewModel.fetchHabits()
                }
            }
        }
    }
}
