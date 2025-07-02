import SwiftUI
import OSLog

struct CloseFriendsManagementView: View {
    @StateObject private var viewModel = CloseFriendsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showClearAllAlert = false

    private let logger = Logger(subsystem: "com.adet.friends", category: "CloseFriendsManagementView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)

                // Main content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.allFriends.isEmpty {
                    emptyFriendsView
                } else {
                    mainContent
                }

                // Done button at bottom
                VStack {
                    Button {
                        Task {
                            await viewModel.saveChanges()
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Done")
                            .frame(minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
            }
            .navigationTitle("Close Friends")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .alert("Clear All Close Friends", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    Task {
                        await clearAllCloseFriends()
                    }
                }
            } message: {
                Text("Are you sure you want to remove all close friends? This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search friends", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .foregroundColor(.accentColor)
                .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with count and clear all
                headerSection
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                // Friends list
                LazyVStack(spacing: 8) {
                    ForEach(sortedAndFilteredFriends) { friend in
                        CloseFriendRowView(
                            friend: friend.user,
                            isCloseFriend: viewModel.isCloseFriend(friend.user.id),
                            canAddMore: true,
                            onToggle: { isCloseFriend in
                                viewModel.updateCloseFriend(friend.user, isCloseFriend: isCloseFriend)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Text(closeFriendsCountText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if viewModel.getCloseFriendsCount() > 0 {
                Button("Clear All") {
                    showClearAllAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading friends...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Friends View

    private var emptyFriendsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Add some friends first to create your close friends list")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Helper Properties

    private var closeFriendsCountText: String {
        let count = viewModel.getCloseFriendsCount()
        return count == 1 ? "1 person" : "\(count) people"
    }

    private var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return viewModel.allFriends
        } else {
            return viewModel.allFriends.filter { friend in
                friend.user.displayName.localizedCaseInsensitiveContains(searchText) ||
                friend.user.displayUsername.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var sortedAndFilteredFriends: [Friend] {
        filteredFriends.sorted { first, second in
            let firstIsClose = viewModel.isCloseFriend(first.user.id)
            let secondIsClose = viewModel.isCloseFriend(second.user.id)

            // Close friends first
            if firstIsClose && !secondIsClose {
                return true
            } else if !firstIsClose && secondIsClose {
                return false
            } else {
                // Within the same group, sort alphabetically
                return first.user.displayName < second.user.displayName
            }
        }
    }

    // MARK: - Actions

    private func clearAllCloseFriends() async {
        for friend in viewModel.allFriends {
            if viewModel.isCloseFriend(friend.user.id) {
                viewModel.updateCloseFriend(friend.user, isCloseFriend: false)
            }
        }
    }
}

// MARK: - Close Friend Row View

struct CloseFriendRowView: View {
    let friend: UserBasic
    let isCloseFriend: Bool
    let canAddMore: Bool
    let onToggle: (Bool) -> Void

    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            ProfileImageView(
                user: User(
                    id: friend.id,
                    clerkId: "",
                    email: "",
                    name: friend.displayName,
                    username: friend.username,
                    bio: friend.bio,
                    profileImageUrl: friend.profileImageUrl,
                    isActive: true,
                    createdAt: Date(),
                    updatedAt: nil
                ),
                size: 50,
                isEditable: false,
                onImageTap: nil,
                onDeleteTap: nil,
                jwtToken: authViewModel.jwtToken
            )

            // Friend info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("@\(friend.displayUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Circle toggle button
            Button(action: {
                let newState = !isCloseFriend
                HapticManager.shared.selection()
                onToggle(newState)
            }) {
                ZStack {
                    Circle()
                        .stroke(isCloseFriend ? Color.accentColor : Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(isCloseFriend ? Color.accentColor : Color.clear)
                                .frame(width: 20, height: 20)
                        )

                    if isCloseFriend {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(isCloseFriend ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: isCloseFriend)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    NavigationStack {
        CloseFriendsManagementView()
            .environmentObject(AuthViewModel())
    }
}
