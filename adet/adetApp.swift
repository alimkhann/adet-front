import SwiftUI
import Clerk

@main
struct adetApp: App {
    @State private var clerk = Clerk.shared
    @StateObject private var authManager = AuthManager()
    @AppStorage("appTheme") private var themeRawValue: String = Theme.system.rawValue
    @AppStorage("appLanguage") var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    var body: some Scene {
        WindowGroup {
            ZStack {
                if clerk.isLoaded {
                    RootView()
                } else {
                    ProgressView()
                }
            }
            .preferredColorScheme(Theme(rawValue: themeRawValue)?.colorScheme)
            .environment(clerk)
            .environmentObject(authManager)
            .environment(\.locale, .init(identifier: appLanguage))
            .task {
                clerk.configure(publishableKey: "pk_live_Y2xlcmsudHJ5YWRldC5jb20k")
                try? await clerk.load()
            }
        }
    }
}
