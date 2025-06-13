import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    private let authService: AuthenticationServiceProtocol

    @Published var user: User?
    @Published var authError: String?
    @Published var isLoading = false

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
