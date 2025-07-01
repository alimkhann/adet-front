import SwiftUI

struct UserSearchCardView: View {
    let user: UserBasic
    let onAddFriend: () -> Void

    @State private var friendshipStatus: FriendshipStatus = .none
    @State private var isLoading = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationLink(destination: OtherUserProfileView(userId: user.id).environmentObject(authViewModel)) {
            HStack(spacing: 16) {
                // Profile Image
                ProfileImageView(
                    user: User(
                        id: user.id,
                        clerkId: "",
                        email: "",
                        name: user.displayName,
                        username: user.username,
                        bio: user.bio,
                        profileImageUrl: user.profileImageUrl,
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

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("@\(user.displayUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

                // Action Button
                actionButton
            }
        }
        .foregroundColor(.primary) // Ensure text color for NavigationLink
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            loadFriendshipStatus()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isLoading {
            ProgressView()
                .scaleEffect(0.8)
        } else {
            switch friendshipStatus {
            case .none:
                Button(action: onAddFriend) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Add")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }

            case .friends:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Friends")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

            case .requestSent:
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                    Text("Sent")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

            case .requestReceived:
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 12, weight: .medium))
                    Text("Respond")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func loadFriendshipStatus() {
        isLoading = true
        Task {
            do {
                let response = try await FriendsAPIService.shared.getFriendshipStatus(userId: user.id)
                await MainActor.run {
                    friendshipStatus = response
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    friendshipStatus = .none
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        UserSearchCardView(
            user: UserBasic(
                id: 1,
                username: "alex_runner",
                name: "Alex Runner",
                bio: "Marathon enthusiast and habit tracker 🏃‍♂️",
                profileImageUrl: nil
            ),
            onAddFriend: { }
        )

        UserSearchCardView(
            user: UserBasic(
                id: 2,
                username: "sara_yoga",
                name: "Sara Yoga",
                bio: nil,
                profileImageUrl: nil
            ),
            onAddFriend: { }
        )
    }
    .environmentObject(AuthViewModel())
    .padding()
}
