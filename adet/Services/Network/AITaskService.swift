import Foundation
import Combine

class AITaskService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService = NetworkService.shared) {
        self.networkService = networkService
    }

    // MARK: - Task Generation

    func generateTask(
        for habitId: Int,
        request: AITaskRequest
    ) async throws -> TaskGenerationResponse {
        let endpoint = "/api/v1/habits/\(habitId)/generate-task"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "POST", body: request)
    }

    func generateAndCreateTask(
        for habitId: Int,
        request: AITaskRequest
    ) async throws -> TaskCreationResponse {
        let endpoint = "/api/v1/habits/\(habitId)/generate-and-create-task"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "POST", body: request)
    }

    // MARK: - Task Management

    func getTodayTask(for habitId: Int) async throws -> TaskEntry {
        let endpoint = "/api/v1/habits/\(habitId)/today-task"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "GET", body: nil as String?)
    }

    func getPendingTasks(limit: Int = 10) async throws -> [TaskEntry] {
        let endpoint = "/api/v1/habits/pending-tasks?limit=\(limit)"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "GET", body: nil as String?)
    }

    func submitTaskProof(
        taskId: Int,
        proof: TaskProofSubmit
    ) async throws -> TaskSubmissionResponse {
        let endpoint = "/api/v1/tasks/\(taskId)/submit-proof"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "POST", body: proof)
    }

    func updateTaskStatus(
        taskId: Int,
        status: TaskStatus
    ) async throws -> TaskSubmissionResponse {
        let endpoint = "/api/v1/tasks/\(taskId)/status"
        let statusUpdate = TaskStatusUpdate(status: status)
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "PUT", body: statusUpdate)
    }

    // MARK: - Performance Analysis

    func analyzePerformance(for habitId: Int) async throws -> AIResponse<PerformanceAnalysis> {
        let endpoint = "/api/v1/habits/\(habitId)/performance-analysis"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "GET", body: nil as String?)
    }

    func getImprovementSuggestions(for habitId: Int) async throws -> AIResponse<ImprovementSuggestions> {
        let endpoint = "/api/v1/habits/\(habitId)/improvement-suggestions"
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "GET", body: nil as String?)
    }

    // MARK: - Quick Task Generation (Fallback)

    func generateQuickTask(
        for habitId: Int,
        baseDifficulty: String,
        proofStyle: String,
        userLanguage: String = "en"
    ) async throws -> TaskGenerationResponse {
        let endpoint = "/api/v1/habits/\(habitId)/generate-quick-task"
        let request = [
            "base_difficulty": baseDifficulty,
            "proof_style": proofStyle,
            "user_language": userLanguage
        ]
        return try await networkService.makeAuthenticatedRequest(endpoint: endpoint, method: "POST", body: request)
    }
}

// MARK: - Convenience Extensions

extension AITaskService {
    func generateTaskForHabit(
        _ habit: Habit,
        motivationLevel: String,
        abilityLevel: String
    ) async throws -> TaskCreationResponse {
        let request = AITaskRequest(
            baseDifficulty: habit.difficulty.lowercased(),
            motivationLevel: motivationLevel,
            abilityLevel: abilityLevel,
            proofStyle: habit.proofStyle.lowercased(),
            userLanguage: "en", // TODO: Get from user preferences
            userTimezone: TimeZone.current.identifier
        )

        return try await generateAndCreateTask(for: habit.id, request: request)
    }

    func checkTodayTask(for habit: Habit) async throws -> TaskEntry? {
        do {
            return try await getTodayTask(for: habit.id)
        } catch NetworkError.requestFailed(let statusCode, _) where statusCode == 404 {
            return nil
        }
    }
}