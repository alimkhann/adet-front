import SwiftUI
import Foundation

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var friendRequestCount = 0
    @AppStorage("appLanguage") var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("home".t(appLanguage), systemImage: "house")
                }
                .tag(0)

            FriendsView()
                .tabItem {
                    Label("friends".t(appLanguage), systemImage: "person.2.fill")
                }
                .tag(1)
                .badge(friendsTabBadge)

            HabitsView()
                .tabItem {
                    Label("habits".t(appLanguage), systemImage: "book.fill")
                }
                .tag(2)

            ChatsView()
                .tabItem {
                    Label("chats".t(appLanguage), systemImage: "message")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("profile".t(appLanguage), systemImage: "person")
                }
                .tag(4)
        }
        .tint(.primary)
        .onAppear {
            // Configure tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.shadowColor = UIColor.separator

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            Task { @MainActor in
                await authViewModel.fetchUser()
                await updateFriendRequestCount()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            Task { @MainActor in
                await authViewModel.fetchUser()
                // Refresh friend request count when switching tabs
                if newValue == 1 { // Friends tab
                    await updateFriendRequestCount()
                }
            }
        }
        .accessibilityIdentifier("Tab Bar")
    }

    // MARK: - Computed Properties

    private var friendsTabBadge: String? {
        friendRequestCount > 0 ? "\(friendRequestCount)" : nil
    }

    // MARK: - Helper Methods

    private func updateFriendRequestCount() async {
        do {
            let response = try await FriendsAPIService.shared.getFriendRequests()
            friendRequestCount = response.incomingCount
        } catch {
            // Silently handle error - badge will remain at 0
            friendRequestCount = 0
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
}
