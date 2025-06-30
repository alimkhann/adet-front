import SwiftUI

struct ConversationCardView: View {
    let conversation: Conversation
    let onTap: () -> Void

    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image with Online Indicator
                ZStack(alignment: .bottomTrailing) {
                    ProfileImageView(
                        user: User(
                            id: conversation.otherParticipant.id,
                            clerkId: "",
                            email: "",
                            name: conversation.otherParticipant.name,
                            username: conversation.otherParticipant.username,
                            bio: conversation.otherParticipant.bio,
                            profileImageUrl: conversation.otherParticipant.profileImageUrl,
                            isActive: true,
                            createdAt: Date(),
                            updatedAt: nil
                        ),
                        size: 56,
                        isEditable: false,
                        onImageTap: nil,
                        onDeleteTap: nil,
                        jwtToken: authViewModel.jwtToken
                    )

                    // Online Status Indicator
                    if conversation.isOtherOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                // Conversation Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.otherParticipant.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        // Timestamp
                        Text(timeAgoText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        // Last Message Preview
                        Text(lastMessagePreview)
                            .font(.caption)
                            .foregroundColor(conversation.unreadCount > 0 ? .primary : .secondary)
                            .fontWeight(conversation.unreadCount > 0 ? .medium : .regular)
                            .lineLimit(1)

                        Spacer()

                        // Unread Badge
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        }
                    }

                    // Online Status Text
                    if !conversation.isOtherOnline {
                        Text(onlineStatusText)
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Computed Properties

    private var lastMessagePreview: String {
        guard let lastMessage = conversation.lastMessage else {
            return "No messages yet"
        }

        let preview = lastMessage.content.prefix(50)
        return preview.count < lastMessage.content.count ? "\(preview)..." : String(preview)
    }

    private var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        if let lastMessage = conversation.lastMessage {
            return formatter.localizedString(for: lastMessage.createdAt, relativeTo: Date())
        } else {
            return formatter.localizedString(for: conversation.createdAt, relativeTo: Date())
        }
    }

    private var onlineStatusText: String {
        if let lastSeen = conversation.otherLastSeen {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        } else {
            return "Offline"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Conversation with unread messages
        ConversationCardView(
            conversation: Conversation(
                id: 1,
                participant1Id: 1,
                participant2Id: 2,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date(),
                lastMessageAt: Date().addingTimeInterval(-3600),
                otherParticipant: UserBasic(
                    id: 2,
                    username: "sarah_wellness",
                    name: "Sarah Johnson",
                    bio: nil,
                    profileImageUrl: nil
                ),
                lastMessage: Message(
                    id: 101,
                    conversationId: 1,
                    senderId: 2,
                    content: "How's your morning routine going?",
                    messageType: "text",
                    status: .delivered,
                    createdAt: Date().addingTimeInterval(-3600),
                    deliveredAt: Date().addingTimeInterval(-3590),
                    readAt: nil,
                    sender: UserBasic(id: 2, username: "sarah_wellness", name: "Sarah Johnson", bio: nil, profileImageUrl: nil),
                    repliedToMessageId: nil
                ),
                unreadCount: 2,
                isOtherOnline: true,
                otherLastSeen: nil
            ),
            onTap: { }
        )

        // Conversation without unread messages
        ConversationCardView(
            conversation: Conversation(
                id: 2,
                participant1Id: 1,
                participant2Id: 3,
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date(),
                lastMessageAt: Date().addingTimeInterval(-7200),
                otherParticipant: UserBasic(
                    id: 3,
                    username: "mike_fitness",
                    name: "Mike Chen",
                    bio: nil,
                    profileImageUrl: nil
                ),
                lastMessage: Message(
                    id: 102,
                    conversationId: 2,
                    senderId: 1,
                    content: "Great job on completing your workout streak! 💪",
                    messageType: "text",
                    status: .read,
                    createdAt: Date().addingTimeInterval(-7200),
                    deliveredAt: Date().addingTimeInterval(-7190),
                    readAt: Date().addingTimeInterval(-7180),
                    sender: UserBasic(id: 1, username: "me", name: "Me", bio: nil, profileImageUrl: nil),
                    repliedToMessageId: nil
                ),
                unreadCount: 0,
                isOtherOnline: false,
                otherLastSeen: Date().addingTimeInterval(-1800)
            ),
            onTap: { }
        )
    }
    .environmentObject(AuthViewModel())
    .padding()
}
