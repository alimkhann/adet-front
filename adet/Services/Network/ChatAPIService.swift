import Foundation
import Combine
import OSLog

@MainActor
actor ChatAPIService {
    static let shared = ChatAPIService()

    private let networkService = NetworkService.shared
    private let webSocketManager = WebSocketManager.shared
    private let logger = Logger(subsystem: "com.adet.api", category: "ChatAPIService")

    private init() {}

    // MARK: - REST API Operations

    /// Fetches all conversations for the current user
    func getConversations(limit: Int = 50, offset: Int = 0) async throws -> [Conversation] {
        let endpoint = "/api/v1/chats/conversations?limit=\(limit)&offset=\(offset)"
        let response: ConversationListResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
        return response.conversations
    }

    /// Creates a new conversation with a friend or returns existing one
    func createConversation(with friendId: Int) async throws -> Conversation {
        let requestBody = ConversationCreateRequest(participantId: friendId)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations",
            method: "POST",
            body: requestBody
        )
    }

    /// Gets detailed information about a specific conversation
    func getConversation(id: Int) async throws -> Conversation {
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations/\(id)",
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Fetches messages for a conversation with pagination
    func getMessages(
        conversationId: Int,
        limit: Int = 50,
        offset: Int = 0,
        beforeMessageId: Int? = nil
    ) async throws -> MessageListResponse {
        var endpoint = "/api/v1/chats/conversations/\(conversationId)/messages?limit=\(limit)&offset=\(offset)"

        if let beforeId = beforeMessageId {
            endpoint += "&before_message_id=\(beforeId)"
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Sends a message via REST API (fallback when WebSocket is not available)
    func sendMessage(conversationId: Int, content: String) async throws -> Message {
        let requestBody = MessageCreateRequest(content: content)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations/\(conversationId)/messages",
            method: "POST",
            body: requestBody
        )
    }

    /// Marks messages as read up to a specific message
    func markMessagesAsRead(conversationId: Int, lastMessageId: Int) async throws {
        let requestBody = MarkAsReadRequest(lastMessageId: lastMessageId)
        let _: [String: String] = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations/\(conversationId)/read",
            method: "POST",
            body: requestBody
        )
    }

    // MARK: - WebSocket Operations

    /// Connects to real-time chat for a conversation
    func connectToChat(conversationId: Int) async throws {
        // Get auth token from Clerk
        guard let authService = AuthManager.shared.clerkAuthService,
              let token = await authService.getValidToken() else {
            throw ChatError.authenticationFailed
        }

        logger.info("Connecting to real-time chat for conversation \(conversationId)")
        webSocketManager.connect(to: conversationId, with: token)
    }

    /// Disconnects from real-time chat
    func disconnectFromChat() {
        logger.info("Disconnecting from real-time chat")
        webSocketManager.disconnect()
    }

    /// Sends a message via WebSocket (preferred method for real-time)
    func sendMessageRealTime(_ content: String) {
        webSocketManager.sendMessage(content)
    }

    /// Sends typing indicator
    func sendTypingIndicator(isTyping: Bool) {
        webSocketManager.sendTypingIndicator(isTyping: isTyping)
    }

    /// Marks messages as read via WebSocket
    func markMessagesAsReadRealTime(lastMessageId: Int) {
        webSocketManager.markMessagesAsRead(lastMessageId: lastMessageId)
    }

    // MARK: - Publishers for Real-time Events

    /// Publisher for incoming messages
    var messagePublisher: AnyPublisher<Message, Never> {
        webSocketManager.messagePublisher
    }

    /// Publisher for typing indicators
    var typingPublisher: AnyPublisher<TypingEvent, Never> {
        webSocketManager.typingPublisher
    }

    /// Publisher for presence updates (online/offline status)
    var presencePublisher: AnyPublisher<PresenceEvent, Never> {
        webSocketManager.presencePublisher
    }

    /// Publisher for message status updates (delivered, read)
    var messageStatusPublisher: AnyPublisher<MessageStatusEvent, Never> {
        webSocketManager.messageStatusPublisher
    }

    /// Publisher for connection events
    var connectionPublisher: AnyPublisher<ConnectionEvent, Never> {
        webSocketManager.connectionPublisher
    }

    /// Connection state publisher
    var connectionStatePublisher: Published<ConnectionState>.Publisher {
        webSocketManager.$connectionState
    }

    /// Error publisher
    var errorPublisher: Published<ChatError?>.Publisher {
        webSocketManager.$lastError
    }

    // MARK: - Hybrid Operations (REST + WebSocket)

    /// Sends a message using WebSocket if connected, otherwise falls back to REST
    func sendMessageHybrid(conversationId: Int, content: String) async throws -> Message? {
        // If WebSocket is connected, use real-time messaging
        if webSocketManager.connectionState == .connected {
            logger.info("Sending message via WebSocket")
            webSocketManager.sendMessage(content)
            return nil // Message will be delivered via publisher
        } else {
            // Fallback to REST API
            logger.info("WebSocket not connected, falling back to REST API")
            return try await sendMessage(conversationId: conversationId, content: content)
        }
    }

    /// Ensures conversation is loaded and WebSocket is connected
    func initializeConversation(id: Int) async throws -> Conversation {
        logger.info("Initializing conversation \(id)")

        // First, get conversation details via REST
        let conversation = try await getConversation(id: id)

        // Then connect to real-time chat
        try await connectToChat(conversationId: id)

        return conversation
    }

    // MARK: - Utility Methods

    /// Health check for chat service
    func healthCheck() async throws -> Bool {
        do {
            let _: [String: String] = try await networkService.makeAuthenticatedRequest(
                endpoint: "/api/v1/chats/health",
                method: "GET",
                body: (nil as String?)
            )
            return true
        } catch {
            logger.error("Chat service health check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Gets current WebSocket connection state
    var connectionState: ConnectionState {
        webSocketManager.connectionState
    }

    /// Gets last WebSocket error
    var lastError: ChatError? {
        webSocketManager.lastError
    }
}

// MARK: - Error Handling Extensions

extension ChatAPIService {
    /// Handles chat-specific errors and provides user-friendly messages
    func handleChatError(_ error: Error) -> ChatError {
        if let chatError = error as? ChatError {
            return chatError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .authenticationFailed
            case .notFound:
                return .conversationNotFound
            default:
                return .networkError(error)
            }
        }

        return .networkError(error)
    }
}

// MARK: - Development Helpers

#if DEBUG
extension ChatAPIService {
    /// Debug method to simulate incoming messages (for testing UI)
    func simulateIncomingMessage(conversationId: Int, content: String, senderId: Int) {
        let message = Message(
            id: Int.random(in: 1000...9999),
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            messageType: MessageType.text.rawValue,
            status: .delivered,
            createdAt: Date(),
            deliveredAt: Date(),
            readAt: nil,
            sender: UserBasic(
                id: senderId,
                username: "test_user",
                name: "Test User",
                profileImageUrl: nil
            )
        )

        // Simulate message via WebSocket manager
        webSocketManager.messageSubject.send(message)
    }

    /// Debug method to test typing indicators
    func simulateTypingIndicator(conversationId: Int, userId: Int, isTyping: Bool) {
        let typingEvent = TypingEvent(
            type: "typing",
            conversationId: conversationId,
            userId: userId,
            isTyping: isTyping
        )

        webSocketManager.typingSubject.send(typingEvent)
    }
}
#endif