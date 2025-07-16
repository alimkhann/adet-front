import Foundation
import SwiftUI
import Clerk
import FirebaseAnalytics

@MainActor
class AuthViewModel: ObservableObject {
    private let authService = ClerkAuthService()
    private let apiService = APIService.shared
    private let toastManager = ToastManager.shared

    @Published var user: User?
    @Published var isClerkVerifying = false
    @Published var isUpdatingUsername = false
    @Published var isDeletingAccount = false
    @Published var isSigningOut = false
    @Published var isTestingNetwork = false
    @Published var networkStatus: Bool?

    private var pendingOnboardingAnswers: OnboardingAnswers?

    // Debouncing for username updates
    private var lastUsernameUpdateTime: Date = Date.distantPast
    private let usernameUpdateDebounceInterval: TimeInterval = 1.0 // 1 second

    // Profile image states
    @Published var isUploadingProfileImage = false
    @Published var isDeletingProfileImage = false
    @Published var jwtToken: String? = nil

    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding: Bool = false

    func fetchUser() async {
        do {
            self.user = try await apiService.getCurrentUser()
#if DEBUG
            print("Fetched user: \(String(describing: user?.username))")
#endif
            await fetchJWT()
        } catch {
#if DEBUG
            print("Failed to fetch user: \(error.localizedDescription)")
#endif
            self.user = nil
            AnalyticsHelper.logError(NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user: \(error.localizedDescription)"]))
        }
    }

    func syncUserFromClerk() async {
        do {
            self.user = try await apiService.syncUserFromClerk()
#if DEBUG
            print("Synced user from Clerk: \(String(describing: user?.username))")
#endif
        } catch {
#if DEBUG
            print("Failed to sync user from Clerk: \(error.localizedDescription)")
#endif
            AnalyticsHelper.logError(NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sync user from Clerk: \(error.localizedDescription)"]))
        }
    }

    func signUpClerk(email: String, password: String, username: String?, answers: OnboardingAnswers) async {
#if DEBUG
        print("Starting sign up in AuthViewModel...")
#endif
        self.pendingOnboardingAnswers = answers
        clearErrors()
        isClerkVerifying = false
        await authService.signUp(email: email, password: password, username: username)
        self.isClerkVerifying = authService.isVerifying
        if let error = authService.error {
            toastManager.showError(error)
            AnalyticsHelper.logError(NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign up user: \(error)"]))
            AnalyticsHelper.logEvent("registration_failed", parameters: ["email": email, "error": error])
        } else {
            AnalyticsHelper.logEvent("registration_success", parameters: ["email": email])
        }
#if DEBUG
        print("Sign up initiated, isVerifying: \(isClerkVerifying)")
#endif
        await fetchJWT()
        // Set onboarding flag after successful registration
        if authService.error == nil {
            shouldShowOnboarding = true
            if let user = self.user ?? Clerk.shared.user.map({
                User(
                    id: 0,
                    clerkId: $0.id,
                    email: $0.emailAddresses.first?.emailAddress ?? "",
                    name: $0.firstName ?? "",
                    username: $0.username,
                    bio: nil,
                    profileImageUrl: nil,
                    isActive: true,
                    createdAt: Date(),
                    updatedAt: nil,
                    plan: "free"
                )
            }) {
                AnalyticsHelper.setUserId(user.clerkId)
            }
        }
    }

    func verifyClerk(_ code: String) async {
#if DEBUG
        print("Starting verification in AuthViewModel...")
#endif
        clearErrors()
        await authService.verify(code: code)
        self.isClerkVerifying = authService.isVerifying
        if let error = authService.error {
            toastManager.showError(error)
            AnalyticsHelper.logError(NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to verify user: \(error)"]))
            AnalyticsHelper.logEvent("verification_failed", parameters: ["error": error])
        } else {
            AnalyticsHelper.logEvent("verification_success", parameters: nil)
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Try to sync user data from Clerk after successful verification
        await syncUserFromClerk()

        // If user was created or synced, submit onboarding answers
        if self.user != nil, let answers = pendingOnboardingAnswers {
            await submitOnboardingAnswers(answers)
            pendingOnboardingAnswers = nil // Clear after submitting
        } else if self.user == nil {
            // Fallback if sync fails
            if let clerkUser = Clerk.shared.user {
                self.user = User(
                    id: 0, // Will be set by backend when sync works
                    clerkId: clerkUser.id,
                    email: clerkUser.emailAddresses.first?.emailAddress ?? "",
                    name: clerkUser.firstName ?? "",
                    username: clerkUser.username,
                    bio: nil,
                    profileImageUrl: nil, // Will be set from backend
                    isActive: true,
                    createdAt: Date(),
                    updatedAt: nil,
                    plan: "free" // Add this line
                )
#if DEBUG
                print("Created fallback user object from Clerk data")
#endif
                // Still try to submit answers
                if let answers = pendingOnboardingAnswers {
                    await submitOnboardingAnswers(answers)
                    pendingOnboardingAnswers = nil // Clear after submitting
                }
            }
        }
        // Set user ID after verification
        if let user = self.user {
            AnalyticsHelper.setUserId(user.clerkId)
        }
    }

    func signInClerk(email: String, password: String) async {
#if DEBUG
        print("Starting sign in in AuthViewModel...")
#endif
        clearErrors()
        await authService.submit(email: email, password: password)

        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Try to sync user data from Clerk after successful sign in
        // If it fails, we'll still consider the user authenticated via Clerk
        await syncUserFromClerk()
#if DEBUG
        print("Sign in complete, user synced: \(String(describing: user?.username))")
#endif
        await fetchJWT()

        // If sync failed, create a minimal user object from Clerk data
        if self.user == nil {
            if let clerkUser = Clerk.shared.user {
                self.user = User(
                    id: 0, // Will be set by backend when sync works
                    clerkId: clerkUser.id,
                    email: clerkUser.emailAddresses.first?.emailAddress ?? "",
                    name: clerkUser.firstName ?? "",
                    username: clerkUser.username,
                    bio: nil,
                    profileImageUrl: nil, // Will be set from backend
                    isActive: true,
                    createdAt: Date(),
                    updatedAt: nil,
                    plan: "free" // Add this line
                )
#if DEBUG
                print("Created fallback user object from Clerk data")
#endif
            }
        }
        if let error = authService.error {
            toastManager.showError(error)
            AnalyticsHelper.logError(NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign in user: \(error)"]))
            AnalyticsHelper.logEvent("login_failed", parameters: ["email": email, "error": error])
        } else {
            AnalyticsHelper.logEvent("login_success", parameters: ["email": email])
            if let user = self.user {
                AnalyticsHelper.setUserId(user.clerkId)
            }
        }
    }

    func submitOnboardingAnswers(_ answers: OnboardingAnswers) async {
        do {
            try await apiService.submitOnboarding(answers: answers)
#if DEBUG
            print("Successfully submitted onboarding answers.")
#endif
            AnalyticsHelper.logEvent("onboarding_complete", parameters: nil)
        } catch {
#if DEBUG
            print("Failed to submit onboarding answers: \(error.localizedDescription)")
#endif
            toastManager.showError("Account created, but failed to save onboarding answers.")
            AnalyticsHelper.logError(NSError(domain: "AuthViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to submit onboarding answers: \(error.localizedDescription)"]))
        }
    }

    func deleteClerk() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            // First delete from backend
            try await apiService.deleteAccount()
#if DEBUG
            print("Account deleted from backend successfully")
#endif
            AnalyticsHelper.logEvent("account_deleted_backend", parameters: nil)

            // Then delete from Clerk
            await authService.delete()
#if DEBUG
            print("Account deleted from Clerk successfully")
#endif
            AnalyticsHelper.logEvent("account_deleted_clerk", parameters: nil)

            // Clear local user data
            self.user = nil
            AnalyticsHelper.logEvent("account_deleted", parameters: nil)

        } catch {
#if DEBUG
            print("Failed to delete account: \(error.localizedDescription)")
#endif
            AnalyticsHelper.logError(error)
            AnalyticsHelper.logEvent("account_delete_failed", parameters: ["error": error.localizedDescription])
            // Even if backend deletion fails, still try to delete from Clerk
            await authService.delete()
            self.user = nil
        }
    }

    func updateUsername(_ username: String) async {
        guard !username.isEmpty else { return }

        // Debouncing: prevent rapid updates
        let now = Date()
        if now.timeIntervalSince(lastUsernameUpdateTime) < usernameUpdateDebounceInterval {
#if DEBUG
            print("Username update debounced - too soon since last update")
#endif
            return
        }
        lastUsernameUpdateTime = now

        isUpdatingUsername = true
        defer { isUpdatingUsername = false }

        // Immediately update local user data for responsive UI
        if let currentUser = self.user {
            self.user = User(
                id: currentUser.id,
                clerkId: currentUser.clerkId,
                email: currentUser.email,
                name: currentUser.name ?? "",
                username: username,
                bio: currentUser.bio,
                profileImageUrl: currentUser.profileImageUrl,
                isActive: currentUser.isActive,
                createdAt: currentUser.createdAt,
                updatedAt: currentUser.updatedAt,
                plan: currentUser.plan // Add this line
            )
        }

        do {
            // Run backend and Clerk updates in parallel since they're independent
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.apiService.updateUsername(username)
#if DEBUG
                    print("Username updated in backend successfully")
#endif
                }

                group.addTask {
                    try await self.authService.updateUsername(username)
#if DEBUG
                    print("Username updated in Clerk successfully")
#endif
                }

                // Wait for both tasks to complete
                try await group.waitForAll()
            }

            // Clear any previous errors on success
            toastManager.dismiss()
            AnalyticsHelper.logEvent("username_updated", parameters: ["username": username])

        } catch {
#if DEBUG
            print("Failed to update username: \(error.localizedDescription)")
#endif
            AnalyticsHelper.logError(error)
            AnalyticsHelper.logEvent("username_update_failed", parameters: ["username": username, "error": error.localizedDescription])
            toastManager.showError("Failed to update username: \(error.localizedDescription)")

            // Revert local changes on error
            await fetchUser()
        }
    }

    func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        do {
            // Sign out from Clerk
            try await Clerk.shared.signOut()
#if DEBUG
            print("Signed out from Clerk successfully")
#endif
            AnalyticsHelper.logEvent("sign_out_success", parameters: nil)

            // Clear local user data
            self.user = nil

        } catch {
#if DEBUG
            print("Failed to sign out: \(error.localizedDescription)")
#endif
            AnalyticsHelper.logError(error)
            AnalyticsHelper.logEvent("sign_out_failed", parameters: ["error": error.localizedDescription])
            // Even if sign out fails, clear local data
            self.user = nil
        }
    }

