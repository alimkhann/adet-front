import Foundation
import SwiftUI
import OSLog
import Clerk

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let logger = Logger(subsystem: "com.adet.auth", category: "AuthManager")

    // Cache to prevent redundant API calls
    private var lastAuthCheck: Date = .distantPast
    private let authCheckCooldown: TimeInterval = 5.0 // 5 seconds

    func checkAuthentication() async {
        logger.info("Checking authentication status...")

        // Check if we recently performed an auth check
        let now = Date()
        if now.timeIntervalSince(lastAuthCheck) < authCheckCooldown {
            logger.info("Skipping auth check - too recent")
            return
        }

        isLoading = true
        errorMessage = nil
        lastAuthCheck = now

        // First check if Clerk has an authenticated user
        if let user = Clerk.shared.user {
            logger.info("Clerk user found: \(user.id)")
            self.isAuthenticated = true

            // Try to sync user data from backend, but don't fail if it doesn't work
            do {
                let _ = try await apiService.getCurrentUser()
                logger.info("Backend user data synced successfully.")
            } catch {
                logger.warning("Failed to sync backend user data: \(error.localizedDescription)")
                // Don't set error message or change authentication status
                // The user is still authenticated via Clerk
            }
        } else {
            logger.info("No Clerk user found")
            self.isAuthenticated = false
            self.errorMessage = "User is not authenticated."
        }

        isLoading = false
    }

    func forceRefreshAuthentication() async {
        lastAuthCheck = .distantPast // Reset the cooldown
        await checkAuthentication()
    }

    func handleSignOut() async {
        isAuthenticated = false
        isLoading = false
        errorMessage = nil
        logger.info("User signed out - authentication state updated")
    }
}