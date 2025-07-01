import Foundation

// MARK: - Chat Models

struct Conversation: Codable, Identifiable, Hashable {
    let id: Int
    let participant1Id: Int
    let participant2Id: Int
    let createdAt: Date
    let updatedAt: Date?
    let lastMessageAt: Date
    let otherParticipant: UserBasic
    let lastMessage: Message?
    let unreadCount: Int
    let isOtherOnline: Bool
    let otherLastSeen: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case participant1Id = "participant_1_id"
        case participant2Id = "participant_2_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
        case otherParticipant = "other_participant"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case isOtherOnline = "is_other_online"
        case otherLastSeen = "other_last_seen"
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Message: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let conversationId: Int
    let senderId: Int
    let content: String
    let messageType: String
    let status: MessageStatus
    let createdAt: Date
    let deliveredAt: Date?
    let readAt: Date?
    let sender: UserBasic
    let repliedToMessageId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case status
        case createdAt = "created_at"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case sender
        case repliedToMessageId = "replied_to_message_id"
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
}

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case system = "system"
}

// MARK: - API Request/Response Models

struct ConversationCreateRequest: Codable {
    let participantId: Int

    enum CodingKeys: String, CodingKey {
        case participantId = "participant_id"
    }
}

struct MessageCreateRequest: Codable {
    let content: String
    let messageType: String
    let repliedToMessageId: Int?

    enum CodingKeys: String, CodingKey {
        case content
        case messageType = "message_type"
        case repliedToMessageId = "replied_to_message_id"
    }

    init(content: String, messageType: MessageType = .text, repliedToMessageId: Int? = nil) {
        self.content = content
        self.messageType = messageType.rawValue
        self.repliedToMessageId = repliedToMessageId
    }
}

struct ConversationListResponse: Codable {
    let conversations: [Conversation]
}

struct MessageListResponse: Codable {
    let messages: [Message]
    let totalCount: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case messages
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

struct MessageEditRequest: Codable {
    let content: String
}

struct MessageDeleteRequest: Codable {
    let deleteForEveryone: Bool

    enum CodingKeys: String, CodingKey {
        case deleteForEveryone = "delete_for_everyone"
    }
}

struct MarkAsReadRequest: Codable {
    let lastMessageId: Int

    enum CodingKeys: String, CodingKey {
        case lastMessageId = "last_message_id"
    }
}

// MARK: - WebSocket Event Models

struct WebSocketMessage: Codable {
    let eventType: String
    let data: [String: Any]
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case data
        case timestamp
    }

    init(eventType: String, data: [String: Any] = [:]) {
        self.eventType = eventType
        self.data = data
        self.timestamp = Date()
    }

    // Custom encoding for Any values
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)

        // Convert data to JSON data and then to string
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .data)
        }
    }

    // Custom decoding for Any values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(String.self, forKey: .eventType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Try to decode data as JSON string first
        if let jsonString = try? container.decode(String.self, forKey: .data),
           let jsonData = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            data = jsonObject
        } else {
            // Fallback to empty dictionary
            data = [:]
        }
    }
}

// MARK: - WebSocket Event Types

enum WebSocketEventType: String, CaseIterable {
    case sendMessage = "send_message"
    case typing = "typing"
    case markRead = "mark_read"

    // Incoming events
    case message = "message"
    case messageStatus = "message_status"
    case typingIndicator = "typing_indicator"
    case presence = "presence"
    case connection = "connection"
    case error = "error"
    case messageSent = "message_sent"
}

// MARK: - WebSocket Event Data Models

struct SendMessageEventData {
    let content: String

    var dictionary: [String: Any] {
        return ["content": content]
    }
}

struct TypingEventData {
    let isTyping: Bool

    var dictionary: [String: Any] {
        return ["is_typing": isTyping]
    }
}

struct MarkReadEventData {
    let lastMessageId: Int

    var dictionary: [String: Any] {
        return ["last_message_id": lastMessageId]
    }
}

// MARK: - Incoming WebSocket Events

struct MessageEvent: Codable {
    let type: String
    let conversationId: Int
    let message: Message

    enum CodingKeys: String, CodingKey {
        case type
        case conversationId = "conversation_id"
        case message
    }
}

struct TypingEvent: Codable {
    let type: String
    let conversationId: Int
    let userId: Int
    let isTyping: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case conversationId = "conversation_id"
        case userId = "user_id"
        case isTyping = "is_typing"
    }
}

struct PresenceEvent: Codable {
    let type: String
    let conversationId: Int
    let userId: Int
    let isOnline: Bool
    let lastSeen: Date?

    enum CodingKeys: String, CodingKey {
        case type
        case conversationId = "conversation_id"
        case userId = "user_id"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
    }
}

struct MessageStatusEvent: Codable {
    let type: String
    let conversationId: Int
    let messageId: Int
    let status: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case type
        case conversationId = "conversation_id"
        case messageId = "message_id"
        case status
        case timestamp
    }
}

struct ConnectionEvent: Codable {
    let type: String
    let status: String
    let message: String?
}

// MARK: - Connection States

enum ConnectionState: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
}

// MARK: - Chat Error Types

enum ChatError: LocalizedError {
    case connectionFailed
    case authenticationFailed
    case messageNotSent
    case conversationNotFound
    case networkError(Error)
    case invalidData
    case webSocketError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to chat server"
        case .authenticationFailed:
            return "Authentication failed"
        case .messageNotSent:
            return "Message could not be sent"
        case .conversationNotFound:
            return "Conversation not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data received"
        case .webSocketError(let message):
            return "WebSocket error: \(message)"
        }
    }
}

// MARK: - Debug Extensions
#if DEBUG
extension Message {
    static func createTestMessage(id: Int, content: String, repliedToMessageId: Int? = nil) -> Message {
        return Message(
            id: id,
            conversationId: 1,
            senderId: 1,
            content: content,
            messageType: "text",
            status: .sent,
            createdAt: Date(),
            deliveredAt: Date(),
            readAt: nil,
            sender: UserBasic(id: 1, username: "test", name: "Test User", bio: nil, profileImageUrl: nil),
            repliedToMessageId: repliedToMessageId
        )
    }

    /// Test function to verify reply system works without infinite recursion
    static func testReplySystem() {
        // Create a message
        let originalMessage = createTestMessage(id: 1, content: "Original message")

        // Create a reply to that message
        let replyMessage = createTestMessage(id: 2, content: "Reply to original", repliedToMessageId: originalMessage.id)

        // Verify the reply relationship
        assert(replyMessage.repliedToMessageId == originalMessage.id)
        assert(originalMessage.repliedToMessageId == nil)

        print("✅ Reply system test passed - no infinite recursion!")
    }
}
#endif
