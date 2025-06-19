import Foundation
import SwiftUI
import Clerk

@MainActor
class AuthViewModel: ObservableObject {
    private let authService = ClerkAuthService()

    @Published var user: User?
    @Published var isClerkVerifying = false
    @Published var clerkError: String?

    func fetchUser() {
        self.user = Clerk.shared.user
    }

    func signUpClerk(email: String, password: String, username: String?) async {
        clerkError = nil
        isClerkVerifying = false
        await authService.signUp(email: email, password: password, username: username)
        self.isClerkVerifying = authService.isVerifying
        self.clerkError = authService.error
    }

    func verifyClerk(_ code: String) async {
        clerkError = nil
        await authService.verify(code: code)
        self.isClerkVerifying = authService.isVerifying
        self.clerkError = authService.error
        self.user = Clerk.shared.user
    }

    func signInClerk(email: String, password: String) async {
        clerkError = nil
        await authService.submit(email: email, password: password)
        self.user = Clerk.shared.user
    }

    func deleteClerk() async {
        await authService.delete()
        self.user = nil
    }
}
