import SwiftUI

struct TabBarView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.crop.circle")
                }
            
            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "book.fill")
                }
            
            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .accessibilityIdentifier("Tab Bar")
    }
}

#Preview {
    TabBarView()
}
