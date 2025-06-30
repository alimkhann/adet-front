import SwiftUI

struct FeedView: View {
    @StateObject private var postsViewModel = PostsViewModel()
    @State private var showingCreatePost = false
    @State private var showingComments = false
    @State private var selectedPost: Post?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if postsViewModel.feedPosts.isEmpty && !postsViewModel.isLoadingFeed {
                    EmptyFeedView(onCreatePost: {
                        showingCreatePost = true
                    })
                } else {
                    feedContent
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .refreshable {
                await postsViewModel.loadFeedPosts(refresh: true)
            }
            .task {
                if postsViewModel.feedPosts.isEmpty {
                    await postsViewModel.loadFeedPosts(refresh: true)
                }
            }
            .sheet(isPresented: $showingCreatePost) {
                CreatePostView()
            }
            .sheet(isPresented: $showingComments) {
                if let post = selectedPost {
                    CommentsView(post: post)
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

    private var feedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Header section with time window info
                feedHeaderSection

                // Posts
                ForEach(postsViewModel.feedPosts) { post in
                    PostCardView(
                        post: post,
                        onLike: {
                            Task {
                                await postsViewModel.toggleLike(for: post)
                            }
                        },
                        onComment: {
                            selectedPost = post
                            showingComments = true
                        },
                        onView: {
                            Task {
                                await postsViewModel.markPostAsViewed(post)
                            }
                        },
                        onShare: {
                            sharePost(post)
                        },
                        onUserTap: {
                            // Navigate to user profile
                            // TODO: Implement navigation
                        }
                    )
                    .onAppear {
                        // Load more posts when approaching the end
                        if post == postsViewModel.feedPosts.last {
                            Task {
                                await postsViewModel.loadMoreFeedPosts()
                            }
                        }
                    }
                }

                // Loading indicator for pagination
                if postsViewModel.isLoadingFeed && !postsViewModel.feedPosts.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding()
                }

                // End of feed indicator
                if !postsViewModel.hasMorePosts && !postsViewModel.feedPosts.isEmpty {
                    endOfFeedSection
                }
            }
        }
    }

    private var feedHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Posts from the last 3 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Filter button (future feature)
                Menu {
                    Button("All Posts", systemImage: "list.bullet") {
                        // Filter implementation
                    }
                    Button("Close Friends Only", systemImage: "heart.fill") {
                        // Filter implementation
                    }
                    Button("Media Only", systemImage: "photo") {
                        // Filter implementation
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Divider()
        }
        .background(Color(.systemBackground))
    }

    private var endOfFeedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)

            Text("You're all caught up!")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Share your own progress to inspire others")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create Post") {
                showingCreatePost = true
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }

    private func sharePost(_ post: Post) {
        // Implement sharing functionality
        let shareText = "Check out this post from \(post.user.displayName)!"
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Empty Feed View

struct EmptyFeedView: View {
    let onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.person.crop")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Posts Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Be the first to share your progress!\nConnect with friends to see their posts here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("Create Your First Post") {
                    onCreatePost()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)

                NavigationLink("Find Friends") {
                    // Navigate to friends search
                    Text("Friends Search") // Placeholder
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Feed Filter Options

enum FeedFilter: String, CaseIterable {
    case all = "All Posts"
    case closeFriends = "Close Friends"
    case media = "Media Only"
    case recent = "Most Recent"

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .closeFriends: return "heart.fill"
        case .media: return "photo"
        case .recent: return "clock"
        }
    }
}

#Preview {
    FeedView()
}