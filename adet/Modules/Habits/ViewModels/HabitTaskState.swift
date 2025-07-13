import Foundation

/// Enum representing all possible UI states for the main task section in HabitsView.
/// This is driven by the business logic in HabitViewModel and matches the Figma flows.
enum HabitTaskState: Equatable {
    // No habit selected or no habits exist
    case empty

    // Not a scheduled day for this habit
    case notToday(nextTaskDate: Date)

    // Task is today, but not validation time yet
    case waitingForValidationTime(timeLeft: TimeInterval, motivationSet: Bool, abilitySet: Bool)

    // Task is today, validation time but motivation and ability are not set
    case validationTime(timeLeft: TimeInterval, motivationSet: Bool, abilitySet: Bool)

    // Motivation step (inline, not modal)
    case setMotivation(current: String?, timeLeft: TimeInterval?)
    // Ability step (inline, not modal)
    case setAbility(current: String?, timeLeft: TimeInterval?)

    // Task is today, validation time, motivation/ability set, ready to generate
    case readyToGenerateTask

    // Task is being generated
    case generatingTask

    // Task generated, showing details and proof section
    case showTask(task: HabitTaskDetails, proof: HabitProofState)

    // Task missed (expired)
    case missed(nextTaskDate: Date)

    // Dismissable missed state (for previous day)
    case dismissableMissed(nextTaskDate: Date)

    // Task failed, attempts left
    case failed(attemptsLeft: Int)
    // Task failed, no attempts left
    case failedNoAttempts(nextTaskDate: Date)

    // Dismissable failedNoAttempts state (for previous day)
    case dismissableFailedNoAttempts(nextTaskDate: Date)

    // Task success, show share option
    case successShare(task: HabitTaskDetails, proof: HabitProofState)
    // Task success, done
    case successDone

    // Error state (network, AI, etc.)
    case error(message: String)
}

/// Struct for passing task details to the view
struct HabitTaskDetails: Equatable {
    let description: String
    let easierAlternative: String?
    let harderAlternative: String?
    let motivation: String
    let ability: String
    let timeLeft: TimeInterval?
}

/// Enum for proof section state
public enum HabitProofState: Equatable {
    case notStarted
    case uploading
    case validating
    case readyToSubmit(ProofData)
    case submitted
    case error(message: String)
}

public enum ProofData: Equatable {
    case image(Data)
    case video(Data)
    case audio(Data)
    case text(String)
}

// Add HabitTaskState extension for isShowTask
extension HabitTaskState {
    var isShowTask: Bool {
        if case .showTask = self { return true }
        return false
    }
}

