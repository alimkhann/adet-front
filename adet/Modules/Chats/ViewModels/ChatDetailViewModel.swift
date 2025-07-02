import Foundation
import Combine
import OSLog

@MainActor
class ChatDetailViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatDetailViewModel")
    private var cancellables = Set<AnyCancellable>()

    // Published properties for UI
    @Published var conversation: Conversation?
    @Published private var _messages: [Message] = []
    @Published var messageText: String = ""
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

    // Reply state
    @Published var replyingToMessage: Message?

    // Edit state
    @Published var editingMessage: Message?

    // Typing timer
    private var typingTimer: Timer?
    private let typingTimeout: TimeInterval = 3.0

    // Pagination
    private var hasMoreMessages = true
    private let messagesPerPage = 50

    // Current user ID (for message ownership)
    private var currentUserId: Int?

    // Selection and editing state
    @Published var selectedMessages: Set<Int> = []
    @Published var isSelectionMode = false

    // Computed property to filter out messages deleted for everyone
    var messages: [Message] {
        _messages.filter { message in
            // Don't hide any messages - let them show with their deleted state
            true
        }
    }

    // Online status text for UI
    var onlineStatusText: String {
        switch connectionState {
        case .connected:
            return isOtherUserOnline ? "Online" : "Offline"
        case .connecting, .reconnecting:
            return "Connecting..."
        case .disconnected:
            return "Offline"
        case .failed:
            return "Connection failed"
        }
    }

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

        // Ensure current user ID is loaded first
        if currentUserId == nil {
            await getCurrentUserIdAsync()
        }

        // Load messages and connect to real-time chat
        await loadInitialData()
    }

    /// Loads conversation and messages for the first time
    private func loadInitialData() async {
        guard let conversationId = conversation?.id else { return }

        await setLoading(true)

        do {
            // Get the shared ChatAPIService instance
            let chatService = ChatAPIService.shared

            // Load conversation details and messages in parallel
            async let conversationTask = chatService.initializeConversation(id: conversationId)
            async let messagesTask = chatService.getMessages(conversationId: conversationId, limit: messagesPerPage)

            let (updatedConversation, messageResponse) = try await (conversationTask, messagesTask)

            await MainActor.run {
                self.conversation = updatedConversation
                self._messages = messageResponse.messages
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
            let chatService = ChatAPIService.shared
            let beforeMessageId = messages.first?.id
            let messageResponse = try await chatService.getMessages(
                conversationId: conversationId,
                limit: messagesPerPage,
                offset: 0,
                beforeMessageId: beforeMessageId
            )

            await MainActor.run {
                // Prepend older messages
                self._messages.insert(contentsOf: messageResponse.messages, at: 0)
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
        // Check if we're in editing mode
        if editingMessage != nil {
            await saveEdit()
            return
        }

        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty,
              let conversationId = conversation?.id,
              !isSendingMessage else { return }

        // Clear input immediately for better UX
        let messageToSend = content
        let replyToMessageId = replyingToMessage?.id
        await MainActor.run {
            self.messageText = ""
            self.isSendingMessage = true
            // Clear reply state when sending
            self.replyingToMessage = nil
        }

        do {
            logger.info("Sending message to conversation \(conversationId)")

            let chatService = ChatAPIService.shared
            // Use hybrid approach: WebSocket if connected, REST as fallback
            let sentMessage = try await chatService.sendMessageHybrid(
                conversationId: conversationId,
                content: messageToSend,
                repliedToMessageId: replyToMessageId
            )

            // If REST was used (WebSocket not connected), add message to UI
            if let message = sentMessage {
                await MainActor.run {
                    self._messages.append(message)
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
                // Restore reply state on error
                if let replyId = replyToMessageId {
                    self.replyingToMessage = self._messages.first { $0.id == replyId }
                }
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

        // TODO: Send typing indicator via WebSocket when implemented
        // For now, typing indicators are disabled until WebSocket is fully implemented
        // let chatService = ChatAPIService.shared
        // await chatService.sendTypingIndicator(isTyping: typing)

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
            let chatService = ChatAPIService.shared
            // TODO: For now, always use REST API until WebSocket is fully implemented
            try await chatService.markMessagesAsRead(
                conversationId: conversationId,
                lastMessageId: messageId
            )

            logger.debug("Marked messages as read up to message \(messageId)")

        } catch {
            logger.error("Failed to mark messages as read: \(error)")
        }
    }

    /// Disconnects from real-time chat
    func disconnect() {
        logger.info("Disconnecting from chat")
        Task {
            let chatService = ChatAPIService.shared
            await chatService.disconnectFromChat()
        }

        // Clean up typing timer
        typingTimer?.invalidate()
        typingTimer = nil
    }

    // MARK: - Real-time Updates

    private func setupRealTimeUpdates() {
        Task { @MainActor in
            let chatService = ChatAPIService.shared

            // Listen for incoming messages
            let messagePublisher = await chatService.messagePublisher
            messagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    self?.handleIncomingMessage(message)
                }
                .store(in: &cancellables)

            // Listen for typing indicators
            let typingPublisher = await chatService.typingPublisher
            typingPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] typingEvent in
                    self?.handleTypingEvent(typingEvent)
                }
                .store(in: &cancellables)

            // Listen for presence updates
            let presencePublisher = await chatService.presencePublisher
            presencePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] presenceEvent in
                    self?.handlePresenceEvent(presenceEvent)
                }
                .store(in: &cancellables)

            // Listen for message status updates
            let messageStatusPublisher = await chatService.messageStatusPublisher
            messageStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] statusEvent in
                    self?.handleMessageStatusEvent(statusEvent)
                }
                .store(in: &cancellables)

            // Listen for connection state changes
            let connectionStatePublisher = await chatService.connectionStatePublisher
            connectionStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] connectionState in
                    self?.connectionState = connectionState
                }
                .store(in: &cancellables)
        }
    }

    private func handleIncomingMessage(_ message: Message) {
        guard message.conversationId == conversation?.id else { return }

        logger.debug("Received message: \(message.content)")

        // Add message if not already present
        if !_messages.contains(where: { $0.id == message.id }) {
            _messages.append(message)

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
        if let index = _messages.firstIndex(where: { $0.id == event.messageId }) {
            var updatedMessage = _messages[index]
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
                sender: updatedMessage.sender,
                repliedToMessageId: updatedMessage.repliedToMessageId
            )

            _messages[index] = updatedMessage
        }
    }

    // MARK: - Helper Methods

    private func getCurrentUserId() {
        Task {
            await getCurrentUserIdAsync()
        }
    }

    private func getCurrentUserIdAsync() async {
        do {
            let user = try await APIService.shared.getCurrentUser()
            await MainActor.run {
                self.currentUserId = user.id
            }
            logger.info("Current user ID set to: \(user.id)")
        } catch {
            logger.error("Failed to get current user ID: \(error)")
            // Fallback to a default value or handle error
            await MainActor.run {
                self.currentUserId = nil
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
        let chatError = await ChatAPIService.shared.handleChatError(error)

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
        let result = message.senderId == currentUserId
        if currentUserId == nil {
            logger.warning("Current user ID is nil when checking message ownership for message \(message.id)")
        }
        logger.debug("Message \(message.id) from sender \(message.senderId), current user: \(self.currentUserId ?? -1), isMyMessage: \(result)")
        return result
    }

    func getRepliedMessage(for message: Message) -> Message? {
        guard let repliedToMessageId = message.repliedToMessageId else { return nil }
        return _messages.first { $0.id == repliedToMessageId }
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

    func shouldShowDateHeader(for message: Message, at index: Int) -> Bool {
        // Always show for first message
        if index == 0 { return true }

        // Show if this message is from a different day than the previous message
        let previousMessage = messages[index - 1]
        let calendar = Calendar.current
        return !calendar.isDate(message.createdAt, inSameDayAs: previousMessage.createdAt)
    }

    func shouldShowTimeBelow(for message: Message, at index: Int) -> Bool {
        // Show time below the last message in a group from the same sender

        // Always show for the last message in the conversation
        if index == messages.count - 1 { return true }

        // Show if next message is from a different sender
        if index < messages.count - 1 {
            let nextMessage = messages[index + 1]
            if nextMessage.senderId != message.senderId { return true }
        }

        // Show if there's a significant time gap (more than 10 minutes) to the next message
        if index < messages.count - 1 {
            let nextMessage = messages[index + 1]
            let timeDifference = nextMessage.createdAt.timeIntervalSince(message.createdAt)
            if timeDifference > 600 { return true } // 10 minutes instead of 5
        }

        return false
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

    var canSaveEdit: Bool {
        editingMessage != nil && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSendingMessage
    }

    var typingIndicatorText: String {
        guard let otherUser = conversation?.otherParticipant else { return "" }
        return "\(otherUser.displayName) is typing..."
    }

    // MARK: - Message Actions

    func canEditMessage(_ message: Message) -> Bool {
        guard isMyMessage(message) else { return false }

        // Cannot edit deleted messages
        if message.content == "Message deleted" || message.content == "Deleted for me" {
            return false
        }

        // Can edit if message is less than 30 minutes old
        let timeElapsed = Date().timeIntervalSince(message.createdAt)
        return timeElapsed < 1800 // 30 minutes
    }

    func canDeleteForEveryone(_ message: Message) -> Bool {
        guard isMyMessage(message) else { return false }

        // Can delete for everyone if message is less than 30 minutes old (even if already deleted)
        // OR if message is already deleted (for removal)
        let timeElapsed = Date().timeIntervalSince(message.createdAt)
        let withinTimeLimit = timeElapsed < 1800 // 30 minutes
        let isAlreadyDeleted = message.content == "Message deleted"

        return withinTimeLimit || isAlreadyDeleted
    }

    func canDeleteForMe(_ message: Message) -> Bool {
        // Can always delete for yourself (even if already deleted to remove completely)
        // This includes both "Deleted for me" and "Message deleted" messages
        return true
    }

    func canReplyToMessage(_ message: Message) -> Bool {
        // Cannot reply to deleted messages
        if message.content == "Message deleted" || message.content == "Deleted for me" {
            return false
        }
        return true
    }

    // MARK: - Bulk Selection

    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            clearSelection()
        }
    }

    func toggleMessageSelection(_ messageId: Int) {
        if selectedMessages.contains(messageId) {
            selectedMessages.remove(messageId)
        } else {
            selectedMessages.insert(messageId)
        }

        // Exit selection mode if no messages selected
        if selectedMessages.isEmpty {
            isSelectionMode = false
        }
    }

    func clearSelection() {
        selectedMessages.removeAll()
    }

    func selectAllMyMessages() {
        selectedMessages = Set(_messages.compactMap { message in
            // Allow selection of all messages including deleted ones
            isMyMessage(message) ? message.id : nil
        })
    }

    // MARK: - Bulk Delete

    @Published var showingBulkDeleteConfirmation = false

    func bulkDeleteSelectedMessages() async {
        guard !selectedMessages.isEmpty else { return }

        // Show confirmation dialog
        await MainActor.run {
            showingBulkDeleteConfirmation = true
        }
    }

    func confirmBulkDelete() async {
        guard !selectedMessages.isEmpty else { return }

        let messagesToDelete = _messages.filter { selectedMessages.contains($0.id) }

        // Clear selection immediately for better UX
        await MainActor.run {
            clearSelection()
            isSelectionMode = false
            showingBulkDeleteConfirmation = false
        }

        // Group messages by delete strategy
        var deleteForEveryoneIds: [Int] = []
        var deleteForMeIds: [Int] = []
        var removeCompletelyIds: [Int] = []

        for message in messagesToDelete {
            if message.content == "Deleted for me" || message.content == "Message deleted" {
                // Already deleted messages should be removed completely
                removeCompletelyIds.append(message.id)
            } else if canDeleteForEveryone(message) && shouldDeleteForEveryone(message) {
                deleteForEveryoneIds.append(message.id)
            } else {
                deleteForMeIds.append(message.id)
            }
        }

        // Execute bulk deletes
        await performBulkDelete(
            deleteForEveryoneIds: deleteForEveryoneIds,
            deleteForMeIds: deleteForMeIds,
            removeCompletelyIds: removeCompletelyIds
        )
    }

    private func shouldDeleteForEveryone(_ message: Message) -> Bool {
        // Smart logic: delete for everyone if message is recent and not already deleted for me
        let isRecent = Date().timeIntervalSince(message.createdAt) < 1800 // 30 minutes
        let isNotDeletedForMe = message.content != "Deleted for me"
        let isMyMessage = isMyMessage(message)

        return isMyMessage && isRecent && isNotDeletedForMe
    }

    private func performBulkDelete(deleteForEveryoneIds: [Int], deleteForMeIds: [Int], removeCompletelyIds: [Int]) async {
        guard let conversationId = conversation?.id else { return }

        // Optimistic UI updates
        await MainActor.run {
            // Handle delete for everyone
            for messageId in deleteForEveryoneIds {
                if let index = _messages.firstIndex(where: { $0.id == messageId }) {
                    var updatedMessage = _messages[index]
                    updatedMessage = Message(
                        id: updatedMessage.id,
                        conversationId: updatedMessage.conversationId,
                        senderId: updatedMessage.senderId,
                        content: "Message deleted",
                        messageType: "system",
                        status: updatedMessage.status,
                        createdAt: updatedMessage.createdAt,
                        deliveredAt: updatedMessage.deliveredAt,
                        readAt: updatedMessage.readAt,
                        sender: updatedMessage.sender,
                        repliedToMessageId: updatedMessage.repliedToMessageId
                    )
                    _messages[index] = updatedMessage
                }
            }

            // Handle delete for me
            for messageId in deleteForMeIds {
                if let index = _messages.firstIndex(where: { $0.id == messageId }) {
                    var updatedMessage = _messages[index]
                    updatedMessage = Message(
                        id: updatedMessage.id,
                        conversationId: updatedMessage.conversationId,
                        senderId: updatedMessage.senderId,
                        content: "Deleted for me",
                        messageType: "system",
                        status: updatedMessage.status,
                        createdAt: updatedMessage.createdAt,
                        deliveredAt: updatedMessage.deliveredAt,
                        readAt: updatedMessage.readAt,
                        sender: updatedMessage.sender,
                        repliedToMessageId: updatedMessage.repliedToMessageId
                    )
                    _messages[index] = updatedMessage
                }
            }

            // Handle complete removal
            for messageId in removeCompletelyIds {
                _messages.removeAll { $0.id == messageId }
            }
        }

        // Sync with server
        let chatService = ChatAPIService.shared

        // Delete for everyone
        for messageId in deleteForEveryoneIds {
            do {
                try await chatService.deleteMessage(
                    conversationId: conversationId,
                    messageId: messageId,
                    deleteForEveryone: true
                )
                logger.info("Bulk deleted message \(messageId) for everyone")
            } catch {
                logger.error("Failed to bulk delete message \(messageId) for everyone: \(error)")
            }
        }

        // Delete for me
        for messageId in deleteForMeIds {
            do {
                try await chatService.deleteMessage(
                    conversationId: conversationId,
                    messageId: messageId,
                    deleteForEveryone: false
                )
                logger.info("Bulk deleted message \(messageId) for me")
            } catch {
                logger.error("Failed to bulk delete message \(messageId) for me: \(error)")
            }
        }

        // Remove completely
        for messageId in removeCompletelyIds {
            do {
                try await chatService.deleteMessage(
                    conversationId: conversationId,
                    messageId: messageId,
                    deleteForEveryone: true // Use delete for everyone to trigger complete removal
                )
                logger.info("Bulk removed message \(messageId) completely")
            } catch {
                logger.error("Failed to bulk remove message \(messageId) completely: \(error)")
            }
        }
    }

    func replyToMessage(_ message: Message) async {
        await MainActor.run {
            self.replyingToMessage = message
        }
        logger.info("Reply to message \(message.id): \(message.content)")
    }

    func cancelReply() {
        replyingToMessage = nil
    }

    func startEditingMessage(_ message: Message) async {
        await MainActor.run {
            self.editingMessage = message
            self.messageText = message.content
        }
        logger.info("Start editing message \(message.id): \(message.content)")
    }

    func cancelEditing() {
        editingMessage = nil
        messageText = ""
    }

    func saveEdit() async {
        guard let message = editingMessage else { return }
        let newContent = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !newContent.isEmpty else {
            await MainActor.run {
                self.messageText = message.content // Restore original text
            }
            return
        }

        // Clear edit state immediately for better UX
        await MainActor.run {
            self.editingMessage = nil
            self.messageText = ""
        }

        // Then perform the edit operation
        await editMessage(message, newContent: newContent)
    }

    /// Refreshes messages from the server to ensure consistency
    func refreshMessages() async {
        guard let conversationId = conversation?.id else { return }

        do {
            let chatService = ChatAPIService.shared
            let messageResponse = try await chatService.getMessages(
                conversationId: conversationId,
                limit: _messages.count > messagesPerPage ? _messages.count : messagesPerPage
            )

            await MainActor.run {
                self._messages = messageResponse.messages
            }

            logger.info("Messages refreshed successfully")
        } catch {
            logger.error("Failed to refresh messages: \(error)")
        }
    }

    // MARK: - Individual Message Actions

    func editMessage(_ message: Message, newContent: String) async {
        guard let conversationId = conversation?.id else {
            logger.error("No conversation ID available for editing message")
            return
        }

        // First, update locally for immediate UI feedback
        await MainActor.run {
            if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = self._messages[index]
                updatedMessage = Message(
                    id: updatedMessage.id,
                    conversationId: updatedMessage.conversationId,
                    senderId: updatedMessage.senderId,
                    content: newContent,
                    messageType: updatedMessage.messageType,
                    status: updatedMessage.status,
                    createdAt: updatedMessage.createdAt,
                    deliveredAt: updatedMessage.deliveredAt,
                    readAt: updatedMessage.readAt,
                    sender: updatedMessage.sender,
                    repliedToMessageId: updatedMessage.repliedToMessageId
                )
                self._messages[index] = updatedMessage
            }
        }

        // Then sync with server
        do {
            logger.info("Edit message \(message.id) with new content: \(newContent)")

            let serverUpdatedMessage = try await ChatAPIService.shared.editMessage(
                conversationId: conversationId,
                messageId: message.id,
                newContent: newContent
            )

            // Update with server response to ensure consistency
            await MainActor.run {
                if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                    self._messages[index] = serverUpdatedMessage
                }
            }

            logger.info("Message edited successfully")
        } catch {
            logger.error("Failed to edit message: \(error)")

            // Revert local changes on error
            await MainActor.run {
                if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                    var revertedMessage = self._messages[index]
                    revertedMessage = Message(
                        id: revertedMessage.id,
                        conversationId: revertedMessage.conversationId,
                        senderId: revertedMessage.senderId,
                        content: message.content, // Revert to original content
                        messageType: revertedMessage.messageType,
                        status: revertedMessage.status,
                        createdAt: revertedMessage.createdAt,
                        deliveredAt: revertedMessage.deliveredAt,
                        readAt: revertedMessage.readAt,
                        sender: revertedMessage.sender,
                        repliedToMessageId: revertedMessage.repliedToMessageId
                    )
                    self._messages[index] = revertedMessage
                }
                self.errorMessage = "Failed to edit message"
            }
        }
    }

    func deleteMessageForMe(_ message: Message) async {
        guard let conversationId = conversation?.id else {
            logger.error("No conversation ID available for deleting message")
            return
        }

        // Store original message for potential revert
        let originalMessage = message

        // If message is already "Deleted for me", remove it completely
        if message.content == "Deleted for me" || message.content == "Message deleted" {
            await MainActor.run {
                self._messages.removeAll { $0.id == message.id }
            }

            // Also sync removal with server (this ensures persistence)
            do {
                logger.info("Remove message \(message.id) completely")
                try await ChatAPIService.shared.deleteMessage(
                    conversationId: conversationId,
                    messageId: message.id,
                    deleteForEveryone: true // This will actually remove it from server
                )
                logger.info("Message removed completely from server")
            } catch {
                logger.error("Failed to remove message completely: \(error)")
                // Revert - add the message back
                await MainActor.run {
                    let insertIndex = self._messages.firstIndex { $0.createdAt > originalMessage.createdAt } ?? self._messages.count
                    self._messages.insert(originalMessage, at: insertIndex)
                }
            }
            return
        }

        // First, update UI immediately to show "Deleted for me"
        await MainActor.run {
            if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                var deletedMessage = self._messages[index]
                deletedMessage = Message(
                    id: deletedMessage.id,
                    conversationId: deletedMessage.conversationId,
                    senderId: deletedMessage.senderId,
                    content: "Deleted for me",
                    messageType: "system",
                    status: deletedMessage.status,
                    createdAt: deletedMessage.createdAt,
                    deliveredAt: deletedMessage.deliveredAt,
                    readAt: deletedMessage.readAt,
                    sender: deletedMessage.sender,
                    repliedToMessageId: deletedMessage.repliedToMessageId
                )
                self._messages[index] = deletedMessage
            }
        }

        // Then sync with server
        do {
            logger.info("Delete message \(message.id) for me")

            try await ChatAPIService.shared.deleteMessage(
                conversationId: conversationId,
                messageId: message.id,
                deleteForEveryone: false
            )

            logger.info("Message deleted for me successfully")
        } catch {
            logger.error("Failed to delete message for me: \(error)")

            // Revert to original message on error
            await MainActor.run {
                if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                    self._messages[index] = originalMessage
                }
                self.errorMessage = "Failed to delete message"
            }
        }
    }

    func deleteMessageForEveryone(_ message: Message) async {
        guard let conversationId = conversation?.id else {
            logger.error("No conversation ID available for deleting message")
            return
        }

        // Store original message for potential revert
        let originalMessage = message

        // If message is already deleted for everyone, remove it completely
        if message.content == "Message deleted" {
            await MainActor.run {
                self._messages.removeAll { $0.id == message.id }
            }

            // Sync removal with server
            do {
                logger.info("Remove message \(message.id) completely from server")
                try await ChatAPIService.shared.deleteMessage(
                    conversationId: conversationId,
                    messageId: message.id,
                    deleteForEveryone: true // This will actually delete from DB
                )
                logger.info("Message removed completely from server")
            } catch {
                logger.error("Failed to remove message completely: \(error)")
                // Revert - add the message back
                await MainActor.run {
                    let insertIndex = self._messages.firstIndex { $0.createdAt > originalMessage.createdAt } ?? self._messages.count
                    self._messages.insert(originalMessage, at: insertIndex)
                }
            }
            return
        }

        // First, update UI immediately to show "Deleted for everyone"
        await MainActor.run {
            if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                var deletedMessage = self._messages[index]
                deletedMessage = Message(
                    id: deletedMessage.id,
                    conversationId: deletedMessage.conversationId,
                    senderId: deletedMessage.senderId,
                    content: "Message deleted",
                    messageType: "system",
                    status: deletedMessage.status,
                    createdAt: deletedMessage.createdAt,
                    deliveredAt: deletedMessage.deliveredAt,
                    readAt: deletedMessage.readAt,
                    sender: deletedMessage.sender,
                    repliedToMessageId: deletedMessage.repliedToMessageId
                )
                self._messages[index] = deletedMessage
            }
        }

        // Then sync with server
        do {
            logger.info("Delete message \(message.id) for everyone")

            try await ChatAPIService.shared.deleteMessage(
                conversationId: conversationId,
                messageId: message.id,
                deleteForEveryone: true
            )

            logger.info("Message deleted for everyone successfully")
        } catch {
            logger.error("Failed to delete message for everyone: \(error)")

            // Revert - restore original message on error
            await MainActor.run {
                if let index = self._messages.firstIndex(where: { $0.id == message.id }) {
                    self._messages[index] = originalMessage
                }
                self.errorMessage = "Failed to delete message"
            }
        }
    }

    // MARK: - Reply Actions
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
                bio: nil,
                profileImageUrl: nil
            ),
            lastMessage: nil,
            unreadCount: 0,
            isOtherOnline: true,
            otherLastSeen: nil
        )

        conversation = mockConversation
        currentUserId = 1

        _messages = [
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
                sender: UserBasic(id: 1, username: "me", name: "Me", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
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
                sender: UserBasic(id: 2, username: "sarah_wellness", name: "Sarah", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
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
                sender: UserBasic(id: 1, username: "me", name: "Me", bio: nil, profileImageUrl: nil),
                repliedToMessageId: nil
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
            sender: conversation?.otherParticipant ?? UserBasic(id: 2, username: "test", name: "Test User", bio: nil, profileImageUrl: nil),
            repliedToMessageId: nil
        )

        handleIncomingMessage(message)
    }
}
#endif
