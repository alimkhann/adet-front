import SwiftUI
import Clerk

@main
struct adetApp: App {
    @State private var clerk = Clerk.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if clerk.isLoaded {
                    RootView()
                } else {
                    ProgressView()
                }
            }
            .environment(clerk)
            .task {
                clerk.configure(publishableKey: "pk_test_dGVuZGVyLWFscGFjYS0xMC5jbGVyay5hY2NvdW50cy5kZXYk")
                try? await clerk.load()
            }
        }
    }
}
