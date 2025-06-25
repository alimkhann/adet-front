import SwiftUI

@MainActor
class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var selectedHabit: Habit?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var todayMotivation: MotivationEntryResponse? = nil
    @Published var todayAbility: AbilityEntryResponse? = nil

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

    func createHabit(_ habit: Habit) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let _ = try await apiService.createHabit(habit)
            await fetchHabits() // Refresh the list
            resetFallbackFlag() // Allow fallback creation again if needed
        } catch {
            errorMessage = "Failed to create habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func updateHabit(_ habit: Habit) async -> Habit? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let updatedHabit = try await apiService.updateHabit(id: habit.id, data: habit)
            print("Successfully updated habit: \(updatedHabit.name)")

            // Update the habit in the local array
            if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                habits[index] = updatedHabit
            }

            // Update selected habit if it's the one being updated
            if selectedHabit?.id == habit.id {
                selectedHabit = updatedHabit
            }

            return updatedHabit
        } catch {
            errorMessage = "Failed to update habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
            return nil
        }
    }

    // MARK: - Motivation & Ability Tracking
    func getTodayMotivationEntry(for habitId: Int) async -> MotivationEntryResponse? {
        do {
            let entry = try await apiService.getTodayMotivationEntry(habitId: habitId)
            todayMotivation = entry
            return entry
        } catch {
            todayMotivation = nil
            return nil
        }
    }

    func submitMotivationEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.submitMotivationEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch let error as NSError {
            if error.localizedDescription.contains("already exists") {
                // Already exists, treat as success
                return true
            }
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    func updateMotivationEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.updateMotivationEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch {
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    func getTodayAbilityEntry(for habitId: Int) async -> AbilityEntryResponse? {
        do {
            return try await apiService.getTodayAbilityEntry(habitId: habitId)
        } catch {
            return nil
        }
    }

    func submitAbilityEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.submitAbilityEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Interval Day Logic
    func isTodayIntervalDay(for habit: Habit) -> Bool {
        // Assumes habit.frequency is a comma-separated string of weekday abbreviations, e.g. "Mon, Wed, Fri"
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1 // Sunday = 0
        let formatter = DateFormatter()
        let todayAbbr = formatter.shortWeekdaySymbols[todayIndex] // e.g. "Mon"
        return habit.frequency.contains(todayAbbr)
    }
}
