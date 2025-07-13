import SwiftUI

struct FeedView: View {
    @StateObject private var postsViewModel = PostsViewModel()
    @State private var refreshTrigger = false

    var body: some View {
        NavigationView {
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
                        onComment: { showComments(for: post) },
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
            .padding(.horizontal)
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
        // TODO: Navigate to comments view
        print("Show comments for post \(post.id)")
    }

    private func sharePost(_ post: Post) {
        // TODO: Implement native sharing
        print("Share post \(post.id)")
    }

    private func showUserProfile(for user: UserBasic) {
        // TODO: Navigate to user profile view
        print("Show user profile for user \(user.id)")
    }
}

#Preview {
    FeedView()
}
