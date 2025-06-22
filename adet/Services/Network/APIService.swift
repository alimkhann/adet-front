import Foundation
import Clerk
import OSLog

// MARK: - API Service
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
}

// MARK: - API Response Types
struct HealthResponse: Codable {
    let status: String
    let database: String
}

struct UsernameUpdateRequest: Codable {
    let username: String
}
