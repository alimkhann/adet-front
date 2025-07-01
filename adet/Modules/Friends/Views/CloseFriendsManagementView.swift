import SwiftUI
import OSLog

struct CloseFriendsManagementView: View {
    @StateObject private var viewModel = CloseFriendsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(subsystem: "com.adet.friends", category: "CloseFriendsManagementView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Friends list
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.allFriends.isEmpty {
                    emptyFriendsView
                } else {
                    friendsListView
                }

                Spacer()
            }
            .navigationTitle("Close Friends")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
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

    // MARK: - Friends List View

    private var friendsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.allFriends) { friend in
                    CloseFriendRowView(
                        friend: friend.user,
                        isCloseFriend: viewModel.isCloseFriend(friend.user.id),
                        canAddMore: true,
                        onToggle: { isCloseFriend in
                            Task {
                                await viewModel.updateCloseFriend(friend.user, isCloseFriend: isCloseFriend)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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

            // Toggle button
            Button(action: {
                let newState = !isCloseFriend
                HapticManager.shared.selection()
                onToggle(newState)
            }) {
                Image(systemName: isCloseFriend ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(isCloseFriend ? .red : .gray)
                    .animation(.easeInOut(duration: 0.2), value: isCloseFriend)
            }
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
