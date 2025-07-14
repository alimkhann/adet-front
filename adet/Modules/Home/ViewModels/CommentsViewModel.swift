import Foundation

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [PostComment] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var hasMoreComments = false

    private var nextCursor: String?
    private var currentPostId: Int?
    private let postService = PostService.shared

    func loadComments(for postId: Int, refresh: Bool = false) async {
        print("Loading comments for postId: \(postId)")
        guard !isLoading else { return }

        self.currentPostId = postId
        isLoading = true
        errorMessage = nil

        if refresh {
            nextCursor = nil
            comments = []
        }

        do {
            let response = try await postService.getPostComments(
                postId: postId,
                cursor: nextCursor
            )
            print("Loaded comments: \(response.comments.count)")

            if refresh {
                comments = response.comments
            } else {
                comments.append(contentsOf: response.comments)
            }

            nextCursor = response.nextCursor
            hasMoreComments = response.hasMore

        } catch {
            print("Failed to load comments: \(error)")
            errorMessage = "Failed to load comments. Please try again."
        }

        isLoading = false
    }

    func loadMoreComments() async {
        guard hasMoreComments && !isLoading, let postId = currentPostId else { return }
        await loadComments(for: postId, refresh: false)
    }

    func createComment(postId: Int, content: String, parentCommentId: Int? = nil) async -> Bool {
        guard !isSubmitting else { return false }

        isSubmitting = true
        errorMessage = nil

        let commentData = PostCommentCreate(
            postId: postId,
            content: content,
            parentCommentId: parentCommentId
        )

        do {
            let response = try await postService.createComment(commentData)

            if response.success {
                // Reload comments to get the updated list
                await loadComments(for: postId, refresh: true)
                isSubmitting = false
                return true
            } else {
                errorMessage = response.message
                isSubmitting = false
                return false
            }

        } catch {
            errorMessage = "Failed to post comment. Please try again."
            isSubmitting = false
            return false
        }
    }

    func toggleLike(for comment: PostComment) async {
        do {
            let response = try await postService.toggleCommentLike(commentId: comment.id)

            if response.success {
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments[index].isLikedByCurrentUser = response.isLiked
                    comments[index].likesCount = response.likesCount
                }
            }

        } catch {
            errorMessage = "Failed to toggle like. Please try again."
        }
    }

    func deleteComment(commentId: Int) async -> Bool {
        do {
            let success = try await postService.deleteComment(commentId: commentId)
            if success, let postId = currentPostId {
                await loadComments(for: postId, refresh: true)
            }
            return success
        } catch {
            errorMessage = "Failed to delete comment."
            return false
        }
    }

    func reportComment(commentId: Int, reason: String) async -> Bool {
        do {
            let success = try await postService.reportComment(commentId: commentId, reason: reason)
            if !success {
                errorMessage = "You have already reported this comment."
            }
            return success
        } catch {
            errorMessage = "Failed to report comment."
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Extensions

extension PostComment {
    var timeAgo: String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: createdAt) {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        } else {
            return createdAt
        }
    }
}
extension PostComment: Equatable {
    static func == (lhs: PostComment, rhs: PostComment) -> Bool {
        lhs.id == rhs.id
    }
}