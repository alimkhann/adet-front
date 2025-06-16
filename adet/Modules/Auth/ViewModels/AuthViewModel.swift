import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    private let authService: AuthenticationServiceProtocol

    @Published var user: User?
    @Published var authError: String?
    @Published var isLoading = false
    @Published var showAccountDeletedAlert = false

    init(authService: AuthenticationServiceProtocol = AuthenticationService()) {
        self.authService = authService
        Task {
            await fetchUser()
        }
    }

    func signUp(email: String, username: String, password: String) {
        Task {
            isLoading = true
            authError = nil

            do {
                self.user = try await authService.signUp(email: email, username: username, password: password)
            } catch let error as AuthenticationError {
                authError = error.localizedDescription
            } catch {
                authError = "An unexpected error occurred"
            }

            isLoading = false
        }
    }

    func signIn(email: String, password: String) {
        Task {
            isLoading = true
            authError = nil

            do {
                self.user = try await authService.signIn(email: email, password: password)
            } catch let error as AuthenticationError {
                authError = error.localizedDescription
            } catch {
                authError = "An unexpected error occurred"
            }

            isLoading = false
        }
    }

    func updateUsername(newUsername: String) {
        Task {
            isLoading = true
            authError = nil
            do {
                self.user = try await authService.updateUsername(newUsername: newUsername)
            } catch let error as AuthenticationError {
                authError = error.localizedDescription
            } catch {
                authError = "An unexpected error occurred during username update"
            }
            isLoading = false
        }
    }

    func updatePassword(currentPassword: String, newPassword: String) {
        Task {
            isLoading = true
            authError = nil
            do {
                try await authService.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            } catch let error as AuthenticationError {
                authError = error.localizedDescription
            } catch {
                authError = "An unexpected error occurred during password reset"
            }
            isLoading = false
        }
    }

    func deleteAccount() {
        Task {
            isLoading = true
            authError = nil
            do {
                try await authService.deleteAccount()
                user = nil // Clear user on successful deletion
                showAccountDeletedAlert = true // Trigger alert
            } catch let error as AuthenticationError {
                authError = error.localizedDescription
            } catch {
                authError = "An unexpected error occurred during account deletion"
            }
            isLoading = false
        }
    }

    func signOut() {
        Task {
            isLoading = true
            do {
                try await authService.signOut()
                user = nil
                authError = nil
            } catch {
                authError = "Failed to sign out"
            }
            isLoading = false
        }
    }

    private func fetchUser() async {
        user = await authService.currentUser
    }
}
