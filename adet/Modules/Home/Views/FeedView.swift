import SwiftUI

struct FeedView: View {
    @EnvironmentObject var postsViewModel: PostsViewModel
    @State private var refreshTrigger = false
    @State private var showCommentsSheet = false
    @State private var selectedPost: Post? = nil
    @EnvironmentObject var currentUser: AuthViewModel
    @State private var selectedUserId: Int? = nil
    @State private var showProfile: Bool = false
    @StateObject private var commentsViewModel = CommentsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
                    loadingView
                } else if postsViewModel.posts.isEmpty && !postsViewModel.isLoading {
                    emptyStateView
                } else {
                    feedContent
                }
            }
            .navigationTitle("ädet")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                print("DEBUG: .refreshable triggered in FeedView at \(Date())")
                await refreshFeed()
            }
            .onAppear {
                print("DEBUG: .onAppear triggered in FeedView at \(Date())")
                Task {
                    await loadFeedIfNeeded()
                }
            }
            .alert("Error", isPresented: .constant(postsViewModel.errorMessage != nil)) {
                Button("OK") {
                    postsViewModel.clearError()
                }
            } message: {
                if let errorMessage = postsViewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            // --- Comments Sheet ---
            .sheet(item: $selectedPost) { post in
                CommentsSheetView(
                    viewModel: commentsViewModel,
                    postId: post.id,
                    currentUser: currentUser.user!.asUserBasic,
                    isPresented: Binding(
                        get: { selectedPost != nil },
                        set: { if !$0 { selectedPost = nil } }
                    ),
                    onUserTap: { user in
                        // Dismiss comments sheet before navigating
                        selectedPost = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showUserProfile(for: user)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(item: $selectedUserId) { userId in
                OtherUserProfileView(userId: userId)
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(postsViewModel.posts) { post in
                    PostCardView(
                        post: post,
                        onLike: {
                            Task { await toggleLike(for: post) }
                        },
                        onComment: {
                            print("Opening comments for post id: \(post.id)")
                            selectedPost = post
                            DispatchQueue.main.async {
                                showCommentsSheet = true
                            }
                        },
                        onView: {
                            Task { await postsViewModel.markAsViewed(postId: post.id) }
                        },
                        onShare: { sharePost(post) },
                        onUserTap: { showUserProfile(for: post.user) }
                    )
                    .onAppear {
                        // Load more posts when approaching the end
                        if post == postsViewModel.posts.last {
                            Task {
                                await postsViewModel.loadMorePosts()
                            }
                        }
                    }
                }

                // Loading more indicator
                if postsViewModel.isLoadingFeed && !postsViewModel.posts.isEmpty {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading feed...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No posts yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Be the first to share your habit progress!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func loadFeedIfNeeded() async {
        print("DEBUG: loadFeedIfNeeded called in FeedView at \(Date())")
        if postsViewModel.posts.isEmpty && !postsViewModel.isLoading {
            await postsViewModel.loadFeed()
        }
    }

    private func refreshFeed() async {
        print("DEBUG: refreshFeed called in FeedView at \(Date())")
        await postsViewModel.refreshFeed()
    }

    private func toggleLike(for post: Post) async {
        await postsViewModel.toggleLike(for: post)
    }

    private func showComments(for post: Post) {
        selectedPost = post
        DispatchQueue.main.async {
            showCommentsSheet = true
        }
    }

    private func sharePost(_ post: Post) {
        // TODO: Implement native sharing
        print("Share post \(post.id)")
    }

    private func showUserProfile(for user: UserBasic) {
        if user.id == currentUser.user?.id {
            showProfile = true
        } else {
            selectedUserId = user.id
        }
    }
}

#Preview {
    FeedView()
}
