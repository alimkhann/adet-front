import SwiftUI
import Clerk

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        ZStack {
            if authManager.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if authManager.isAuthenticated {
                TabBarView()
                    .environmentObject(authViewModel)
            } else {
                WelcomeView()
                    .environmentObject(authViewModel)
            }

            // Global toast overlay
            ToastOverlay()
        }
        .onAppear {
            Task {
                await authManager.checkAuthentication()
            }
        }
        .onChange(of: clerk.user) { _, newUser in
            Task {
                if newUser != nil {
                    // User signed in, refresh authentication state
                    await authManager.forceRefreshAuthentication()
                } else {
                    // User signed out, update state immediately
                    authManager.isAuthenticated = false
                    authManager.isLoading = false
                }
            }
        }
    }
}
