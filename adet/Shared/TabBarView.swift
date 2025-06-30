import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

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
        .onChange(of: selectedTab) { _, newValue in
            Task { @MainActor in
                await authViewModel.fetchUser()
            }
        }
        .onAppear {
            Task { @MainActor in
                await authViewModel.fetchUser()
            }
        }
        .accessibilityIdentifier("Tab Bar")
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
}
