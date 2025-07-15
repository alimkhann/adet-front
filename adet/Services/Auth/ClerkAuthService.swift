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
#if DEBUG
            print("Starting sign up process...")
#endif
            // First check if we have any existing sign up
            if self.signUp != nil {
#if DEBUG
                print("Found existing sign up, cleaning up...")
#endif
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
#if DEBUG
                print("Email verification required")
#endif
                try await signUp.prepareVerification(strategy: .emailCode)
                self.signUp = signUp
                self.isVerifying = true
#if DEBUG
                print("Sign up prepared, waiting for verification...")
#endif
            } else {
                // If no verification needed, try to set username immediately
                if let username = self.pendingUsername {
#if DEBUG
                    print("Setting username...")
#endif
                    try await signUp.update(params: .init(username: username))
                }
                self.signUp = nil
#if DEBUG
                print("Sign up completed without verification needed")
#endif
            }
        } catch let error as ClerkAPIError {
#if DEBUG
            print("Sign up error: \(error.localizedDescription)")
#endif
            self.error = error.localizedDescription
            self.isVerifying = false
            self.signUp = nil
        } catch {
            #if DEBUG
            print("Sign up unexpected error: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
            self.isVerifying = false
            self.signUp = nil
        }
    }

    func verify(code: String) async {
        do {
#if DEBUG
            print("Starting verification process...")
#endif
            guard let signUp = self.signUp else {
#if DEBUG
                print("No sign up session found")
#endif
                isVerifying = false
                error = "No sign up session found"
                return
            }
#if DEBUG
            print("Attempting verification...")
#endif
            // Verify the email
            try await signUp.attemptVerification(strategy: .emailCode(code: code))
#if DEBUG
            print("Code verification successful")
#endif
            // After verification, check if we need to set the username
            if let username = self.pendingUsername {
#if DEBUG
                print("Setting username: \(username)")
#endif
                try await signUp.update(params: .init(username: username))
#if DEBUG
                print("Username set successfully")
#endif
            }
            // Wait briefly for everything to be processed
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // Verify we have a user
            if let user = Clerk.shared.user {
#if DEBUG
                print("User created and signed in successfully: \(user.id)")
#endif
            } else {
#if DEBUG
                print("User verification succeeded but no user object found")
#endif
                error = "Failed to complete sign up"
            }
            // Clean up
            self.signUp = nil
            self.pendingUsername = nil
            self.isVerifying = false
        } catch let error as ClerkAPIError {
#if DEBUG
            print("Verification error: \(error.code)")
            dump(error)
#endif
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
            #if DEBUG
            print("Verification unexpected error: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
            self.isVerifying = false
        }
    }

    // sign in
    func submit(email: String, password: String) async {
        do {
#if DEBUG
            print("Attempting sign in...")
#endif
            try await SignIn.create(
                strategy: .identifier(email, password: password)
            )
            // Wait briefly for session to be established
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let user = Clerk.shared.user {
#if DEBUG
                print("Sign in successful for user: \(user.id)")
#endif
            } else {
#if DEBUG
                print("Sign in completed but no user found")
#endif
                self.error = "Failed to establish session"
            }
        } catch let error as ClerkAPIError {
#if DEBUG
            print("Sign in error: \(error.code)")
#endif
            switch error.code {
            case "form_identifier_not_found":
                self.error = "Account not found. Please sign up first."
            case "form_password_incorrect":
                self.error = "Incorrect password"
            default:
                self.error = error.message ?? error.localizedDescription
            }
        } catch {
            #if DEBUG
            print("Sign in unexpected error: \(error.localizedDescription)")
            #endif
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
