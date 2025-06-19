import Foundation
import Clerk

@MainActor
class ClerkAuthService: ObservableObject {
    @Published var isVerifying = false
    @Published var error: String?
    private var signUp: SignUp?
    private var pendingUsername: String?

    // sign up
    func signUp(email: String, password: String, username: String?) async {
        do {
            let signUp = try await SignUp.create(
                strategy: .standard(emailAddress: email, password: password)
            )
            try await signUp.prepareVerification(strategy: .emailCode)
            self.signUp = signUp
            self.pendingUsername = username
            isVerifying = true
        } catch {
            self.error = error.localizedDescription
            isVerifying = false
        }
    }

    func verify(code: String) async {
        do {
            guard let signUp = Clerk.shared.client?.signUp ?? self.signUp else {
                isVerifying = false
                return
            }
            try await signUp.attemptVerification(strategy: .emailCode(code: code))
            isVerifying = false
            // Set username after verification if provided
            if let username = pendingUsername, let user = Clerk.shared.user {
                try? await user.update(.init(username: username))
                pendingUsername = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // sign in
    func submit(email: String, password: String) async {
        do {
            try await SignIn.create(
                strategy: .identifier(email, password: password)
            )
        } catch {
            dump(error)
        }
    }

    func delete() async {
        do {
            if let user = Clerk.shared.user {
                try await user.delete()
                try? await Clerk.shared.signOut()
            }
        } catch {
            dump(error)
        }
    }
}