    func testNetworkConnectivity() async {
        isTestingNetwork = true
        defer { isTestingNetwork = false }

        do {
            let isConnected = try await apiService.testConnectivity()
            self.networkStatus = isConnected
#if DEBUG
            print("Network connectivity test result: \(isConnected)")
#endif
        } catch {
            self.networkStatus = false
#if DEBUG
            print("Network connectivity test failed: \(error.localizedDescription)")
#endif
        }
    }

    func uploadProfileImage(_ imageData: Data, fileName: String, mimeType: String) async {
        isUploadingProfileImage = true
        defer { isUploadingProfileImage = false }

        do {
            let updatedUser = try await apiService.uploadProfileImage(imageData, fileName: fileName, mimeType: mimeType)
            self.user = updatedUser
            toastManager.dismiss()
#if DEBUG
            print("Profile image uploaded successfully")
#endif
        } catch {
#if DEBUG
            print("Failed to upload profile image: \(error.localizedDescription)")
#endif
            toastManager.showError("Failed to upload profile image: \(error.localizedDescription)")
        }
    }

    func updateProfileImageUrl(_ imageUrl: String) async {
        isUploadingProfileImage = true
        defer { isUploadingProfileImage = false }

        do {
            let updatedUser = try await apiService.updateProfileImageUrl(imageUrl)
            self.user = updatedUser
            toastManager.dismiss()
#if DEBUG
            print("Profile image URL updated successfully")
#endif
        } catch {
#if DEBUG
            print("Failed to update profile image URL: \(error.localizedDescription)")
#endif
            toastManager.showError("Failed to update profile image: \(error.localizedDescription)")
        }
    }

