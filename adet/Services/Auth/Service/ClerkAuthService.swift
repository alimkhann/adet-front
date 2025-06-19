import Foundation
import Clerk

@MainActor
class ClerkAuthService: ObservableObject {
    @Published var isVerifying = false
    @Published var error: String?
    private var signUp: SignUp?
    private var pendingUsername: String?
    private var pendingEmail: String?
    private var pendingPassword: String?

    // sign up
    func signUp(email: String, password: String, username: String?) async {
        do {
            print("Starting sign up process...")

            // First check if we have any existing sign up
            if let existingSignUp = self.signUp {
                print("Found existing sign up, cleaning up...")
                self.signUp = nil
            }

            // Create new sign up
            let signUp = try await SignUp.create(
                strategy: .standard(emailAddress: email, password: password)
            )

            // Store username for later if provided
            if let username = username, !username.isEmpty {
                self.pendingUsername = username
            }

            // Check if email verification is required
            if signUp.unverifiedFields.contains("email_address") {
                print("Email verification required")
                try await signUp.prepareVerification(strategy: .emailCode)
                self.signUp = signUp
                self.isVerifying = true
                print("Sign up prepared, waiting for verification...")
            } else {
                // If no verification needed, try to set username immediately
                if let username = self.pendingUsername {
                    print("Setting username...")
                    try await signUp.update(params: .init(username: username))
                }
                self.signUp = nil
                print("Sign up completed without verification needed")
            }
        } catch {
            print("Sign up error: \(error.localizedDescription)")
            self.error = error.localizedDescription
            self.isVerifying = false
            self.signUp = nil
        }
    }

    func verify(code: String) async {
        do {
            print("Starting verification process...")
            guard let signUp = self.signUp else {
                print("No sign up session found")
                isVerifying = false
                error = "No sign up session found"
                return
            }

            print("Attempting verification...")
            // Verify the email
            try await signUp.attemptVerification(strategy: .emailCode(code: code))
            print("Code verification successful")

            // After verification, check if we need to set the username
            if let username = self.pendingUsername {
                print("Setting username: \(username)")
                try await signUp.update(params: .init(username: username))
                print("Username set successfully")
            }

            // Wait briefly for everything to be processed
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Verify we have a user
            if let user = Clerk.shared.user {
                print("User created and signed in successfully: \(user.id)")
            } else {
                print("User verification succeeded but no user object found")
                error = "Failed to complete sign up"
            }

            // Clean up
            self.signUp = nil
            self.pendingUsername = nil
            self.isVerifying = false

        } catch let error as ClerkAPIError {
            print("Verification error: \(error.code)")
            dump(error)

            switch error.code {
            case "form_code_incorrect":
                self.error = "Incorrect verification code"
            case "form_identifier_not_found":
                self.error = "Account not found"
            case "form_password_incorrect":
                self.error = "Incorrect password"
            default:
                self.error = error.message ?? error.localizedDescription
            }

            self.isVerifying = false
        } catch {
            print("Unexpected error: \(error)")
            self.error = error.localizedDescription
            self.isVerifying = false
        }
    }

    // sign in
    func submit(email: String, password: String) async {
        do {
            print("Attempting sign in...")
            try await SignIn.create(
                strategy: .identifier(email, password: password)
            )

            // Wait briefly for session to be established
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            if let user = Clerk.shared.user {
                print("Sign in successful for user: \(user.id)")
            } else {
                print("Sign in completed but no user found")
                self.error = "Failed to establish session"
            }
        } catch let error as ClerkAPIError {
            print("Sign in error: \(error.code)")

            switch error.code {
            case "form_identifier_not_found":
                self.error = "Account not found. Please sign up first."
            case "form_password_incorrect":
                self.error = "Incorrect password"
            default:
                self.error = error.message ?? error.localizedDescription
            }
        } catch {
            print("Unexpected error: \(error)")
            self.error = error.localizedDescription
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

    func updateUsername(_ username: String) async throws {
        if let user = Clerk.shared.user {
            try await user.update(.init(username: username))
        }
    }
}
