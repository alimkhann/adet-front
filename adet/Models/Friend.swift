import Foundation

// MARK: - Friend Models

struct Friend: Codable, Identifiable {
    let id: Int
    let userId: Int
    let friendId: Int
    let friend: UserBasic
    let status: String
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case friend
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FriendRequest: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let receiverId: Int
    let sender: UserBasic
    let receiver: UserBasic
    let status: String
    let message: String?
    let createdAt: Date
    let updatedAt: Date?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case sender
        case receiver
        case status
        case message
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
}

struct UserBasic: Codable, Identifiable {
    let id: Int
    let username: String?
    let name: String?
    let bio: String?
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case bio
        case profileImageUrl = "profile_image_url"
    }

    // Computed properties for display
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return username ?? "Unknown User"
    }

    var displayUsername: String {
        return username ?? "no_username"
    }
}

// MARK: - Friend Request Status Enum

enum FriendRequestStatus: String, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case cancelled = "cancelled"
}

// MARK: - Friendship Status Enum

enum FriendshipStatus: String, CaseIterable {
    case none = "none"
    case friends = "friends"
    case requestSent = "request_sent"
    case requestReceived = "request_received"
}