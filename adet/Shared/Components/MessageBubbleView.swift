import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    let showTimestamp: Bool
    let showTimeBelow: Bool
    let viewModel: ChatDetailViewModel?

    @State private var dragOffset: CGSize = .zero
    @State private var showingActions = false
    @State private var showingEditAlert = false
    @State private var editText = ""

    init(message: Message, isFromCurrentUser: Bool, showSenderName: Bool, showTimestamp: Bool, showTimeBelow: Bool, viewModel: ChatDetailViewModel? = nil) {
        self.message = message
        self.isFromCurrentUser = isFromCurrentUser
        self.showSenderName = showSenderName
        self.showTimestamp = showTimestamp
        self.showTimeBelow = showTimeBelow
        self.viewModel = viewModel
        self._editText = State(initialValue: message.content)
    }

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
            HStack {
                if isFromCurrentUser {
                    Spacer(minLength: 50)
                }

                // Message Content with gestures
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Replied message preview (if this is a reply)
                    if let repliedMessage = viewModel?.getRepliedMessage(for: message) {
                        repliedMessageView(repliedMessage)
                    }

                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromCurrentUser ? Color.accentColor : Color(.systemGray5))
                        )
                        .offset(x: dragOffset.width)
                        .scaleEffect(dragOffset.width != 0 ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)

                    // Show time below message when showTimeBelow is true
                    if showTimeBelow {
                        HStack(spacing: 4) {
                            // Status Indicator (only for current user messages)
                            if isFromCurrentUser {
                                statusIcon
                            }

                            // Time
                            Text(formatTime(message.createdAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .contentShape(Rectangle()) // Make entire area tappable
                .onLongPressGesture {
                    showingActions = true
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Allow swipe right to reply for all messages
                            if value.translation.width > 0 && abs(value.translation.width) > abs(value.translation.height) {
                                dragOffset = CGSize(width: value.translation.width * 0.3, height: 0)
                            }
                        }
                        .onEnded { value in
                            let swipeThreshold: CGFloat = 60
                            let swipeDirection = value.translation.width > swipeThreshold

                            if swipeDirection {
                                // Trigger reply action
                                Task {
                                    await viewModel?.replyToMessage(message)
                                }
                            }

                            // Reset offset
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = .zero
                            }
                        }
                )

                if !isFromCurrentUser {
                    Spacer(minLength: 50)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 1) // Reduced padding for better grouping
        .confirmationDialog("Message Actions", isPresented: $showingActions) {
            messageActionButtons
        }
        .alert("Edit Message", isPresented: $showingEditAlert) {
            TextField("Message", text: $editText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                Task {
                    await viewModel?.editMessage(message, newContent: editText)
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var messageActionButtons: some View {
        if viewModel?.canReplyToMessage(message) == true {
            Button("Reply") {
                Task {
                    await viewModel?.replyToMessage(message)
                }
            }
        }

        if viewModel?.canEditMessage(message) == true {
            Button("Edit") {
                showingEditAlert = true
            }
        }

        if viewModel?.canDeleteForEveryone(message) == true {
            Button("Delete for Everyone", role: .destructive) {
                Task {
                    await viewModel?.deleteMessageForEveryone(message)
                }
            }
        }

        if viewModel?.canDeleteForMe(message) == true {
            Button("Delete for Me", role: .destructive) {
                Task {
                    await viewModel?.deleteMessageForMe(message)
                }
            }
        }
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

    // MARK: - Replied Message View

    private func repliedMessageView(_ repliedMessage: Message) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Replied to label
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Replying to \(repliedMessage.sender.displayName)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            // Replied message content preview
            Text(repliedMessage.content)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.secondary)
                .padding(.leading, 16) // Indent the content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
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
                sender: UserBasic(id: 2, username: "sarah_wellness", firstName: "Sarah", lastName: "Johnson", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
            ),
            isFromCurrentUser: false,
            showSenderName: true,
            showTimestamp: false,
            showTimeBelow: true,
            viewModel: nil
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
                sender: UserBasic(id: 1, username: "me", firstName: "Me", lastName: "", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            showTimestamp: false,
            showTimeBelow: false,
            viewModel: nil
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
                sender: UserBasic(id: 1, username: "me", firstName: "Me", lastName: "", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            showTimestamp: true,
            showTimeBelow: true,
            viewModel: nil
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
                sender: UserBasic(id: 1, username: "me", firstName: "Me", lastName: "", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            showTimestamp: false,
            showTimeBelow: true,
            viewModel: nil
        )
    }
    .padding()
}