import SwiftUI
import Foundation

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var friendRequestCount = 0
    @State private var hasLoadedUser = false
    @State private var hasLoadedFriendRequests = false
    @StateObject private var postsViewModel = PostsViewModel()
    @StateObject private var profileViewModel = ProfileViewModel(authViewModel: AuthViewModel())
    @AppStorage("appLanguage") var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("home".t(appLanguage), systemImage: "house")
                }
                .tag(0)
                .environmentObject(profileViewModel)
                .environmentObject(postsViewModel)

            FriendsView()
                .tabItem {
                    Label("friends".t(appLanguage), systemImage: "person.2.fill")
                }
                .tag(1)
                .badge(friendsTabBadge)
                .environmentObject(profileViewModel)

            HabitsView()
                .tabItem {
                    Label("habits".t(appLanguage), systemImage: "book.fill")
                }
                .tag(2)
                .environmentObject(postsViewModel)
                .environmentObject(profileViewModel)

            ChatsView()
                .tabItem {
                    Label("chats".t(appLanguage), systemImage: "message")
                }
                .tag(3)
                .environmentObject(profileViewModel)

            ProfileView()
                .tabItem {
                    Label("profile".t(appLanguage), systemImage: "person")
                }
                .tag(4)
                .environmentObject(profileViewModel)
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
                if !hasLoadedUser {
                    await authViewModel.fetchUser()
                    hasLoadedUser = true
                }
                if !hasLoadedFriendRequests {
                    await updateFriendRequestCount()
                    hasLoadedFriendRequests = true
                }
            }
            profileViewModel.updateAuthViewModel(authViewModel)
        }
        .onChange(of: selectedTab) { _, newValue in
            Task { @MainActor in
                if !hasLoadedUser {
                    await authViewModel.fetchUser()
                    hasLoadedUser = true
                }
                // Refresh friend request count only when switching to Friends tab
                if newValue == 1 && !hasLoadedFriendRequests {
                    await updateFriendRequestCount()
                    hasLoadedFriendRequests = true
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
