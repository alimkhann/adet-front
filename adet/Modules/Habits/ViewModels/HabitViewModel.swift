import SwiftUI

@MainActor
class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func fetchHabits() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            habits = try await apiService.fetchHabits()

            // Fallback: If user has no habits but has completed onboarding, create a habit
            if habits.isEmpty {
                await createHabitFromOnboarding()
            }
        } catch {
            errorMessage = "Failed to fetch habits: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    private func createHabitFromOnboarding() async {
        do {
            let onboardingAnswers = try await apiService.getOnboardingAnswers()
            let newHabit = try await apiService.createHabit(name: onboardingAnswers.habit_name)
            print("Created fallback habit from onboarding: \(newHabit.name)")

            // Refresh habits list
            habits = try await apiService.fetchHabits()
        } catch {
            print("Failed to create fallback habit: \(error.localizedDescription)")
            // Don't show this error to the user as it's just a fallback
        }
    }
}
