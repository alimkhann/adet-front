import Foundation
import Combine
import OSLog

@MainActor
class ChatDetailViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatDetailViewModel")
    private let chatAPIService = ChatAPIService.shared
    private var cancellables = Set<AnyCancellable>()

    // Published properties for UI
    @Published var conversation: Conversation?
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isLoadingMessages = false
    @Published var isSendingMessage = false
    @Published var errorMessage: String?
    @Published var connectionState: ConnectionState = .disconnected

    // Real-time state
    @Published var isTyping = false
    @Published var otherUserTyping = false
    @Published var isOtherUserOnline = false
    @Published var otherUserLastSeen: Date?

    // Typing timer
    private var typingTimer: Timer?
    private let typingTimeout: TimeInterval = 3.0

    // Pagination
    private var hasMoreMessages = true
    private let messagesPerPage = 50

    // Current user ID (for message ownership)
    private var currentUserId: Int?

    init() {
        setupRealTimeUpdates()
        getCurrentUserId()
    }

    // MARK: - Public Interface

    /// Initializes the chat with a conversation
    func initialize(with conversation: Conversation) async {
        logger.info("Initializing chat for conversation \(conversation.id)")

        await MainActor.run {
            self.conversation = conversation
            self.isOtherUserOnline = conversation.isOtherOnline
            self.otherUserLastSeen = conversation.otherLastSeen
        }

        // Load messages and connect to real-time chat
        await loadInitialData()
    }

    /// Loads conversation and messages for the first time
    private func loadInitialData() async {
        guard let conversationId = conversation?.id else { return }

        await setLoading(true)

        do {
            // Load conversation details and messages in parallel
            async let conversationTask = chatAPIService.initializeConversation(id: conversationId)
            async let messagesTask = chatAPIService.getMessages(conversationId: conversationId, limit: messagesPerPage)

            let (updatedConversation, messageResponse) = try await (conversationTask, messagesTask)

            await MainActor.run {
                self.conversation = updatedConversation
                self.messages = messageResponse.messages
                self.hasMoreMessages = messageResponse.hasMore
                self.isLoading = false
                self.errorMessage = nil
            }

            // Mark messages as read
            if let lastMessage = messageResponse.messages.last {
                await markMessagesAsRead(upTo: lastMessage.id)
            }

            logger.info("Loaded \(messageResponse.messages.count) messages for conversation \(conversationId)")

        } catch {
            await handleError(error)
        }
    }

    /// Loads more messages (pagination)
    func loadMoreMessages() async {
        guard let conversationId = conversation?.id,
              !isLoadingMessages && hasMoreMessages else { return }

        await setLoadingMessages(true)

        do {
            let beforeMessageId = messages.first?.id
            let messageResponse = try await chatAPIService.getMessages(
                conversationId: conversationId,
                limit: messagesPerPage,
                offset: 0,
                beforeMessageId: beforeMessageId
            )

            await MainActor.run {
                // Prepend older messages
                self.messages.insert(contentsOf: messageResponse.messages, at: 0)
                self.hasMoreMessages = messageResponse.hasMore
                self.isLoadingMessages = false
            }

            logger.info("Loaded \(messageResponse.messages.count) more messages")

        } catch {
            await handleError(error)
            await setLoadingMessages(false)
        }
    }

    /// Sends a message
    func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty,
              let conversationId = conversation?.id,
              !isSendingMessage else { return }

        // Clear input immediately for better UX
        let messageToSend = content
        await MainActor.run {
            self.messageText = ""
            self.isSendingMessage = true
        }

        do {
            logger.info("Sending message to conversation \(conversationId)")

            // Use hybrid approach: WebSocket if connected, REST as fallback
            let sentMessage = try await chatAPIService.sendMessageHybrid(
                conversationId: conversationId,
                content: messageToSend
            )

            // If REST was used (WebSocket not connected), add message to UI
            if let message = sentMessage {
                await MainActor.run {
                    self.messages.append(message)
                }
            }

            await MainActor.run {
                self.isSendingMessage = false
            }

            // Stop typing indicator
            await setTyping(false)

            logger.info("Message sent successfully")

        } catch {
            // Restore message text on error
            await MainActor.run {
                self.messageText = messageToSend
                self.isSendingMessage = false
            }

            await handleError(error)
        }
    }

    /// Updates typing status
    func setTyping(_ typing: Bool) async {
        guard isTyping != typing else { return }

        await MainActor.run {
            self.isTyping = typing
        }

        // Send typing indicator via WebSocket
        chatAPIService.sendTypingIndicator(isTyping: typing)

        if typing {
            // Reset typing timer
            typingTimer?.invalidate()
            typingTimer = Timer.scheduledTimer(withTimeInterval: typingTimeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    await self?.setTyping(false)
                }
            }
        } else {
            typingTimer?.invalidate()
            typingTimer = nil
        }
    }

    /// Marks messages as read
    func markMessagesAsRead(upTo messageId: Int) async {
        guard let conversationId = conversation?.id else { return }

        do {
            // Use WebSocket if connected, otherwise REST
            if connectionState == .connected {
                chatAPIService.markMessagesAsReadRealTime(lastMessageId: messageId)
            } else {
                try await chatAPIService.markMessagesAsRead(
                    conversationId: conversationId,
                    lastMessageId: messageId
                )
            }

            logger.debug("Marked messages as read up to message \(messageId)")

        } catch {
            logger.error("Failed to mark messages as read: \(error)")
        }
    }

    /// Disconnects from real-time chat
    func disconnect() {
        logger.info("Disconnecting from chat")
        chatAPIService.disconnectFromChat()

        // Clean up typing timer
        typingTimer?.invalidate()
        typingTimer = nil
    }

    // MARK: - Real-time Updates

    private func setupRealTimeUpdates() {
        // Listen for incoming messages
        chatAPIService.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)

        // Listen for typing indicators
        chatAPIService.typingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] typingEvent in
                self?.handleTypingEvent(typingEvent)
            }
            .store(in: &cancellables)

        // Listen for presence updates
        chatAPIService.presencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presenceEvent in
                self?.handlePresenceEvent(presenceEvent)
            }
            .store(in: &cancellables)

        // Listen for message status updates
        chatAPIService.messageStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statusEvent in
                self?.handleMessageStatusEvent(statusEvent)
            }
            .store(in: &cancellables)

        // Listen for connection state changes
        chatAPIService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
    }

    private func handleIncomingMessage(_ message: Message) {
        guard message.conversationId == conversation?.id else { return }

        logger.debug("Received message: \(message.content)")

        // Add message if not already present
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)

            // Mark as read if from other user
            if message.senderId != currentUserId {
                Task {
                    await markMessagesAsRead(upTo: message.id)
                }
            }
        }
    }

    private func handleTypingEvent(_ event: TypingEvent) {
        guard event.conversationId == conversation?.id,
              event.userId != currentUserId else { return }

        logger.debug("Typing event: \(event.isTyping)")
        otherUserTyping = event.isTyping
    }

    private func handlePresenceEvent(_ event: PresenceEvent) {
        guard event.conversationId == conversation?.id,
              event.userId != currentUserId else { return }

        logger.debug("Presence event: \(event.isOnline)")
        isOtherUserOnline = event.isOnline
        if !event.isOnline {
            otherUserLastSeen = event.lastSeen
        }
    }

    private func handleMessageStatusEvent(_ event: MessageStatusEvent) {
        guard event.conversationId == conversation?.id else { return }

        logger.debug("Message status event: \(event.status) for message \(event.messageId)")

        // Update message status
        if let index = messages.firstIndex(where: { $0.id == event.messageId }) {
            var updatedMessage = messages[index]
            let newStatus = MessageStatus(rawValue: event.status) ?? updatedMessage.status

            updatedMessage = Message(
                id: updatedMessage.id,
                conversationId: updatedMessage.conversationId,
                senderId: updatedMessage.senderId,
                content: updatedMessage.content,
                messageType: updatedMessage.messageType,
                status: newStatus,
                createdAt: updatedMessage.createdAt,
                deliveredAt: newStatus == .delivered ? event.timestamp : updatedMessage.deliveredAt,
                readAt: newStatus == .read ? event.timestamp : updatedMessage.readAt,
                sender: updatedMessage.sender
            )

            messages[index] = updatedMessage
        }
    }

    // MARK: - Helper Methods

    private func getCurrentUserId() {
        // TODO: Get from AuthManager/Clerk
        // For now, we'll set it when conversation is loaded
        Task {
            // Mock current user ID - replace with actual auth service
            await MainActor.run {
                self.currentUserId = 1 // This should come from AuthManager
            }
        }
    }

    private func setLoading(_ loading: Bool) async {
        await MainActor.run {
            self.isLoading = loading
        }
    }

    private func setLoadingMessages(_ loading: Bool) async {
        await MainActor.run {
            self.isLoadingMessages = loading
        }
    }

    private func handleError(_ error: Error) async {
        let chatError = chatAPIService.handleChatError(error)

        await MainActor.run {
            self.errorMessage = chatError.localizedDescription
            self.isLoading = false
            self.isLoadingMessages = false
            self.isSendingMessage = false
        }

        logger.error("Chat detail error: \(chatError.localizedDescription)")
    }

    // MARK: - View Helpers

    func isMyMessage(_ message: Message) -> Bool {
        return message.senderId == currentUserId
    }

    func shouldShowTimestamp(for message: Message, at index: Int) -> Bool {
        guard index < messages.count else { return false }

        // Show timestamp for first message
        if index == 0 { return true }

        // Show timestamp if more than 5 minutes since previous message
        let previousMessage = messages[index - 1]
        let timeDifference = message.createdAt.timeIntervalSince(previousMessage.createdAt)
        return timeDifference > 300 // 5 minutes
    }

    func shouldShowSenderName(for message: Message, at index: Int) -> Bool {
        // Don't show sender name for my messages
        if isMyMessage(message) { return false }

        // Show for first message
        if index == 0 { return true }

        // Show if previous message was from different sender
        if index > 0 {
            let previousMessage = messages[index - 1]
            return previousMessage.senderId != message.senderId
        }

        return true
    }

    func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    func messageStatusIcon(for message: Message) -> String? {
        guard isMyMessage(message) else { return nil }

        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }

    var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSendingMessage
    }

    var onlineStatusText: String {
        if isOtherUserOnline {
            return "Online"
        } else if let lastSeen = otherUserLastSeen {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        } else {
            return "Offline"
        }
    }

    var typingIndicatorText: String {
        guard let otherUser = conversation?.otherParticipant else { return "" }
        return "\(otherUser.displayName) is typing..."
    }
}

