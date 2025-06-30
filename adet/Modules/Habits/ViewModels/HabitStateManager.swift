import Foundation
import SwiftUI

// MARK: - Habit State Enum

enum HabitState: String, CaseIterable {
    case waitingForValidationTime = "waiting_for_validation_time"
    case needsMotivationAbility = "needs_motivation_ability"
    case readyToGenerate = "ready_to_generate"
    case taskActive = "task_active"
    case taskCompleted = "task_completed"

    var displayName: String {
        switch self {
        case .waitingForValidationTime: return "Waiting for validation time"
        case .needsMotivationAbility: return "Needs motivation & ability"
        case .readyToGenerate: return "Ready to generate task"
        case .taskActive: return "Task active"
        case .taskCompleted: return "Task completed"
        }
    }
}

// MARK: - Habit State Manager

@MainActor
class HabitStateManager: ObservableObject {
    @Published var habitStates: [Int: HabitState] = [:]

    // MARK: - State Calculation

    func calculateState(for habit: Habit, currentTask: TaskEntry?, motivation: MotivationEntryResponse?, ability: AbilityEntryResponse?, logic: HabitsViewLogic) -> HabitState {

        let today = Calendar.current.startOfDay(for: Date())
        let isValidationDay = isValidationDay(for: habit, on: today)
        let validationTimeReached = logic.isValidationTimeReached(for: habit)

        // If not a validation day, wait
        if !isValidationDay {
            return .waitingForValidationTime
        }

        // If validation time hasn't been reached yet
        if !validationTimeReached {
            return .waitingForValidationTime
        }

        // Check if we have a task for today
        if let task = currentTask, task.habitId == habit.id {
            switch task.status {
            case "completed":
                return .taskCompleted
            default:
                return .taskActive
            }
        }

        // No task exists - check motivation/ability
        let hasMotivation = motivation != nil
        let hasAbility = ability != nil

        if !hasMotivation || !hasAbility {
            return .needsMotivationAbility
        }

        return .readyToGenerate
    }

    // MARK: - State Management Actions

    func updateState(for habitId: Int, to state: HabitState) {
        habitStates[habitId] = state
    }

    // MARK: - Helper Methods

    private func isValidationDay(for habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current

        switch habit.frequency.lowercased() {
        case "daily":
            return true
        case "weekly":
            // For simplicity, let's say weekly habits are on the same day of week they were created
            // In a real app, you'd store the preferred day of week
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: Date())
        default:
            return true
        }
    }
}

// MARK: - State-Based UI Helpers

extension HabitStateManager {

    func shouldShowTaskGeneration(for habitId: Int) -> Bool {
        guard let state = habitStates[habitId] else { return false }
        return [.needsMotivationAbility, .readyToGenerate].contains(state)
    }

    func shouldShowActiveTask(for habitId: Int) -> Bool {
        guard let state = habitStates[habitId] else { return false }
        return [.taskActive, .taskCompleted].contains(state)
    }
}