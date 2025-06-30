import SwiftUI

@MainActor
class HabitsViewState: ObservableObject {
    @Published var showingHabitDetails = false
    @Published var showingAddHabitSheet = false
    @Published var showMotivationAbilityModal = false
    @Published var motivationAnswer: String? = nil
    @Published var abilityAnswer: String? = nil
    @Published var isLoadingMotivation = false
    @Published var isLoadingAbility = false
    @Published var showToast: Bool = false
    @Published var isGeneratingTask: [Int: Bool] = [:]
    @Published var generatedTaskText: [Int: String] = [:]
    @Published var showTaskAnimation: [Int: Bool] = [:]
    @Published var taskDifficulty: [Int: String] = [:]
    @Published var currentTaskRequest: [Int: String] = [:]
    @Published var showUploadProofSection: [Int: Bool] = [:]
    @Published var generateButtonPulse: Bool = false

    func resetTaskState(for habitId: Int) {
        isGeneratingTask[habitId] = false
        generatedTaskText[habitId] = ""
        showTaskAnimation[habitId] = false
        taskDifficulty[habitId] = "original"
        currentTaskRequest[habitId] = nil
        showUploadProofSection[habitId] = false
    }

    func startTaskGeneration(for habitId: Int) {
        isGeneratingTask[habitId] = true
        currentTaskRequest[habitId] = taskDifficulty[habitId] ?? "original"
        showTaskAnimation[habitId] = true
        showUploadProofSection[habitId] = false
        generatedTaskText[habitId] = ""
    }

    func completeTaskGeneration(for habitId: Int) {
        showTaskAnimation[habitId] = false
        isGeneratingTask[habitId] = false
    }

    func showUploadProof(for habitId: Int) {
        showUploadProofSection[habitId] = true
    }
}