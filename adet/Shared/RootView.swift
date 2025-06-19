import SwiftUI
import Clerk

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    
    var body: some View {
        if clerk.user != nil {
            TabBarView()
        } else {
            WelcomeView()
        }
    }
}
