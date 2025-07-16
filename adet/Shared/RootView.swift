import SwiftUI
import Clerk

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

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
            Task { @MainActor in
                if newUser != nil {
                    // User signed in, refresh authentication state
                    await authManager.forceRefreshAuthentication()
                } else {
                    // User signed out, update state immediately
                    await authManager.handleSignOut()
                }
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { shouldShowOnboarding && authManager.isAuthenticated },
            set: { _ in }
        )) {
            OnboardingView(onFinish: {
                shouldShowOnboarding = false
            })
        }
    }
}