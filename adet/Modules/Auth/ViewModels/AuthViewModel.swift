import Foundation
import SwiftUI
import Clerk

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

    func fetchUser() async {
        do {
            self.user = try await apiService.getCurrentUser()
            print("Fetched user: \(String(describing: user?.username))")
            await fetchJWT()
        } catch {
            print("Failed to fetch user: \(error.localizedDescription)")
            self.user = nil
        }
    }

    func syncUserFromClerk() async {
        do {
            self.user = try await apiService.syncUserFromClerk()
            print("Synced user from Clerk: \(String(describing: user?.username))")
        } catch {
            print("Failed to sync user from Clerk: \(error.localizedDescription)")
        }
    }

    func signUpClerk(email: String, password: String, username: String?, answers: OnboardingAnswers) async {
        print("Starting sign up in AuthViewModel...")
        self.pendingOnboardingAnswers = answers
        clearErrors()
        isClerkVerifying = false
        await authService.signUp(email: email, password: password, username: username)
        self.isClerkVerifying = authService.isVerifying
        if let error = authService.error {
            toastManager.showError(error)
        }
        print("Sign up initiated, isVerifying: \(isClerkVerifying)")
        await fetchJWT()
    }

    func verifyClerk(_ code: String) async {
        print("Starting verification in AuthViewModel...")
        clearErrors()
        await authService.verify(code: code)
        self.isClerkVerifying = authService.isVerifying
        if let error = authService.error {
            toastManager.showError(error)
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
                print("Created fallback user object from Clerk data")
                // Still try to submit answers
                if let answers = pendingOnboardingAnswers {
                    await submitOnboardingAnswers(answers)
                    pendingOnboardingAnswers = nil // Clear after submitting
                }
            }
        }
    }

    func signInClerk(email: String, password: String) async {
        print("Starting sign in in AuthViewModel...")
        clearErrors()
        await authService.submit(email: email, password: password)

        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Try to sync user data from Clerk after successful sign in
        // If it fails, we'll still consider the user authenticated via Clerk
        await syncUserFromClerk()
        print("Sign in complete, user synced: \(String(describing: user?.username))")
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
                print("Created fallback user object from Clerk data")
            }
        }
        if let error = authService.error {
            toastManager.showError(error)
        }
    }

    func submitOnboardingAnswers(_ answers: OnboardingAnswers) async {
        do {
            try await apiService.submitOnboarding(answers: answers)
            print("Successfully submitted onboarding answers.")
        } catch {
            print("Failed to submit onboarding answers: \(error.localizedDescription)")
            toastManager.showError("Account created, but failed to save onboarding answers.")
        }
    }

    func deleteClerk() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            // First delete from backend
            try await apiService.deleteAccount()
            print("Account deleted from backend successfully")

            // Then delete from Clerk
            await authService.delete()
            print("Account deleted from Clerk successfully")

            // Clear local user data
            self.user = nil

        } catch {
            print("Failed to delete account: \(error.localizedDescription)")
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
            print("Username update debounced - too soon since last update")
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
                    print("Username updated in backend successfully")
                }

                group.addTask {
                    try await self.authService.updateUsername(username)
                    print("Username updated in Clerk successfully")
                }

                // Wait for both tasks to complete
                try await group.waitForAll()
            }

            // Clear any previous errors on success
            toastManager.dismiss()

        } catch {
            print("Failed to update username: \(error.localizedDescription)")
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
            print("Signed out from Clerk successfully")

            // Clear local user data
            self.user = nil

        } catch {
            print("Failed to sign out: \(error.localizedDescription)")
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
            print("Network connectivity test result: \(isConnected)")
        } catch {
            self.networkStatus = false
            print("Network connectivity test failed: \(error.localizedDescription)")
        }
    }

    func uploadProfileImage(_ imageData: Data, fileName: String, mimeType: String) async {
        isUploadingProfileImage = true
        defer { isUploadingProfileImage = false }

        do {
            let updatedUser = try await apiService.uploadProfileImage(imageData, fileName: fileName, mimeType: mimeType)
            self.user = updatedUser
            toastManager.dismiss()
            print("Profile image uploaded successfully")
        } catch {
            print("Failed to upload profile image: \(error.localizedDescription)")
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
            print("Profile image URL updated successfully")
        } catch {
            print("Failed to update profile image URL: \(error.localizedDescription)")
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
            print("Profile image deleted successfully")
        } catch {
            print("Failed to delete profile image: \(error.localizedDescription)")
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
        } catch let NetworkError.requestFailed(statusCode, _) where statusCode == 409 {
            toastManager.showError("Username already taken. Please choose another.")
        } catch {
            toastManager.showError("Failed to update profile: \(error.localizedDescription)")
        }
    }

    func clearErrors() {
        toastManager.dismiss()
    }
}
