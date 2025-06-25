import Foundation
import Clerk
import OSLog

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
}

// MARK: - API Response Types
struct HealthResponse: Codable {
    let status: String
    let database: String
}

struct UsernameUpdateRequest: Codable {
    let username: String
}

struct ProfileImageUpdateRequest: Codable {
    let profileImageUrl: String

    enum CodingKeys: String, CodingKey {
        case profileImageUrl = "profile_image_url"
    }
}

struct HabitCreateRequest: Codable {
    let name: String
    let description: String
    let frequency: String
    let validationTime: String
    let difficulty: String
    let proofStyle: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case frequency
        case validationTime = "validation_time"
        case difficulty
        case proofStyle = "proof_style"
    }
}

struct OnboardingAnswer: Codable {
    let id: Int
    let user_id: Int
    let habit_name: String
    let habit_description: String
    let frequency: String
    let validation_time: String
    let difficulty: String
    let proof_style: String
}
