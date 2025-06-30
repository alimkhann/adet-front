import Foundation

// MARK: - Post Models

struct Post: Identifiable, Codable {
    let id: Int
    let userId: Int
    let habitId: Int?
    let proofUrls: [String]
    let proofType: ProofType
    let description: String?
    let privacy: PostPrivacy
    let createdAt: Date
    let updatedAt: Date?

    // Analytics
    let viewsCount: Int
    let likesCount: Int
    let commentsCount: Int

    // User info (populated by API)
    let user: UserBasic

    // Interaction state (populated by API for current user)
    let isLikedByCurrentUser: Bool
    let isViewedByCurrentUser: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case habitId = "habit_id"
        case proofUrls = "proof_urls"
        case proofType = "proof_type"
        case description
        case privacy
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case viewsCount = "views_count"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case user
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case isViewedByCurrentUser = "is_viewed_by_current_user"
    }
}

// MARK: - Post Creation Models

struct PostCreate: Codable {
    let habitId: Int?
    let proofUrls: [String]
    let proofType: ProofType
    let description: String?
    let privacy: PostPrivacy

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case proofUrls = "proof_urls"
        case proofType = "proof_type"
        case description
        case privacy
    }
}

struct PostUpdate: Codable {
    let description: String?
    let privacy: PostPrivacy
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

// MARK: - Post Comment Models

struct PostComment: Identifiable, Codable {
    let id: Int
    let postId: Int
    let userId: Int
    let content: String
    let createdAt: Date
    let updatedAt: Date?

    // User info
    let user: UserBasic

    // Interaction state
    let likesCount: Int
    let isLikedByCurrentUser: Bool

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

// MARK: - Feed Models

struct FeedPost: Identifiable {
    let id: Int
    let post: Post
    let timeAgo: String
    let isFromCloseFriend: Bool

    init(post: Post, isFromCloseFriend: Bool = false) {
        self.id = post.id
        self.post = post
        self.isFromCloseFriend = isFromCloseFriend
        self.timeAgo = RelativeDateTimeFormatter().localizedString(for: post.createdAt, relativeTo: Date())
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

    var privacyColor: String {
        switch privacy {
        case .private:
            return "orange"
        case .friends:
            return "blue"
        case .closeFriends:
            return "red"
        }
    }
}