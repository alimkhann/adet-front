import SwiftUI

@MainActor
class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var selectedHabit: Habit?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private var hasAttemptedFallback = false

    func fetchHabits() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            habits = try await apiService.fetchHabits()

            // Fallback: Only if user has no habits, has completed onboarding, and we haven't attempted fallback yet
            if habits.isEmpty && !hasAttemptedFallback {
                await createFallbackHabitFromOnboarding()
            }

            // Select the first habit by default
            if selectedHabit == nil && !habits.isEmpty {
                selectedHabit = habits.first
            }
        } catch {
            errorMessage = "Failed to fetch habits: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func selectHabit(_ habit: Habit) {
        selectedHabit = habit
    }

    func deleteHabit(_ habit: Habit) async {
        do {
            try await apiService.deleteHabit(id: habit.id)
            print("Successfully deleted habit: \(habit.name)")

            // Remove from local array
            habits.removeAll { $0.id == habit.id }

            // If the deleted habit was selected, select another one
            if selectedHabit?.id == habit.id {
                selectedHabit = habits.first
            }
        } catch {
            errorMessage = "Failed to delete habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    /// Resets the fallback flag when a new habit is created
    func resetFallbackFlag() {
        hasAttemptedFallback = false
    }

    /// Manually creates a habit from onboarding data
    func createHabitFromOnboarding() async {
        do {
            let onboardingAnswers = try await apiService.getOnboardingAnswers()
            let newHabit = try await apiService.createHabit(from: onboardingAnswers)
            print("Created habit from onboarding: \(newHabit.name)")

            // Refresh habits list
            habits = try await apiService.fetchHabits()

            // Reset fallback flag so it can be used again if needed
            hasAttemptedFallback = false
        } catch {
            errorMessage = "Failed to create habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    private func createFallbackHabitFromOnboarding() async {
        hasAttemptedFallback = true // Mark that we've attempted fallback

        do {
            let onboardingAnswers = try await apiService.getOnboardingAnswers()
            let newHabit = try await apiService.createHabit(from: onboardingAnswers)
            print("Created fallback habit from onboarding: \(newHabit.name)")

            // Refresh habits list
            habits = try await apiService.fetchHabits()
        } catch {
            print("Failed to create fallback habit: \(error.localizedDescription)")
            // Don't show this error to the user as it's just a fallback
        }
    }
}