    func deleteProfileImage() async {
        isDeletingProfileImage = true
        defer { isDeletingProfileImage = false }

        do {
            let updatedUser = try await apiService.deleteProfileImage()
            self.user = updatedUser
            toastManager.dismiss()
#if DEBUG
            print("Profile image deleted successfully")
#endif
        } catch {
#if DEBUG
            print("Failed to delete profile image: \(error.localizedDescription)")
#endif
            toastManager.showError("Failed to delete profile image: \(error.localizedDescription)")
        }
    }

    func fetchJWT() async {
        do {
            if let token = try? await Clerk.shared.session?.getToken(.init(template: "adet-back"))?.jwt {
                DispatchQueue.main.async {
                    self.jwtToken = token
                }
            } else {
                DispatchQueue.main.async {
                    self.jwtToken = nil
                }
            }
        }
    }

    // Update name, username, and bio together
    func updateProfile(name: String, username: String, bio: String) async {
        do {
            let updatedUser = try await NetworkService.shared.updateProfile(name: name, username: username, bio: bio)
            self.user = updatedUser
            toastManager.dismiss()
            AnalyticsHelper.logEvent("profile_updated", parameters: ["username": username])
        } catch let NetworkError.requestFailed(statusCode, _) where statusCode == 409 {
            toastManager.showError("Username already taken. Please choose another.")
            AnalyticsHelper.logEvent("profile_update_failed", parameters: ["username": username, "error": "username_taken"])
        } catch {
            toastManager.showError("Failed to update profile: \(error.localizedDescription)")
            AnalyticsHelper.logError(error)
            AnalyticsHelper.logEvent("profile_update_failed", parameters: ["username": username, "error": error.localizedDescription])
        }
    }

    func clearErrors() {
        toastManager.dismiss()
    }
}
