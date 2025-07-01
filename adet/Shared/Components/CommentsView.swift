import SwiftUI

struct CommentsView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @StateObject private var commentsViewModel = CommentsViewModel()
    @State private var newCommentText = ""
    @State private var replyingTo: PostComment?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Post summary header
                postSummaryHeader

                Divider()

                // Comments list
                if commentsViewModel.comments.isEmpty && !commentsViewModel.isLoading {
                    emptyCommentsView
                } else {
                    commentsScrollView
                }

                // Comment input
                commentInputSection
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await commentsViewModel.loadComments(for: post.id)
            }
            .alert("Error", isPresented: .constant(commentsViewModel.errorMessage != nil)) {
                Button("OK") {
                    commentsViewModel.clearError()
                }
            } message: {
                if let errorMessage = commentsViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Post Summary Header

    private var postSummaryHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: post.user.profileImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(post.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("\(post.likesCount)")
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(post.commentsCount)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }

            if let description = post.description, !description.isEmpty {
                HStack {
                    Text(description)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Empty Comments View

    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No comments yet")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Comments Scroll View

    private var commentsScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(commentsViewModel.comments) { comment in
                    CommentRowView(
                        comment: comment,
                        onReply: { comment in
                            replyingTo = comment
                            isTextFieldFocused = true
                        },
                        onLike: { comment in
                            Task {
                                await commentsViewModel.toggleLike(for: comment)
                            }
                        }
                    )

                    // Load more when reaching the end
                    if comment == commentsViewModel.comments.last {
                        if commentsViewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding()
                        } else if commentsViewModel.hasMoreComments {
                            Color.clear
                                .onAppear {
                                    Task {
                                        await commentsViewModel.loadMoreComments()
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Comment Input Section

    private var commentInputSection: some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingTo {
                replyingToHeader(replyingTo)
            }

            HStack(spacing: 12) {
                TextField(replyingTo != nil ? "Reply to \(replyingTo!.user.displayName)..." : "Add a comment...",
                         text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)

                Button {
                    Task {
                        await submitComment()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(canSubmitComment ? .blue : .secondary)
                        .font(.title3)
                }
                .disabled(!canSubmitComment || commentsViewModel.isSubmitting)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    private func replyingToHeader(_ comment: PostComment) -> some View {
        HStack {
            Text("Replying to \(comment.user.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                replyingTo = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Helper Properties

    private var canSubmitComment: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func submitComment() async {
        guard canSubmitComment else { return }

        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentCommentId = replyingTo?.id

        let success = await commentsViewModel.createComment(
            postId: post.id,
            content: trimmedText,
            parentCommentId: parentCommentId
        )

        if success {
            newCommentText = ""
            replyingTo = nil
            isTextFieldFocused = false
        }
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: PostComment
    let onReply: (PostComment) -> Void
    let onLike: (PostComment) -> Void

    @State private var showReplies = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main comment
            commentContent

            // Action buttons
            commentActions

            // Replies (if any)
            if comment.repliesCount > 0 {
                repliesSection
            }

            Divider()
                .padding(.leading, 48)
        }
    }

    private var commentContent: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: comment.user.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    )
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.user.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(comment.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                Text(comment.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var commentActions: some View {
        HStack(spacing: 24) {
            Spacer()
                .frame(width: 40) // Align with content

            Button {
                onLike(comment)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                        .font(.caption)

                    if comment.likesCount > 0 {
                        Text("\(comment.likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                onReply(comment)
            } label: {
                Text("Reply")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showReplies.toggle()
            } label: {
                HStack {
                    Spacer()
                        .frame(width: 40)

                    Text(showReplies ? "Hide replies" : "View \(comment.repliesCount) replies")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.blue)

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)

            if showReplies {
                // TODO: Implement replies loading and display
                ForEach(0..<min(comment.repliesCount, 3), id: \.self) { _ in
                    // Placeholder for replies
                    HStack {
                        Spacer()
                            .frame(width: 60)

                        Text("Reply content placeholder...")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Comments ViewModel

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

            if refresh {
                comments = response.comments
            } else {
                comments.append(contentsOf: response.comments)
            }

            nextCursor = response.nextCursor
            hasMoreComments = response.hasMore

        } catch {
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

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Extensions

extension PostComment {
    var timeAgo: String {
        RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date())
    }
}

extension PostComment: Equatable {
    static func == (lhs: PostComment, rhs: PostComment) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    let samplePost = Post(
        id: 1,
        userId: 1,
        habitId: 1,
        proofUrls: ["https://example.com/image.jpg"],
        proofType: .image,
        description: "Just finished my morning workout!",
        privacy: .friends,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: nil,
        viewsCount: 15,
        likesCount: 5,
        commentsCount: 3,
        user: UserBasic(
            id: 1,
            username: "johndoe",
            firstName: "John",
            lastName: "Doe",
            bio: nil,
            profileImageUrl: nil
        ),
        habitStreak: 5,
        isLikedByCurrentUser: false,
        isViewedByCurrentUser: false
    )

    CommentsView(post: samplePost)
}

