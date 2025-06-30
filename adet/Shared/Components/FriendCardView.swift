import SwiftUI

struct FriendCardView: View {
    let friend: Friend
    let isRemoving: Bool
    let onRemove: () -> Void

    @State private var showRemoveAlert = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            ProfileImageView(
                user: User(
                    id: friend.friend.id,
                    clerkId: "",
                    email: "",
                    name: friend.friend.name,
                    username: friend.friend.username,
                    bio: friend.friend.bio,
                    profileImageUrl: friend.friend.profileImageUrl,
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
                Text(friend.friend.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("@\(friend.friend.displayUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let bio = friend.friend.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Remove Button
            if isRemoving {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    showRemoveAlert = true
                }) {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .alert("Remove Friend", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove \(friend.friend.displayName) from your friends list?")
        }
    }
}

#Preview {
    FriendCardView(
        friend: Friend(
            id: 1,
            userId: 1,
            friendId: 2,
            friend: UserBasic(
                id: 2,
                username: "john_doe",
                name: "John Doe",
                bio: "Love building healthy habits!",
                profileImageUrl: nil
            ),
            status: "active",
            createdAt: Date(),
            updatedAt: nil
        ),
        isRemoving: false,
        onRemove: { }
    )
    .environmentObject(AuthViewModel())
    .padding()
}