import Foundation
import SwiftUI
import Clerk

@MainActor
class AuthViewModel: ObservableObject {
    private let authService = ClerkAuthService()

    @Published var user: User?
    @Published var isClerkVerifying = false
    @Published var clerkError: String?
    @Published var isUpdatingUsername = false

    func fetchUser() {
        self.user = Clerk.shared.user
        print("Fetched user: \(String(describing: user?.username))")
    }

    func signUpClerk(email: String, password: String, username: String?) async {
        print("Starting sign up in AuthViewModel...")
        clerkError = nil
        isClerkVerifying = false
        await authService.signUp(email: email, password: password, username: username)
        self.isClerkVerifying = authService.isVerifying
        self.clerkError = authService.error
        print("Sign up initiated, isVerifying: \(isClerkVerifying)")
    }

    func verifyClerk(_ code: String) async {
        print("Starting verification in AuthViewModel...")
        clerkError = nil
        await authService.verify(code: code)
        self.isClerkVerifying = authService.isVerifying
        self.clerkError = authService.error

        // Wait briefly for the session to be established
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Fetch user after verification
        fetchUser()
        print("Verification complete, user: \(String(describing: user?.username))")
    }

    func signInClerk(email: String, password: String) async {
        print("Starting sign in in AuthViewModel...")
        clerkError = nil
        await authService.submit(email: email, password: password)

        // Wait briefly for the session to be established
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Fetch user after sign in
        fetchUser()
        self.clerkError = authService.error
        print("Sign in complete, user: \(String(describing: user?.username))")
    }

    func deleteClerk() async {
        await authService.delete()
        self.user = nil
    }

    func updateUsername(_ username: String) async {
        guard !username.isEmpty else { return }
        isUpdatingUsername = true
        do {
            try await authService.updateUsername(username)
            fetchUser()
        } catch {
            self.clerkError = error.localizedDescription
        }
        isUpdatingUsername = false
    }
}
