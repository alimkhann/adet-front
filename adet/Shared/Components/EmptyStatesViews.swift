import SwiftUI

// MARK: - Empty Friends View

struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text("No Friends Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Start building your network! Use the search above to find friends and send them requests.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Requests View

struct EmptyRequestsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            Text("No Friend Requests")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("When someone sends you a friend request or you send one to others, they'll appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Search View

struct EmptySearchView: View {
    let query: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: query.isEmpty ? "magnifyingglass" : "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 40)

            if query.isEmpty {
                Text("Search for Friends")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Enter a username in the search bar above to find friends to connect with.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("No Results")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("No users found for \"\(query)\". Try searching with a different username.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Empty Friends") {
    EmptyFriendsView()
}

#Preview("Empty Requests") {
    EmptyRequestsView()
}

#Preview("Empty Search - No Query") {
    EmptySearchView(query: "")
}

#Preview("Empty Search - With Query") {
    EmptySearchView(query: "johndoe")
}