import Foundation

// MARK: - Post Privacy Levels
enum PostPrivacy: String, CaseIterable, Identifiable, Codable {
    case `private` = "private"
    case friends = "friends"
    case closeFriends = "close_friends"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .private:
            return "Only me"
        case .friends:
            return "Friends"
        case .closeFriends:
            return "Close friends"
        }
    }

    var icon: String {
        switch self {
        case .private:
            return "lock.fill"
        case .friends:
            return "person.2.fill"
        case .closeFriends:
            return "heart.fill"
        }
    }

    var description: String {
        switch self {
        case .private:
            return "Only visible to you"
        case .friends:
            return "Visible to all friends"
        case .closeFriends:
            return "Visible to close friends only"
        }
    }

    var privacyColor: String {
        switch self {
        case .private:
            return "orange"
        case .friends:
            return "blue"
        case .closeFriends:
            return "red"
        }
    }
}

// MARK: - Proof Type Enum

enum ProofType: String, CaseIterable, Codable {
    case image = "image"
    case video = "video"
    case text = "text"
    case audio = "audio"

    var displayName: String {
        switch self {
        case .image:
            return "Photo"
        case .video:
            return "Video"
        case .text:
            return "Text"
        case .audio:
            return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .text:
            return "text.alignleft"
        case .audio:
            return "waveform"
        }
    }
}

// MARK: - Post Models

struct Post: Identifiable, Codable, Equatable {
    let id: Int
    let userId: Int
    let habitId: Int?
    let proofUrls: [String]
    let proofType: ProofType
    var proofContent: String?
    var description: String?
    var privacy: PostPrivacy
    let createdAt: Date
    let updatedAt: Date?

    // Analytics
    var viewsCount: Int
    var likesCount: Int
    let commentsCount: Int

    // User info (populated by API)
    let user: UserBasic

    // Habit streak at time of post
    let habitStreak: Int?

    // Interaction state (populated by API for current user)
    var isLikedByCurrentUser: Bool
    var isViewedByCurrentUser: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case habitId = "habit_id"
        case proofUrls = "proof_urls"
        case proofType = "proof_type"
        case proofContent = "proof_content"
        case description
        case privacy
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case viewsCount = "views_count"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case user
        case habitStreak = "habit_streak"
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case isViewedByCurrentUser = "is_viewed_by_current_user"
    }

    // Custom decoder to handle ISO8601 string dates
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        habitId = try container.decodeIfPresent(Int.self, forKey: .habitId)
        proofUrls = try container.decode([String].self, forKey: .proofUrls)
        proofType = try container.decode(ProofType.self, forKey: .proofType)
        proofContent = try container.decodeIfPresent(String.self, forKey: .proofContent)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        privacy = try container.decode(PostPrivacy.self, forKey: .privacy)
        // Decode ISO8601 string to Date
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let createdAtDate = isoFormatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid date format for createdAt: \(createdAtString)")
        }
        createdAt = createdAtDate
        if let updatedAtString = updatedAtString {
            updatedAt = isoFormatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
        viewsCount = try container.decode(Int.self, forKey: .viewsCount)
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        user = try container.decode(UserBasic.self, forKey: .user)
        habitStreak = try container.decodeIfPresent(Int.self, forKey: .habitStreak)
        isLikedByCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isLikedByCurrentUser) ?? false
        isViewedByCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isViewedByCurrentUser) ?? false
    }

    // Equatable conformance
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id
    }
}

struct PostUser: Codable {
    let id: Int
    let username: String
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
}

// MARK: - Post Comment Models

struct PostComment: Identifiable, Codable {
    let id: Int
    let postId: Int
    let userId: Int
    let content: String
    let createdAt: String
    let updatedAt: String?

    // User info
    let user: UserBasic

    // Interaction state
    var likesCount: Int
    var isLikedByCurrentUser: Bool

    // Reply support
    let parentCommentId: Int?
    let repliesCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
        case likesCount = "likes_count"
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case parentCommentId = "parent_comment_id"
        case repliesCount = "replies_count"
    }
}

// MARK: - Post Like Models

struct PostLike: Identifiable, Codable {
    let id: Int
    let postId: Int?
    let commentId: Int?
    let userId: Int
    let createdAt: Date

    // User info
    let user: UserBasic

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case commentId = "comment_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case user
    }
}

// MARK: - Post Extensions

extension Post {
    var timeAgo: String {
        RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date())
    }

    var isMediaPost: Bool {
        return proofType == .image || proofType == .video
    }

    var isTextPost: Bool {
        return proofType == .text || proofType == .audio
    }

    var primaryMediaUrl: String? {
        return proofUrls.first
    }

    var hasMultipleMedia: Bool {
        return proofUrls.count > 1
    }

    var displayDescription: String {
        return description ?? ""
    }

    var privacyIcon: String {
        return privacy.icon
    }
}

// MARK: - Post Creation Models

struct PostCreate: Codable {
    let habitId: Int?
    let proofUrls: [String]
    let proofType: ProofType
    let proofContent: String?
    let description: String?
    let privacy: PostPrivacy
    let assignedDate: String?

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case proofUrls = "proof_urls"
        case proofType = "proof_type"
        case proofContent = "proof_content"
        case description
        case privacy
        case assignedDate = "assigned_date"
    }
}

struct PostUpdate: Codable {
    let description: String?
    let privacy: PostPrivacy
}

struct PostCommentCreate: Codable {
    let postId: Int
    let content: String
    let parentCommentId: Int?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case content
        case parentCommentId = "parent_comment_id"
    }
}

// MARK: - API Response Models

struct PostsResponse: Codable {
    let posts: [Post]
    let count: Int
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case posts
        case count
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct PostCommentsResponse: Codable {
    let comments: [PostComment]
    let count: Int
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case comments
        case count
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct PostActionResponse: Codable {
    let success: Bool
    let message: String
    let post: Post?
}

struct CommentActionResponse: Codable {
    let success: Bool
    let message: String
    let comment: PostComment?
}

struct LikeActionResponse: Codable {
    let success: Bool
    let message: String
    let isLiked: Bool
    let likesCount: Int

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case isLiked = "is_liked"
        case likesCount = "likes_count"
    }
}

// MARK: - Analytics Models

struct PostAnalytics: Codable {
    let postId: Int
    let viewsCount: Int
    let likesCount: Int
    let commentsCount: Int
    let sharesCount: Int
    let topLikers: [UserBasic]
    let engagementRate: Double

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case viewsCount = "views_count"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case sharesCount = "shares_count"
        case topLikers = "top_likers"
        case engagementRate = "engagement_rate"
    }
}

// MARK: - Post Creation Response
struct PostResponse: Codable {
    let post: Post
}
