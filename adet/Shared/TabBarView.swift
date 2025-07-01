import SwiftUI
import Foundation

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var friendRequestCount = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.crop.circle")
                }
                .tag(1)
                .badge(friendsTabBadge)

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "book.fill")
                }
                .tag(2)

            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(4)
        }
        .tint(.primary)
        .onAppear {
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
