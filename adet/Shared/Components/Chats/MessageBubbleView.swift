import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    let showTimestamp: Bool
    let showTimeBelow: Bool
    @ObservedObject var viewModel: ChatDetailViewModel
    let previousMessage: Message?
    let nextMessage: Message?

    @State private var dragOffset: CGSize = .zero
    @State private var showingActions = false
    @State private var isMessageSelected = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox on the left - only show in selection mode
            if viewModel.isSelectionMode {
                VStack {
                    CheckboxView(isSelected: isMessageSelected)
                        .onTapGesture {
                            viewModel.toggleMessageSelection(message.id)
                        }

                    Spacer(minLength: 0)
                }
                .frame(width: 40)
            }

            // Message content with proper alignment
            VStack {
                HStack {
                    if isFromCurrentUser {
                        Spacer()
                        messageContent
                    } else {
                        messageContent
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, viewModel.isSelectionMode ? 12 : 16)
        .contentShape(Rectangle()) // Make entire row tappable
        .onTapGesture {
            // Handle tap based on current mode
            if viewModel.isSelectionMode {
                viewModel.toggleMessageSelection(message.id)
            }
            // No action in normal mode - just let it be
        }
        .onLongPressGesture {
            // Long press always shows action menu
            showingActions = true
        }
        .confirmationDialog("Message Actions", isPresented: $showingActions) {
            messageActionButtons
        }
        .onChange(of: viewModel.selectedMessages) { _, newValue in
            isMessageSelected = newValue.contains(message.id)
        }
        .onAppear {
            isMessageSelected = viewModel.selectedMessages.contains(message.id)
        }
    }

    // MARK: - Message Content

    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
            HStack {
                if isFromCurrentUser {
                    Spacer(minLength: 50)
                }

                // Message Content with gestures
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Replied message preview (if this is a reply)
                    if let repliedMessage = viewModel.getRepliedMessage(for: message) {
                        repliedMessageView(repliedMessage)
                    }

                    Text(message.content)
                        .font(.body)
                        .italic(message.content == "Message deleted" || message.content == "Deleted for me")
                        .foregroundColor(
                            (message.content == "Message deleted" || message.content == "Deleted for me")
                                ? .secondary
                                : (isFromCurrentUser ? .white : .primary)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    (message.content == "Message deleted" || message.content == "Deleted for me")
                                        ? Color(.systemGray6)
                                        : (isFromCurrentUser ? Color.accentColor : Color(.systemGray5))
                                )
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
            }

            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1) // Reduced padding for better grouping
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var messageActionButtons: some View {
        // Select Messages option (only if not in selection mode)
        if !viewModel.isSelectionMode {
            Button("Select Messages") {
                viewModel.toggleSelectionMode()
                viewModel.toggleMessageSelection(message.id)
            }
        }

        if viewModel.canReplyToMessage(message) == true {
            Button("Reply") {
                Task {
                    await viewModel.replyToMessage(message)
                }
            }
        }

        if viewModel.canEditMessage(message) == true {
            Button("Edit") {
                Task {
                    await viewModel.startEditingMessage(message)
                }
            }
        }

        if viewModel.canDeleteForEveryone(message) == true {
            Button(
                message.content == "Message deleted" ? "Remove" : "Delete for Everyone",
                role: .destructive
            ) {
                Task {
                    await viewModel.deleteMessageForEveryone(message)
                }
            }
        }

        if viewModel.canDeleteForMe(message) == true {
            Button(
                (message.content == "Deleted for me" || message.content == "Message deleted") ? "Remove" : "Delete for Me",
                role: .destructive
            ) {
                Task {
                    await viewModel.deleteMessageForMe(message)
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

// MARK: - CheckboxView Component

struct CheckboxView: View {
    var isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.primary, lineWidth: 2)
                .background(Circle().fill(isSelected ? Color.accentColor : Color.clear))
                .frame(width: 30, height: 30)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

/*
#Preview {
    // Preview temporarily disabled during refactoring
    Text("MessageBubbleView Preview")
}
*/
