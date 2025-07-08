import Foundation
import Combine
import OSLog
import Clerk

// Remove @MainActor annotation to avoid conflict with actor
actor ChatAPIService {
    static let shared = ChatAPIService()

    private let networkService = NetworkService.shared
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
    func sendMessage(conversationId: Int, content: String, repliedToMessageId: Int? = nil) async throws -> Message {
        let requestBody = MessageCreateRequest(content: content, repliedToMessageId: repliedToMessageId)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations/\(conversationId)/messages",
            method: "POST",
            body: requestBody
        )
    }

    /// Marks messages as read up to a specific message
    func markMessagesAsRead(conversationId: Int, lastMessageId: Int) async throws {
        let endpoint = "/api/v1/chats/conversations/\(conversationId)/read?last_message_id=\(lastMessageId)"

        let _: [String: String] = try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "POST",
            body: (nil as String?)
        )

        logger.info("Messages marked as read successfully")
    }

    /// Edits a message content
    func editMessage(conversationId: Int, messageId: Int, newContent: String) async throws -> Message {
        let requestBody = MessageEditRequest(content: newContent)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations/\(conversationId)/messages/\(messageId)",
            method: "PUT",
            body: requestBody
        )
    }

    /// Deletes a message
    func deleteMessage(conversationId: Int, messageId: Int, deleteForEveryone: Bool = false) async throws {
        let requestBody = MessageDeleteRequest(deleteForEveryone: deleteForEveryone)
        let _: [String: String] = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/chats/conversations/\(conversationId)/messages/\(messageId)",
            method: "DELETE",
            body: requestBody
        )
    }

    // MARK: - WebSocket Operations

    /// Connects to real-time chat for a conversation
    func connectToChat(conversationId: Int) async throws {
        // Get auth token from Clerk session
        guard let token = try? await Clerk.shared.session?.getToken(.init(template: "adet-back"))?.jwt else {
            throw ChatError.authenticationFailed
        }

        logger.info("Connecting to real-time chat for conversation \(conversationId)")
        await WebSocketManager.shared.connect(to: conversationId, with: token)
    }

    /// Disconnects from real-time chat
    func disconnectFromChat() async {
        logger.info("Disconnecting from real-time chat")
        await WebSocketManager.shared.disconnect()
    }

    /// Sends a message via WebSocket (preferred method for real-time)
    func sendMessageRealTime(_ content: String) async {
        await WebSocketManager.shared.sendMessage(content)
    }

    /// Sends typing indicator
    func sendTypingIndicator(isTyping: Bool) async {
        await WebSocketManager.shared.sendTypingIndicator(isTyping: isTyping)
    }

    /// Marks messages as read via WebSocket
    func markMessagesAsReadRealTime(lastMessageId: Int) async {
        await WebSocketManager.shared.markMessagesAsRead(lastMessageId: lastMessageId)
    }

    // MARK: - Publishers for Real-time Events

    /// Publisher for incoming messages
    var messagePublisher: AnyPublisher<Message, Never> {
        get async {
            await WebSocketManager.shared.messagePublisher
        }
    }

    /// Publisher for typing indicators
    var typingPublisher: AnyPublisher<TypingEvent, Never> {
        get async {
            await WebSocketManager.shared.typingPublisher
        }
    }

    /// Publisher for presence updates (online/offline status)
    var presencePublisher: AnyPublisher<PresenceEvent, Never> {
        get async {
            await WebSocketManager.shared.presencePublisher
        }
    }

    /// Publisher for message status updates (delivered, read)
    var messageStatusPublisher: AnyPublisher<MessageStatusEvent, Never> {
        get async {
            await WebSocketManager.shared.messageStatusPublisher
        }
    }

    /// Publisher for connection events
    var connectionPublisher: AnyPublisher<ConnectionEvent, Never> {
        get async {
            await WebSocketManager.shared.connectionPublisher
        }
    }

    /// Connection state publisher
    var connectionStatePublisher: Published<ConnectionState>.Publisher {
        get async {
            await WebSocketManager.shared.$connectionState
        }
    }

    /// Error publisher
    var errorPublisher: Published<ChatError?>.Publisher {
        get async {
            await WebSocketManager.shared.$lastError
        }
    }

    // MARK: - Hybrid Operations (REST + WebSocket)

    /// Sends a message using WebSocket if connected, otherwise falls back to REST
    func sendMessageHybrid(conversationId: Int, content: String, repliedToMessageId: Int? = nil) async throws -> Message? {
        // TODO: For now, always use REST API until WebSocket is fully implemented
        // Once WebSocket implementation is complete, uncomment the WebSocket logic below

        logger.info("Sending message via REST API (WebSocket simulation disabled)")
        return try await sendMessage(conversationId: conversationId, content: content, repliedToMessageId: repliedToMessageId)

        /*
        // If WebSocket is connected, use real-time messaging
        let connectionState = await WebSocketManager.shared.connectionState
        if connectionState == .connected {
            logger.info("Sending message via WebSocket")
            await WebSocketManager.shared.sendMessage(content)
            return nil // Message will be delivered via publisher
        } else {
            // Fallback to REST API
            logger.info("WebSocket not connected, falling back to REST API")
            return try await sendMessage(conversationId: conversationId, content: content)
        }
        */
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
        get async {
            await WebSocketManager.shared.connectionState
        }
    }

    /// Gets last WebSocket error
    var lastError: ChatError? {
        get async {
            await WebSocketManager.shared.lastError
        }
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
            case .requestFailed, .decodeError, .unknown:
                return .networkError(error)
            default:
                return .networkError(error)
            }
        }

        return .networkError(error)
    }
}
