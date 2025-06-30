import Foundation
import Clerk
import OSLog

// MARK: - Motivation & Ability Tracking (move these to file scope)

actor APIService {
    static let shared = APIService()
    private let networkService = NetworkService.shared
    private let logger = Logger(subsystem: "com.adet.api", category: "APIService")

    private init() {}

    // MARK: - User API Operations

    /// Fetches the backend health status.
    func healthCheck() async throws -> HealthResponse {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/health", method: "GET", body: (nil as String?))
    }

    /// Fetches the currently authenticated user's data.
    func getCurrentUser() async throws -> User {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me", method: "GET", body: (nil as String?))
    }

    /// Syncs user data from Clerk to update email and profile information.
    func syncUserFromClerk() async throws -> User {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/sync", method: "POST", body: (nil as String?))
    }

    /// Updates the user's username.
    func updateUsername(_ username: String) async throws {
        let requestBody = UsernameUpdateRequest(username: username)
        let _: EmptyResponse = try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/username", method: "PATCH", body: requestBody)
    }

    /// Deletes the user's account from the backend.
    func deleteAccount() async throws {
        try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me", method: "DELETE")
    }

    /// Uploads a profile image for the user.
    func uploadProfileImage(_ imageData: Data, fileName: String, mimeType: String) async throws -> User {
        return try await networkService.uploadFile(
            endpoint: "/api/v1/users/me/profile-image",
            fileData: imageData,
            fileName: fileName,
            mimeType: mimeType,
            fieldName: "file"
        )
    }

    /// Updates the user's profile image URL.
    func updateProfileImageUrl(_ imageUrl: String) async throws -> User {
        let requestBody = ProfileImageUpdateRequest(profileImageUrl: imageUrl)
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/profile-image", method: "PATCH", body: requestBody)
    }

    /// Deletes the user's profile image.
    func deleteProfileImage() async throws -> User {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/users/me/profile-image", method: "DELETE", body: (nil as String?))
    }

    /// Submits the user's onboarding answers.
    func submitOnboarding(answers: OnboardingAnswers) async throws {
        let _: OnboardingAnswer = try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/onboarding/", method: "POST", body: answers)
    }

    /// Fetches the user's onboarding answers.
    func getOnboardingAnswers() async throws -> OnboardingAnswer {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/onboarding/", method: "GET", body: (nil as String?))
    }

    /// Tests network connectivity to the backend
    func testConnectivity() async throws -> Bool {
        do {
            let _: HealthResponse = try await networkService.makeAuthenticatedRequest(endpoint: "/health", method: "GET", body: (nil as String?))
            return true
        } catch {
            logger.error("API connectivity test failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Habit API Operations

    func fetchHabits() async throws -> [Habit] {
        return try await networkService.makeAuthenticatedRequest(endpoint: "/api/v1/habits/", method: "GET", body: (nil as String?))
    }

    func createHabit(_ habit: Habit) async throws -> Habit {
        let requestBody = HabitCreateRequest(
            name: habit.name,
            description: habit.description,
            frequency: habit.frequency,
            validationTime: habit.validationTime,
            difficulty: habit.difficulty,
            proofStyle: habit.proofStyle
        )
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/",
            method: "POST",
            body: requestBody
        )
    }

    func createHabit(from onboardingAnswer: OnboardingAnswer) async throws -> Habit {
        let requestBody = HabitCreateRequest(
            name: onboardingAnswer.habit_name,
            description: onboardingAnswer.habit_description,
            frequency: onboardingAnswer.frequency,
            validationTime: onboardingAnswer.validation_time,
            difficulty: onboardingAnswer.difficulty,
            proofStyle: onboardingAnswer.proof_style
        )
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/",
            method: "POST",
            body: requestBody
        )
    }

    func updateHabit(id: Int, data: Habit) async throws -> Habit {
        let requestBody = HabitCreateRequest(
            name: data.name,
            description: data.description,
            frequency: data.frequency,
            validationTime: data.validationTime,
            difficulty: data.difficulty,
            proofStyle: data.proofStyle
        )
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(id)",
            method: "PUT",
            body: requestBody
        )
    }

    func deleteHabit(id: Int) async throws {
        let _: EmptyResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(id)",
            method: "DELETE",
            body: (nil as String?)
        )
    }

    // MARK: - Motivation & Ability API Operations

    func submitMotivationEntry(habitId: Int, date: String, level: String) async throws -> MotivationEntryResponse {
        let req = MotivationEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/motivation",
            method: "POST",
            body: req
        )
    }

    func getTodayMotivationEntry(habitId: Int) async throws -> MotivationEntryResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/motivation/today",
            method: "GET",
            body: (nil as String?)
        )
    }

    func submitAbilityEntry(habitId: Int, date: String, level: String) async throws -> AbilityEntryResponse {
        let req = AbilityEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/ability",
            method: "POST",
            body: req
        )
    }

    func getTodayAbilityEntry(habitId: Int) async throws -> AbilityEntryResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/ability/today",
            method: "GET",
            body: (nil as String?)
        )
    }

    func updateMotivationEntry(habitId: Int, date: String, level: String) async throws -> MotivationEntryResponse {
        let req = MotivationEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/motivation/today",
            method: "PATCH",
            body: req
        )
    }

    func updateAbilityEntry(habitId: Int, date: String, level: String) async throws -> AbilityEntryResponse {
        let req = AbilityEntryRequest(habit_id: habitId, date: date, level: level)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/ability/today",
            method: "PATCH",
            body: req
        )
    }

    // MARK: - Task Management API Operations

    func generateAndCreateTask(habitId: Int, request: AITaskGenerationRequest) async throws -> TaskCreationResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/generate-and-create-task",
            method: "POST",
            body: request
        )
    }

    func getTodayTask(habitId: Int) async throws -> TaskEntry {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/\(habitId)/today-task",
            method: "GET",
            body: (nil as String?)
        )
    }

    func getPendingTasks(limit: Int = 10) async throws -> [TaskEntry] {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/pending-tasks?limit=\(limit)",
            method: "GET",
            body: (nil as String?)
        )
    }

    func submitTaskProof(taskId: Int, proofData: TaskProofSubmissionData) async throws -> TaskSubmissionResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/submit-proof",
            method: "POST",
            body: proofData
        )
    }

    func submitTaskProofWithFile(
        taskId: Int,
        proofType: String,
        proofContent: String,
        fileData: Data? = nil,
        fileName: String? = nil,
        mimeType: String? = nil
    ) async throws -> TaskSubmissionResponse {
        let textFields = [
            "proof_type": proofType,
            "proof_content": proofContent
        ]

        return try await networkService.submitMultipartForm(
            endpoint: "/api/v1/habits/tasks/\(taskId)/submit-proof",
            textFields: textFields,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            fileFieldName: "file"
        )
    }

    func updateTaskStatus(taskId: Int, status: String) async throws -> TaskStatusResponse {
        let request = TaskStatusUpdateRequest(status: status)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/status",
            method: "PUT",
            body: request
        )
    }

    func markTaskMissed(taskId: Int) async throws -> TaskStatusResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/\(taskId)/mark-missed",
            method: "PUT",
            body: (nil as String?)
        )
    }

    func checkAndMarkExpiredTasks() async throws -> ExpiredTasksResponse {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/habits/tasks/check-expired",
            method: "POST",
            body: (nil as String?)
        )
    }
}
