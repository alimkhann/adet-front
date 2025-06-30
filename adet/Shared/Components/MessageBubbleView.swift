import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    let showTimestamp: Bool

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Sender name (only for other users)
            if showSenderName && !isFromCurrentUser {
                Text(message.sender.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }

            HStack {
                if isFromCurrentUser {
                    Spacer(minLength: 50)
                }

                // Message Content
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromCurrentUser ? Color.accentColor : Color(.systemGray5))
                        )

                    // Message Status and Time
                    HStack(spacing: 4) {
                        // Timestamp
                        Text(formatTime(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Status Indicator (only for current user messages)
                        if isFromCurrentUser {
                            statusIcon
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if !isFromCurrentUser {
                    Spacer(minLength: 50)
                }
            }

            // Full Timestamp (if shown)
            if showTimestamp {
                Text(formatFullTimestamp(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .read:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.accentColor)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }

    // MARK: - Helper Methods

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFullTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Message from other user
        MessageBubbleView(
            message: Message(
                id: 1,
                conversationId: 1,
                senderId: 2,
                content: "Hey! How's your morning routine going today?",
                messageType: "text",
                status: .read,
                createdAt: Date().addingTimeInterval(-3600),
                deliveredAt: Date().addingTimeInterval(-3590),
                readAt: Date().addingTimeInterval(-3580),
                sender: UserBasic(id: 2, username: "sarah_wellness", name: "Sarah Johnson", profileImageUrl: nil)
            ),
            isFromCurrentUser: false,
            showSenderName: true,
            showTimestamp: false
        )

        // Message from current user (sent)
        MessageBubbleView(
            message: Message(
                id: 2,
                conversationId: 1,
                senderId: 1,
                content: "Going great! I've been consistent for 3 weeks now. The meditation really helps start my day right.",
                messageType: "text",
                status: .delivered,
                createdAt: Date().addingTimeInterval(-3500),
                deliveredAt: Date().addingTimeInterval(-3490),
                readAt: nil,
                sender: UserBasic(id: 1, username: "me", name: "Me", profileImageUrl: nil)
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            showTimestamp: false
        )

        // Message from current user (read)
        MessageBubbleView(
            message: Message(
                id: 3,
                conversationId: 1,
                senderId: 1,
                content: "That's awesome! 💪",
                messageType: "text",
                status: .read,
                createdAt: Date().addingTimeInterval(-300),
                deliveredAt: Date().addingTimeInterval(-290),
                readAt: Date().addingTimeInterval(-280),
                sender: UserBasic(id: 1, username: "me", name: "Me", profileImageUrl: nil)
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            showTimestamp: true
        )

        // Failed message
        MessageBubbleView(
            message: Message(
                id: 4,
                conversationId: 1,
                senderId: 1,
                content: "This message failed to send",
                messageType: "text",
                status: .failed,
                createdAt: Date(),
                deliveredAt: nil,
                readAt: nil,
                sender: UserBasic(id: 1, username: "me", name: "Me", profileImageUrl: nil)
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            showTimestamp: false
        )
    }
    .padding()
}