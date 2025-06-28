import SwiftUI

struct AITaskGenerationView: View {
    let habit: Habit
    @StateObject private var viewModel = AITaskViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Motivation Selection
                    motivationSection

                    // Ability Selection
                    abilitySection

                    // Generate Button
                    generateButton

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Generate AI Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("AI Task Generation")
                .font(.title2)
                .fontWeight(.bold)

            Text("Let AI create a personalized task for your habit using BJ Fogg's Tiny Habits methodology")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.blue)
                    Text("Habit: \(habit.name)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.orange)
                    Text("Difficulty: \(habit.difficulty.capitalized)")
                        .fontWeight(.medium)
                }

                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.green)
                    Text("Proof: \(habit.proofStyle.capitalized)")
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var motivationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("How motivated are you today?")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                ForEach(["low", "medium", "high"], id: \.self) { level in
                    Button(action: {
                        viewModel.selectedMotivationLevel = level
                    }) {
                        HStack {
                            Image(systemName: viewModel.selectedMotivationLevel == level ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.selectedMotivationLevel == level ? .blue : .gray)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.capitalized)
                                    .fontWeight(.medium)
                                Text(motivationDescription(for: level))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(viewModel.selectedMotivationLevel == level ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var abilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("How easy is this for you today?")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                ForEach(["hard", "medium", "easy"], id: \.self) { level in
                    Button(action: {
                        viewModel.selectedAbilityLevel = level
                    }) {
                        HStack {
                            Image(systemName: viewModel.selectedAbilityLevel == level ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.selectedAbilityLevel == level ? .blue : .gray)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.capitalized)
                                    .fontWeight(.medium)
                                Text(abilityDescription(for: level))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(viewModel.selectedAbilityLevel == level ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var generateButton: some View {
        Button(action: {
            viewModel.generateTaskForHabit(habit)
        }) {
            HStack {
                if viewModel.isGeneratingTask {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "wand.and.stars")
                }

                Text(viewModel.isGeneratingTask ? "Generating..." : "Generate AI Task")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isGeneratingTask)
        .opacity(viewModel.isGeneratingTask ? 0.6 : 1.0)
    }

    // MARK: - Helper Methods

    private func motivationDescription(for level: String) -> String {
        switch level {
        case "low":
            return "I'm not feeling very motivated today"
        case "medium":
            return "I'm somewhat motivated to do this"
        case "high":
            return "I'm really excited to tackle this!"
        default:
            return ""
        }
    }

    private func abilityDescription(for level: String) -> String {
        switch level {
        case "hard":
            return "This feels challenging for me right now"
        case "medium":
            return "I can probably handle this"
        case "easy":
            return "This feels very doable for me"
        default:
            return ""
        }
    }
}

#Preview {
    AITaskGenerationView(habit: Habit(
        id: 1,
        userId: 1,
        name: "Exercise",
        description: "Daily workout",
        frequency: "daily",
        validationTime: "morning",
        difficulty: "medium",
        proofStyle: "photo",
        streak: 5
    ))
}
