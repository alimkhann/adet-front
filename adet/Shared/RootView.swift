import SwiftUI
import Clerk

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        if clerk.user != nil {
            TabBarView()
                .environmentObject(authViewModel)
        } else {
            WelcomeView()
                .environmentObject(authViewModel)
        }
    }
}
