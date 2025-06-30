import SwiftUI
import OSLog

struct ChatDetailView: View {
    let conversation: Conversation
    @StateObject private var viewModel = ChatDetailViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatDetailView")

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading messages...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                // Messages list
                messagesScrollView

                // Typing indicator
                if viewModel.otherUserTyping {
                    typingIndicatorView
                }

                // Message input
                MessageInputView(
                    messageText: $viewModel.messageText,
                    isSendingMessage: viewModel.isSendingMessage,
                    canSendMessage: viewModel.canSendMessage,
                    onSendMessage: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    },
                    onTypingChanged: { isTyping in
                        Task {
                            await viewModel.setTyping(isTyping)
                        }
                    }
                )
            }
        }
        .navigationTitle(conversation.otherParticipant.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                VStack(alignment: .trailing, spacing: 2) {
                    connectionStatusIndicator
                    Text(viewModel.onlineStatusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            #if DEBUG
            // For development, load mock data first
            if viewModel.messages.isEmpty {
                viewModel.loadMockMessages()
            }
            #endif
            await viewModel.initialize(with: conversation)
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
            Button("Retry") {
                Task {
                    await viewModel.initialize(with: conversation)
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Load more messages button
                    if viewModel.messages.count > 20 {
                        Button("Load Earlier Messages") {
                            Task {
                                await viewModel.loadMoreMessages()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding()
                        .disabled(viewModel.isLoadingMessages)
                        .overlay {
                            if viewModel.isLoadingMessages {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }

                    // Messages
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: viewModel.isMyMessage(message),
                            showSenderName: viewModel.shouldShowSenderName(for: message, at: index),
                            showTimestamp: viewModel.shouldShowTimestamp(for: message, at: index)
                        )
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
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Auto-scroll to bottom when new messages arrive
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll to bottom on first load
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicatorView: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(typingAnimation ? 1.0 : 0.5)
                        .animation(
                            Animation
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: typingAnimation
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(18)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            typingAnimation = true
        }
    }

    @State private var typingAnimation = false

    // MARK: - Connection Status Indicator

    @ViewBuilder
    private var connectionStatusIndicator: some View {
        switch viewModel.connectionState {
        case .connected:
            Image(systemName: "circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .connecting, .reconnecting:
            ProgressView()
                .scaleEffect(0.6)
        case .disconnected:
            Image(systemName: "circle.fill")
                .foregroundColor(.gray)
                .font(.caption)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
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
                    profileImageUrl: nil
                ),
                lastMessage: nil,
                unreadCount: 0,
                isOtherOnline: true,
                otherLastSeen: nil
            )
        )
        .environmentObject(AuthViewModel())
    }
}