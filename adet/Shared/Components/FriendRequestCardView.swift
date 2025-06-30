import SwiftUI

struct FriendRequestCardView: View {
    let request: FriendRequest
    let isIncoming: Bool
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var authViewModel: AuthViewModel

    private var displayUser: UserBasic {
        isIncoming ? request.sender : request.receiver
    }

    private var actionText: String {
        if isIncoming {
            return "wants to be friends"
        } else {
            return "request sent"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            ProfileImageView(
                user: User(
                    id: displayUser.id,
                    clerkId: "",
                    email: "",
                    name: displayUser.name,
                    username: displayUser.username,
                    bio: displayUser.bio,
                    profileImageUrl: displayUser.profileImageUrl,
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
                Text(displayUser.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("@\(displayUser.displayUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(actionText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let message = request.message, !message.isEmpty {
                    Text("\"\(message)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                }

                // Time ago
                Text(timeAgoString)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }

            Spacer()

            // Action Buttons
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                actionButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isIncoming {
            // Incoming request: Accept/Decline
            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray))
                        .cornerRadius(16)
                }

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .cornerRadius(16)
                }
            }
        } else {
            // Outgoing request: Cancel
            Button(action: onCancel) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: request.createdAt, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 16) {
        // Incoming request
        FriendRequestCardView(
            request: FriendRequest(
                id: 1,
                senderId: 2,
                receiverId: 1,
                sender: UserBasic(
                    id: 2,
                    username: "jane_doe",
                    name: "Jane Doe",
                    bio: "Fitness enthusiast",
                    profileImageUrl: nil
                ),
                receiver: UserBasic(
                    id: 1,
                    username: "current_user",
                    name: "Current User",
                    bio: nil,
                    profileImageUrl: nil
                ),
                status: "pending",
                message: "Let's motivate each other!",
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: nil,
                expiresAt: nil
            ),
            isIncoming: true,
            isProcessing: false,
            onAccept: { },
            onDecline: { },
            onCancel: { }
        )

        // Outgoing request
        FriendRequestCardView(
            request: FriendRequest(
                id: 2,
                senderId: 1,
                receiverId: 3,
                sender: UserBasic(
                    id: 1,
                    username: "current_user",
                    name: "Current User",
                    bio: nil,
                    profileImageUrl: nil
                ),
                receiver: UserBasic(
                    id: 3,
                    username: "bob_smith",
                    name: "Bob Smith",
                    bio: "Running everyday",
                    profileImageUrl: nil
                ),
                status: "pending",
                message: nil,
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: nil,
                expiresAt: nil
            ),
            isIncoming: false,
            isProcessing: false,
            onAccept: { },
            onDecline: { },
            onCancel: { }
        )
    }
    .environmentObject(AuthViewModel())
    .padding()
}