import SwiftUI

struct ReplyIndicatorView: View {
    let replyToMessage: Message
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Reply indicator icon and line
            VStack(spacing: 0) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 20)
            }

            // Message preview
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(replyToMessage.sender.displayName)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)

                Text(replyToMessage.content)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .frame(maxHeight: 44)
    }
}

#Preview {
    ReplyIndicatorView(
        replyToMessage: Message(
            id: 1,
            conversationId: 1,
            senderId: 2,
            content: "This is a sample message that we are replying to",
            messageType: "text",
            status: .read,
            createdAt: Date(),
            deliveredAt: Date(),
            readAt: Date(),
            sender: UserBasic(id: 2, username: "sarah", name: "Sarah Johnson", bio: nil, profileImageUrl: nil),
            repliedToMessageId: nil
        ),
        onCancel: { }
    )
    .padding()
}