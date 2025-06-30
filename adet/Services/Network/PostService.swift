import Foundation
import OSLog

actor PostService {
    static let shared = PostService()
    private let networkService = NetworkService.shared
    private let logger = Logger(subsystem: "com.adet.api", category: "PostService")

    private init() {}

    // MARK: - Feed Operations

    /// Get feed posts (3-day window, BeReal style)
    func getFeedPosts(cursor: String? = nil) async throws -> PostsResponse {
        logger.info("Fetching feed posts")
        var endpoint = "/api/v1/posts/feed"

        if let cursor = cursor {
            endpoint += "?cursor=\(cursor)"
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Get posts for a specific user
    func getUserPosts(userId: Int, cursor: String? = nil) async throws -> PostsResponse {
        logger.info("Fetching posts for user \(userId)")
        var endpoint = "/api/v1/posts/user/\(userId)"

        if let cursor = cursor {
            endpoint += "?cursor=\(cursor)"
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Get current user's posts (including private)
    func getMyPosts(cursor: String? = nil) async throws -> PostsResponse {
        logger.info("Fetching my posts")
        var endpoint = "/api/v1/posts/me"

        if let cursor = cursor {
            endpoint += "?cursor=\(cursor)"
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    // MARK: - Post CRUD Operations

    /// Create a new post
    func createPost(_ postData: PostCreate) async throws -> PostActionResponse {
        logger.info("Creating new post")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts",
            method: "POST",
            body: postData
        )
    }

    /// Get a specific post by ID
    func getPost(id: Int) async throws -> Post {
        logger.info("Fetching post \(id)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(id)",
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Update a post (privacy and description only)
    func updatePost(id: Int, updateData: PostUpdate) async throws -> PostActionResponse {
        logger.info("Updating post \(id)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(id)",
            method: "PUT",
            body: updateData
        )
    }

    /// Delete a post (admin only)
    func deletePost(id: Int) async throws -> PostActionResponse {
        logger.info("Deleting post \(id)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(id)",
            method: "DELETE",
            body: (nil as String?)
        )
    }

    // MARK: - Like Operations

    /// Toggle like on a post
    func togglePostLike(postId: Int) async throws -> LikeActionResponse {
        logger.info("Toggling like for post \(postId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(postId)/like",
            method: "POST",
            body: (nil as String?)
        )
    }

    /// Toggle like on a comment
    func toggleCommentLike(commentId: Int) async throws -> LikeActionResponse {
        logger.info("Toggling like for comment \(commentId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/comments/\(commentId)/like",
            method: "POST",
            body: (nil as String?)
        )
    }

    /// Get users who liked a post
    func getPostLikes(postId: Int) async throws -> [PostLike] {
        logger.info("Fetching likes for post \(postId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(postId)/likes",
            method: "GET",
            body: (nil as String?)
        )
    }

    // MARK: - Comment Operations

    /// Get comments for a post
    func getPostComments(postId: Int, cursor: String? = nil) async throws -> PostCommentsResponse {
        logger.info("Fetching comments for post \(postId)")
        var endpoint = "/api/v1/posts/\(postId)/comments"

        if let cursor = cursor {
            endpoint += "?cursor=\(cursor)"
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Create a new comment
    func createComment(_ commentData: PostCommentCreate) async throws -> CommentActionResponse {
        logger.info("Creating comment for post \(commentData.postId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/comments",
            method: "POST",
            body: commentData
        )
    }

    /// Get replies to a comment
    func getCommentReplies(commentId: Int, cursor: String? = nil) async throws -> PostCommentsResponse {
        logger.info("Fetching replies for comment \(commentId)")
        var endpoint = "/api/v1/posts/comments/\(commentId)/replies"

        if let cursor = cursor {
            endpoint += "?cursor=\(cursor)"
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: endpoint,
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Delete a comment
    func deleteComment(id: Int) async throws -> CommentActionResponse {
        logger.info("Deleting comment \(id)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/comments/\(id)",
            method: "DELETE",
            body: (nil as String?)
        )
    }

    // MARK: - Analytics Operations

    /// Mark post as viewed
    func markPostAsViewed(postId: Int) async throws {
        logger.debug("Marking post \(postId) as viewed")
        let _: PostActionResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(postId)/view",
            method: "POST",
            body: (nil as String?)
        )
    }

    /// Get post analytics
    func getPostAnalytics(postId: Int) async throws -> PostAnalytics {
        logger.info("Fetching analytics for post \(postId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/\(postId)/analytics",
            method: "GET",
            body: (nil as String?)
        )
    }

    // MARK: - Media Upload Operations

    /// Upload media files for a post
    func uploadPostMedia(_ mediaData: [Data], types: [ProofType]) async throws -> [String] {
        logger.info("Uploading \(mediaData.count) media files")

        var uploadedUrls: [String] = []

        for (index, data) in mediaData.enumerated() {
            let type = types[safe: index] ?? .image
            let url = try await uploadSingleMedia(data, type: type)
            uploadedUrls.append(url)
        }

        return uploadedUrls
    }

    /// Upload a single media file
    private func uploadSingleMedia(_ data: Data, type: ProofType) async throws -> String {
        // This would integrate with your media upload service (Azure, AWS, etc.)
        // For now, return a placeholder URL
        let mediaId = UUID().uuidString
        return "https://media.adet.app/posts/\(mediaId).\(type.fileExtension)"
    }

    // MARK: - Batch Operations

    /// Mark multiple posts as viewed (for feed scrolling)
    func markPostsAsViewed(postIds: [Int]) async throws {
        logger.debug("Marking \(postIds.count) posts as viewed")

        let requestBody = ["post_ids": postIds]

        let _: PostActionResponse = try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/posts/batch/view",
            method: "POST",
            body: requestBody
        )
    }

    /// Preload posts for better UX
    func preloadPosts(postIds: [Int]) async {
        // Cache posts for faster loading
        for postId in postIds {
            do {
                let _ = try await getPost(id: postId)
                logger.debug("Preloaded post \(postId)")
            } catch {
                logger.warning("Failed to preload post \(postId): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Helper Extensions

extension ProofType {
    var fileExtension: String {
        switch self {
        case .image:
            return "jpg"
        case .video:
            return "mp4"
        case .text:
            return "txt"
        case .audio:
            return "m4a"
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}