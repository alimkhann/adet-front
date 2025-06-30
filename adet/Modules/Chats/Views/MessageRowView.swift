import SwiftUI

struct MessageRowView: View {
    let message: Message
    let index: Int
    let viewModel: ChatDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Date header (if needed)
            if viewModel.shouldShowDateHeader(for: message, at: index) {
                DateHeaderView(date: message.createdAt)
            }

            // Message bubble
            MessageBubbleView(
                message: message,
                isFromCurrentUser: viewModel.isMyMessage(message),
                showSenderName: false, // No sender names in 1-on-1 chat
                showTimestamp: false, // We're using date headers instead
                showTimeBelow: viewModel.shouldShowTimeBelow(for: message, at: index),
                viewModel: viewModel
            )
        }
        .id(message.id)
        .onAppear {
            // Mark messages as read when they appear
            if !viewModel.isMyMessage(message) && index == viewModel.messages.count - 1 {
                Task {
                    await viewModel.markMessagesAsRead(upTo: message.id)
                }
            }
        }
    }
}