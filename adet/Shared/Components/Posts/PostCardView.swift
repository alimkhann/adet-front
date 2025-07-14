import SwiftUI
import Kingfisher

struct PostCardView: View {
    let post: Post
    let onLike: () -> Void
    let onComment: () -> Void
    let onView: () -> Void
    let onShare: () -> Void
    let onUserTap: () -> Void

    @EnvironmentObject var profileViewModel: ProfileViewModel
    @State private var imageAspectRatio: CGFloat = 1.0
    @State private var showFullDescription = false
    // REMOVED: @State private var hasAppeared = false

    private var isCurrentUserPost: Bool {
        guard let currentUserId = profileViewModel.authViewModel.user?.id else { return false }
        return post.user.id == currentUserId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info and menu
            HStack(alignment: .top) {
                PostHeaderView(
                    user: post.user,
                    timeAgo: post.timeAgo,
                    privacy: post.privacy,
                    onUserTap: onUserTap
                )
                Spacer()
                // Menu logic: only show for your own private posts (Edit) or others' posts (Report)
                if isCurrentUserPost && post.privacy == .private {
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            // Handle edit
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                } else if !isCurrentUserPost {
                    Menu {
                        Button("Report", systemImage: "flag", role: .destructive) {
                            // Handle report
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Media or text proof content
            switch post.proofType {
            case .text:
                OutlinedBox {
                    Text(post.proofContent ?? "")
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            case .image:
                if let urlStr = post.proofUrls.first,
                   let url = URL(string: urlStr) {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
            default:
                EmptyView()
            }

            // Interaction buttons
            PostActionsView(
                post: post,
                isLiked: post.isLikedByCurrentUser,
                likesCount: post.likesCount,
                commentsCount: post.commentsCount,
                viewsCount: post.viewsCount,
                onLike: onLike,
                onComment: onComment,
                onShare: {
                    onShare()
                    SharingHelper.shared.sharePost(post)
                }
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
                PostHabitInfoView(habitId: habitId, streak: post.habitStreak)
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
        }
    }
}

// MARK: - Content Component for Text/Audio Posts

struct PostContentView: View {
    let post: Post

    var body: some View {
        switch post.proofType {
        case .text:
            TextProofView(content: post.proofUrls.first ?? "")
        case .audio:
            AudioProofView(audioUrl: post.proofUrls.first ?? "")
        default:
            EmptyView()
        }
    }
}

struct TextProofView: View {
    let content: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "quote.opening")
                    .foregroundColor(.blue)
                    .font(.title3)
                Spacer()
                Image(systemName: "text.alignleft")
                    .foregroundColor(.blue)
                    .font(.caption)
            }

            Text(content)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)

            HStack {
                Spacer()
                Image(systemName: "quote.closing")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.05), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AudioProofView: View {
    let audioUrl: String
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 45 // Mock duration
    @State private var currentTime: TimeInterval = 0

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                isPlaying.toggle()
                // Handle audio playback
            }) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Audio Proof")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Waveform visualization (simplified)
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(index < Int(currentTime / duration * 20) ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat.random(in: 8...24))
                    }
                }
                .frame(height: 24)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
                    print("Kingfisher loaded image:", imageSize)
                }
                .onFailure { error in
                    print("Kingfisher failed to load image:", error)
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
    let post: Post
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
                (Text(description.prefix(characterLimit) + "...")
                    .font(.body)
                + Text(" more")
                    .font(.body)
                    .foregroundColor(.blue))
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
    let streak: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .foregroundColor(.blue)
                .font(.callout)

            VStack(alignment: .leading, spacing: 2) {
                Text("Linked to habit")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)

                if let streak = streak, streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(streak) day streak")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                }
            }

            Spacer()

            // Streak celebration for milestones
            if let streak = streak, [7, 30, 100].contains(streak) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Milestone!")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.blue.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
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
