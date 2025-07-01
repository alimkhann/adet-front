import Foundation
import Clerk
import OSLog

/// Service for handling authentication tokens and API authentication
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let logger = Logger(subsystem: "com.adet.auth", category: "AuthService")

    private init() {}

    /// Get a valid authentication token for API calls
    func getValidToken() async -> String? {
        do {
            // Get session token from Clerk
            if let session = Clerk.shared.session {
                let tokenResource = try await session.getToken()
                let token = tokenResource?.jwt
                logger.debug("Successfully retrieved auth token")
                return token
            } else {
                logger.warning("No active Clerk session found")
                return nil
            }
        } catch {
            logger.error("Failed to get auth token: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if user is currently authenticated
    var isAuthenticated: Bool {
        return Clerk.shared.user != nil
    }

    /// Get current user ID if authenticated
    var currentUserId: String? {
        return Clerk.shared.user?.id
    }

    /// Get current user
    var currentUser: User? {
        // Note: This returns nil since we don't have a direct mapping from Clerk.User to our User model
        // The actual user data should be fetched from the API using getCurrentUser() method in APIService
        return nil
    }
}