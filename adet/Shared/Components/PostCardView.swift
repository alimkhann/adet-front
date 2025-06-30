import SwiftUI
import Kingfisher

struct PostCardView: View {
    let post: Post
    let onLike: () -> Void
    let onComment: () -> Void
    let onView: () -> Void
    let onShare: () -> Void
    let onUserTap: () -> Void

    @State private var imageAspectRatio: CGFloat = 1.0
    @State private var showFullDescription = false
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            PostHeaderView(
                user: post.user,
                timeAgo: post.timeAgo,
                privacy: post.privacy,
                onUserTap: onUserTap
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Media content
            if post.isMediaPost {
                PostMediaView(
                    urls: post.proofUrls,
                    type: post.proofType,
                    aspectRatio: $imageAspectRatio
                )
                .onAppear {
                    if !hasAppeared {
                        hasAppeared = true
                        onView()
                    }
                }
            }

            // Interaction buttons
            PostActionsView(
                isLiked: post.isLikedByCurrentUser,
                likesCount: post.likesCount,
                commentsCount: post.commentsCount,
                viewsCount: post.viewsCount,
                onLike: onLike,
                onComment: onComment,
                onShare: onShare
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Description and metadata
            if let description = post.description, !description.isEmpty {
                PostDescriptionView(
                    description: description,
                    showFull: $showFullDescription
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Habit info if linked
            if let habitId = post.habitId {
                PostHabitInfoView(habitId: habitId)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            Divider()
                .padding(.top, 16)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Header Component

struct PostHeaderView: View {
    let user: UserBasic
    let timeAgo: String
    let privacy: PostPrivacy
    let onUserTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            Button(action: onUserTap) {
                AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                                .font(.title2)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Button(action: onUserTap) {
                        Text(user.displayName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Privacy indicator
                    HStack(spacing: 4) {
                        Image(systemName: privacy.icon)
                            .font(.caption2)
                        Text(privacy.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }

                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // More menu
            Menu {
                if user.id == getCurrentUserId() {
                    Button("Edit", systemImage: "pencil") {
                        // Handle edit
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        // Handle delete
                    }
                } else {
                    Button("Report", systemImage: "flag", role: .destructive) {
                        // Handle report
                    }
                    Button("Hide", systemImage: "eye.slash") {
                        // Handle hide
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
    }

    private func getCurrentUserId() -> Int {
        // TODO: Get from AuthService or UserDefaults
        return 1
    }
}

// MARK: - Media Component

struct PostMediaView: View {
    let urls: [String]
    let type: ProofType
    @Binding var aspectRatio: CGFloat

    @State private var currentIndex = 0

    var body: some View {
        GeometryReader { geometry in
            if urls.count == 1 {
                SingleMediaView(
                    url: urls[0],
                    type: type,
                    width: geometry.size.width,
                    aspectRatio: $aspectRatio
                )
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        SingleMediaView(
                            url: url,
                            type: type,
                            width: geometry.size.width,
                            aspectRatio: $aspectRatio
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
    }
}

struct SingleMediaView: View {
    let url: String
    let type: ProofType
    let width: CGFloat
    @Binding var aspectRatio: CGFloat

    var body: some View {
        switch type {
        case .image:
            KFImage(URL(string: url))
                .onSuccess { result in
                    let imageSize = result.image.size
                    aspectRatio = imageSize.width / imageSize.height
                }
                .placeholder {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                        )
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width)
                .clipped()

        case .video:
            ZStack {
                KFImage(URL(string: url + "_thumbnail"))
                    .placeholder {
                        Rectangle()
                            .fill(Color(.systemGray6))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width)
                    .clipped()

                Button(action: {
                    // Handle video playback
                }) {
                    Circle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                }
            }

        case .text:
            VStack {
                Text(url) // For text posts, URL contains the text content
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)

        case .audio:
            AudioPlayerView(url: url)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Actions Component

struct PostActionsView: View {
    let isLiked: Bool
    let likesCount: Int
    let commentsCount: Int
    let viewsCount: Int
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Like button
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .primary)
                        .font(.title3)
                        .scaleEffect(isLiked ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isLiked)

                    if likesCount > 0 {
                        Text("\(likesCount)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Comment button
            Button(action: onComment) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.title3)

                    if commentsCount > 0 {
                        Text("\(commentsCount)")
                            .font(.subheadline)
                    }
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())

            // Share button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Views count
            if viewsCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.caption)
                    Text("\(viewsCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Description Component

struct PostDescriptionView: View {
    let description: String
    @Binding var showFull: Bool

    private let characterLimit = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if description.count <= characterLimit || showFull {
                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(description.prefix(characterLimit) + "...")
                    .font(.body)
                + Text(" more")
                    .font(.body)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFull = true
                        }
                    }
            }

            if showFull && description.count > characterLimit {
                Text("show less")
                    .font(.body)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showFull = false
                        }
                    }
            }
        }
    }
}

// MARK: - Habit Info Component

struct PostHabitInfoView: View {
    let habitId: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
                .foregroundColor(.blue)
                .font(.caption)

            Text("Linked to habit")
                .font(.caption)
                .foregroundColor(.blue)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Audio Player Component

struct AudioPlayerView: View {
    let url: String
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 0
    @State private var currentTime: TimeInterval = 0

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                isPlaying.toggle()
                // Handle audio playback
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Audio Message")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: duration > 0 ? currentTime / duration : 0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension PostPrivacy {
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .friends: return "Friends"
        case .closeFriends: return "Close Friends"
        }
    }

    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .closeFriends: return "heart.fill"
        }
    }
}

extension UserBasic {
    var displayName: String {
        if !firstName.isEmpty && !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if !firstName.isEmpty {
            return firstName
        } else if !username.isEmpty {
            return username
        } else {
            return "User"
        }
    }
}

#Preview {
    let samplePost = Post(
        id: 1,
        userId: 1,
        habitId: 1,
        proofUrls: ["https://example.com/image.jpg"],
        proofType: .image,
        description: "Just finished my morning workout! Feeling great and ready to tackle the day. This was a challenging session but totally worth it.",
        privacy: .friends,
        createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
        updatedAt: nil,
        viewsCount: 15,
        likesCount: 5,
        commentsCount: 2,
        user: UserBasic(
            id: 1,
            username: "johndoe",
            firstName: "John",
            lastName: "Doe",
            profileImageUrl: nil
        ),
        isLikedByCurrentUser: false,
        isViewedByCurrentUser: false
    )

    PostCardView(
        post: samplePost,
        onLike: {},
        onComment: {},
        onView: {},
        onShare: {},
        onUserTap: {}
    )
    .padding()
    .previewLayout(.sizeThatFits)
}