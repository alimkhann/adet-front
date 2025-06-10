import SwiftUI

@main
struct adetApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if authViewModel.user == nil {
                    WelcomeView()
                        .environmentObject(authViewModel)
                } else {
                    TabBarView()
                        .environmentObject(authViewModel)
                }
            }
        }
    }
}
