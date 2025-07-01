import Foundation

// MARK: - Friend Models

struct Friend: Identifiable, Codable {
    let id: Int
    let userId: Int
    let friendId: Int
    let createdAt: Date
    let user: UserBasic
    var isCloseFriend: Bool = false // New field for close friends

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case createdAt = "created_at"
        case user
        case isCloseFriend = "is_close_friend"
    }

    // Computed property for compatibility
    var friend: UserBasic {
        return user
    }
}

struct FriendRequest: Identifiable, Codable {
    let id: Int
    let requesterId: Int
    let requestedId: Int
    let status: FriendRequestStatus
    let createdAt: Date
    let expiresAt: Date?
    let user: UserBasic
    let message: String?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case requestedId = "requested_id"
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case user
        case message
    }

    // Computed properties for compatibility
    var sender: UserBasic {
        return user
    }

    var receiver: UserBasic {
        return user
    }
}

struct UserBasic: Codable, Identifiable, Hashable {
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
    var fullName: String {
        if let name = name, !name.isEmpty {
            return name
        } else if let username = username, !username.isEmpty {
            return username
        } else {
            return "User"
        }
    }

    // Use fullName for display
    var displayName: String {
        return fullName
    }

    var displayUsername: String {
        return username ?? "no_username"
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UserBasic, rhs: UserBasic) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Friend Request Status Enum

enum FriendRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case cancelled = "cancelled"

    var statusDisplayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        case .cancelled:
            return "Cancelled"
        }
    }
}

// MARK: - Friendship Status Enum

enum FriendshipStatus: String, Codable {
    case none = "none"
    case friends = "friends"
    case requestSent = "request_sent"
    case requestReceived = "request_received"

    var actionDisplayName: String {
        switch self {
        case .none:
            return "Add Friend"
        case .friends:
            return "Remove Friend"
        case .requestSent:
            return "Cancel Request"
        case .requestReceived:
            return "Respond to Request"
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "person.badge.plus"
        case .friends:
            return "person.badge.minus"
        case .requestSent:
            return "clock"
        case .requestReceived:
            return "person.badge.clock"
        }
    }
}

// MARK: - Profile Statistics

struct ProfileStat {
    let title: String
    let value: String
}

// MARK: - Close Friends API Models
struct CloseFriendsResponse: Codable {
    let closeFriends: [UserBasic]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case closeFriends = "close_friends"
        case count
    }
}

struct CloseFriendRequest: Codable {
    let friendId: Int
    let isCloseFriend: Bool

    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
        case isCloseFriend = "is_close_friend"
    }
}
