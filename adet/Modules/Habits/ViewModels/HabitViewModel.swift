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

    func fetchHabits() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            habits = try await apiService.fetchHabits()

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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await apiService.deleteHabit(id: habit.id)
            print("Successfully deleted habit: \(habit.name)")

            // Refresh the habits list from the server to ensure consistency
            await fetchHabits()

        } catch NetworkError.unauthorized {
            errorMessage = "Authentication failed. Please try again."
            print("Authentication failed for habit deletion")

            // Try to refresh authentication and retry once
            do {
                // Wait a moment for network to recover
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                try await apiService.deleteHabit(id: habit.id)
                print("Successfully deleted habit on retry: \(habit.name)")

                // Refresh the habits list from the server after successful retry
                await fetchHabits()

                // Clear error message on success
                errorMessage = nil
            } catch {
                errorMessage = "Failed to delete habit after retry: \(error.localizedDescription)"
                print("Failed to delete habit on retry: \(error.localizedDescription)")
            }
        } catch {
            errorMessage = "Failed to delete habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    /// Manually creates a habit from onboarding data
    func createHabitFromOnboarding() async {
        do {
            let onboardingAnswers = try await apiService.getOnboardingAnswers()
            let newHabit = try await apiService.createHabit(from: onboardingAnswers)
            print("Created habit from onboarding: \(newHabit.name)")

            // Refresh habits list
            habits = try await apiService.fetchHabits()
        } catch {
            errorMessage = "Failed to create habit: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func createHabit(_ habit: Habit) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let newHabit = try await apiService.createHabit(habit)
            await fetchHabits() // Refresh the list

            // Select the newly created habit
            selectedHabit = habits.first { $0.id == newHabit.id }
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

    func updateAbilityEntry(for habitId: Int, level: String) async -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // yyyy-MM-dd
        do {
            _ = try await apiService.updateAbilityEntry(habitId: habitId, date: String(today), level: level)
            return true
        } catch {
            ToastManager.shared.showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Interval Day Logic
    func isTodayIntervalDay(for habit: Habit) -> Bool {
        let frequency = habit.frequency.lowercased()

        // Handle special frequency formats
        if frequency == "every day" || frequency == "daily" {
            return true
        }

        if frequency == "weekdays" {
            let todayIndex = Calendar.current.component(.weekday, from: Date())
            return todayIndex >= 2 && todayIndex <= 6 // Monday(2) to Friday(6)
        }

        if frequency == "weekends" {
            let todayIndex = Calendar.current.component(.weekday, from: Date())
            return todayIndex == 1 || todayIndex == 7 // Sunday(1) or Saturday(7)
        }

        // Handle comma-separated weekday abbreviations like "Mon, Wed, Fri"
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1 // Sunday = 0
        let formatter = DateFormatter()
        let todayAbbr = formatter.shortWeekdaySymbols[todayIndex] // e.g. "Mon"

        return habit.frequency.contains(todayAbbr)
    }
}
