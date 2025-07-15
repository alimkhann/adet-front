import Foundation
import SwiftUI
import OSLog

@MainActor
class PostsViewModel: ObservableObject {
    @Published var feedPosts: [Post] = []
    @Published var myPosts: [Post] = []
    @Published var isLoadingFeed = false
    @Published var isLoadingMyPosts = false
    @Published var isCreatingPost = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var hasMorePosts = false

    // Pagination
    private var nextCursor: String?
    private var myPostsCursor: String?

    // Services
    private let postService = PostService.shared
    private let logger = Logger(subsystem: "com.adet.posts", category: "PostsViewModel")

    // Cache for viewed posts to avoid duplicate API calls
    @Published var viewedPostIds: Set<Int> = []

    // MARK: - Convenience Properties for Profile
    var personalPosts: [Post] { myPosts }
    var isLoading: Bool { isLoadingMyPosts || isLoadingFeed }

    init() {
#if DEBUG
        print("DEBUG: PostsViewModel init at \(Date())")
#endif
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .userDidCreatePost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let post = notification.object as? Post {
                    self?.handleNewPost(post)
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .userDidDeletePost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let postId = notification.object as? Int {
                    self?.handleDeletedPost(postId)
                }
            }
        }
    }

    // MARK: - Convenience Methods for Profile

    func loadPersonalPosts() async {
        await loadMyPosts(refresh: true)
    }

    func toggleLike(postId: Int) async {
        guard let post = getPost(by: postId) else { return }
        await toggleLike(for: post)
    }

    func markAsViewed(postId: Int) async {
        guard let post = getPost(by: postId) else { return }
        await markPostAsViewed(post)
    }

    // MARK: - Feed Operations

    func loadFeed() async {
        await loadFeedPosts(refresh: true)
    }

    func refreshFeed() async {
        await loadFeedPosts(refresh: true)
    }

    func loadMorePosts() async {
        await loadMoreFeedPosts()
    }

    // Alias for compatibility
    var posts: [Post] { feedPosts }

    func loadFeedPosts(refresh: Bool = false) async {
#if DEBUG
        print("DEBUG: loadFeedPosts called at \(Date()) with refresh=\(refresh)")
#endif
        guard !isLoadingFeed else { return }

        isLoadingFeed = true
        errorMessage = nil

        if refresh {
            nextCursor = nil
            feedPosts = []
        }

        do {
            let response = try await postService.getFeedPosts(cursor: nextCursor)

            if refresh {
                feedPosts = response.posts
            } else {
                feedPosts.append(contentsOf: response.posts)
            }

            nextCursor = response.nextCursor
            hasMorePosts = response.hasMore

            logger.info("Loaded \(response.posts.count) feed posts")
#if DEBUG
            print("DEBUG: Feed posts loaded: \(feedPosts.map { ($0.id, $0.userId, $0.privacy) })")
#endif

        } catch {
            logger.error("Failed to load feed posts: \(error.localizedDescription)")
            errorMessage = "Failed to load posts. Please try again."
        }

        isLoadingFeed = false
    }

    func loadMoreFeedPosts() async {
        guard hasMorePosts && !isLoadingFeed else { return }
        await loadFeedPosts(refresh: false)
    }

    // MARK: - My Posts Operations

    func loadMyPosts(refresh: Bool = false) async {
#if DEBUG
        print("DEBUG: loadMyPosts called at \(Date()) with refresh=\(refresh)")
#endif
        guard !isLoadingMyPosts else { return }

        isLoadingMyPosts = true
        errorMessage = nil

        if refresh {
            myPostsCursor = nil
            myPosts = []
        }

        do {
            let response = try await postService.getMyPosts(cursor: myPostsCursor)

            if refresh {
                myPosts = response.posts
            } else {
                myPosts.append(contentsOf: response.posts)
            }

            myPostsCursor = response.nextCursor

            logger.info("Loaded \(response.posts.count) my posts")

        } catch {
            logger.error("Failed to load my posts: \(error.localizedDescription)")
            errorMessage = "Failed to load your posts. Please try again."
        }

        isLoadingMyPosts = false
    }

    // MARK: - Post Creation

    func createPost(
        habitId: Int? = nil,
        proofUrls: [String],
        proofType: ProofType,
        proofContent: String? = nil,
        description: String?,
        privacy: PostPrivacy,
        assignedDate: String?
    ) async -> Bool {
        guard !isCreatingPost else { return false }

        isCreatingPost = true
        errorMessage = nil

        let postData = PostCreate(
            habitId: habitId,
            proofUrls: proofUrls,
            proofType: proofType,
            proofContent: proofContent,
            description: description,
            privacy: privacy,
            assignedDate: assignedDate
        )

        do {
            let response = try await postService.createPost(postData)

            if response.success, let newPost = response.post {
                // Add to beginning of feed and my posts
                feedPosts.insert(newPost, at: 0)
                myPosts.insert(newPost, at: 0)

                // Post notification
                NotificationCenter.default.post(
                    name: .userDidCreatePost,
                    object: newPost
                )

                logger.info("Successfully created post \(newPost.id)")
                isCreatingPost = false
                return true
            } else {
                errorMessage = response.message
                isCreatingPost = false
                return false
            }

        } catch {
            logger.error("Failed to create post: \(error.localizedDescription)")
            errorMessage = "Failed to create post. Please try again."
            isCreatingPost = false
            return false
        }
    }

    // MARK: - Post Interactions

    func toggleLike(for post: Post) async {
        do {
            let response = try await postService.togglePostLike(postId: post.id)

            if response.success {
                updatePostInCollections(postId: post.id) { updatedPost in
                    updatedPost.isLikedByCurrentUser = response.isLiked
                    updatedPost.likesCount = response.likesCount
                }

                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()

                logger.debug("Toggled like for post \(post.id): \(response.isLiked)")
            }

        } catch {
            logger.error("Failed to toggle like: \(error.localizedDescription)")
            errorMessage = "Failed to like post. Please try again."
        }
    }

    func markPostAsViewed(_ post: Post) async {
        // Avoid duplicate API calls for already viewed posts
        guard !viewedPostIds.contains(post.id) else { return }

        viewedPostIds.insert(post.id)

        do {
            try await postService.markPostAsViewed(postId: post.id)

            updatePostInCollections(postId: post.id) { updatedPost in
                updatedPost.isViewedByCurrentUser = true
                updatedPost.viewsCount += 1
            }

            logger.debug("Marked post \(post.id) as viewed")

        } catch {
            // Remove from viewed set if API call failed
            viewedPostIds.remove(post.id)
            logger.warning("Failed to mark post as viewed: \(error.localizedDescription)")
        }
    }

    func updatePost(
        postId: Int,
        description: String?,
        privacy: PostPrivacy
    ) async -> Bool {
        let updateData = PostUpdate(description: description, privacy: privacy)

        do {
            let response = try await postService.updatePost(id: postId, updateData: updateData)

            if response.success {
                updatePostInCollections(postId: postId) { updatedPost in
                    updatedPost.description = description
                    updatedPost.privacy = privacy
                }

                logger.info("Successfully updated post \(postId)")
                return true
            } else {
                errorMessage = response.message
                return false
            }

        } catch {
            logger.error("Failed to update post: \(error.localizedDescription)")
            errorMessage = "Failed to update post. Please try again."
            return false
        }
    }

    func updatePostPrivacy(postId: Int, privacy: PostPrivacy) async -> Bool {
        do {
            let response = try await postService.updatePostPrivacy(postId: postId, privacy: privacy)

            if response.success {
                updatePostInCollections(postId: postId) { updatedPost in
                    updatedPost.privacy = privacy
                }

                logger.info("Successfully updated post \(postId) privacy to \(privacy.rawValue)")
                return true
            } else {
                errorMessage = response.message
                return false
            }

        } catch {
            logger.error("Failed to update post privacy: \(error.localizedDescription)")
            errorMessage = "Failed to update post privacy. Please try again."
            return false
        }
    }

    // MARK: - Helper Methods

    private func updatePostInCollections(postId: Int, update: (inout Post) -> Void) {
        // Update in feed posts
        if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
            update(&feedPosts[index])
        }

        // Update in my posts
        if let index = myPosts.firstIndex(where: { $0.id == postId }) {
            update(&myPosts[index])
        }
    }

    private func handleNewPost(_ post: Post) {
        // Add to beginning of collections if not already present
        if !feedPosts.contains(where: { $0.id == post.id }) {
            feedPosts.insert(post, at: 0)
        }
        if !myPosts.contains(where: { $0.id == post.id }) {
            myPosts.insert(post, at: 0)
        }
    }

    private func handleDeletedPost(_ postId: Int) {
        feedPosts.removeAll { $0.id == postId }
        myPosts.removeAll { $0.id == postId }
        viewedPostIds.remove(postId)
    }

    // MARK: - Utility Methods

    func clearError() {
        errorMessage = nil
    }

    func getPost(by id: Int) -> Post? {
        return feedPosts.first { $0.id == id } ?? myPosts.first { $0.id == id }
    }

    func refreshAllPosts() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadFeedPosts(refresh: true)
            }
            group.addTask {
                await self.loadMyPosts(refresh: true)
            }
        }
    }

    // MARK: - Analytics

    func getPostAnalytics(for postId: Int) async -> PostAnalytics? {
        do {
            return try await postService.getPostAnalytics(postId: postId)
        } catch {
            logger.error("Failed to get post analytics: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Privacy Helpers

    func getVisiblePosts(from posts: [Post], for privacy: PostPrivacy) -> [Post] {
        return posts.filter { $0.privacy == privacy }
    }

    func canEditPost(_ post: Post, currentUserId: Int) -> Bool {
        return post.userId == currentUserId
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        logger.error("\(message)")
    }

    private func showSuccessMessage(_ message: String) {
        logger.info("\(message)")
    }

    // MARK: - Computed Properties for Privacy Selection

    var privacyOptions: [PostPrivacy] {
        PostPrivacy.allCases
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidCreatePost = Notification.Name("userDidCreatePost")
    static let userDidDeletePost = Notification.Name("userDidDeletePost")
    static let userDidUpdatePost = Notification.Name("userDidUpdatePost")
}

// MARK: - Post Extensions for UI

extension Post {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var isRecent: Bool {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return createdAt > oneDayAgo
    }

    var primaryImageUrl: String? {
        return proofUrls.first
    }

    var hasMultipleImages: Bool {
        return proofUrls.count > 1
    }

    var privacyDisplayText: String {
        switch privacy {
        case .private:
            return "Private"
        case .friends:
            return "Friends"
        case .closeFriends:
            return "Close Friends"
        }
    }

    var engagementCount: Int {
        return likesCount + commentsCount
    }
}

// MARK: - Preview Support

extension PostsViewModel {
    static let preview: PostsViewModel = {
        let vm = PostsViewModel()
        // Add some mock data for previews if needed
        return vm
    }()
}