// MARK: - Development Helpers

#if DEBUG
extension ChatDetailViewModel {
    /// Loads mock messages for development/testing
    func loadMockMessages() {
        let mockConversation = Conversation(
            id: 1,
            participant1Id: 1,
            participant2Id: 2,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date(),
            lastMessageAt: Date().addingTimeInterval(-300),
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

        conversation = mockConversation
        currentUserId = 1

        messages = [
            Message(
                id: 1,
                conversationId: 1,
                senderId: 1,
                content: "Hey Sarah! How's your morning routine going?",
                messageType: "text",
                status: .read,
                createdAt: Date().addingTimeInterval(-3600),
                deliveredAt: Date().addingTimeInterval(-3590),
                readAt: Date().addingTimeInterval(-3580),
                sender: UserBasic(id: 1, username: "me", name: "Me", profileImageUrl: nil)
            ),
            Message(
                id: 2,
                conversationId: 1,
                senderId: 2,
                content: "Great! I've been consistent for 3 weeks now. The meditation really helps start my day right. How about your workout streak?",
                messageType: "text",
                status: .read,
                createdAt: Date().addingTimeInterval(-3500),
                deliveredAt: Date().addingTimeInterval(-3490),
                readAt: Date().addingTimeInterval(-3480),
                sender: UserBasic(id: 2, username: "sarah_wellness", name: "Sarah Johnson", profileImageUrl: nil)
            ),
            Message(
                id: 3,
                conversationId: 1,
                senderId: 1,
                content: "That's awesome! I'm on day 12 of my workout habit. Your consistency is really inspiring 💪",
                messageType: "text",
                status: .delivered,
                createdAt: Date().addingTimeInterval(-300),
                deliveredAt: Date().addingTimeInterval(-290),
                readAt: nil,
                sender: UserBasic(id: 1, username: "me", name: "Me", profileImageUrl: nil)
            )
        ]
    }

    /// Simulates receiving a message
    func simulateIncomingMessage() {
        let message = Message(
            id: Int.random(in: 1000...9999),
            conversationId: conversation?.id ?? 1,
            senderId: conversation?.otherParticipant.id ?? 2,
            content: "This is a simulated incoming message!",
            messageType: "text",
            status: .delivered,
            createdAt: Date(),
            deliveredAt: Date(),
            readAt: nil,
            sender: conversation?.otherParticipant ?? UserBasic(id: 2, username: "test", name: "Test User", profileImageUrl: nil)
        )

        handleIncomingMessage(message)
    }
}
#endif