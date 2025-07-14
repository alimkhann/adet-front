import SwiftUI

struct CommentsSheetView: View {
    @StateObject var viewModel: CommentsViewModel
    let postId: Int
    let currentUser: UserBasic
    @Binding var isPresented: Bool

    @State private var newComment: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showActionSheet = false

    let onUserTap: (UserBasic) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(.gray.opacity(0.3))
                .padding(.top, 8)
            Text("Comments")
                .font(.headline)
                .padding(.vertical, 8)
            Divider()
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(
                                comment: comment,
                                currentUser: currentUser,
                                onLike: { Task { await viewModel.toggleLike(for: comment) } },
                                onDelete: { Task { await viewModel.deleteComment(commentId: comment.id) } },
                                onReport: { Task { await viewModel.reportComment(commentId: comment.id, reason: "inappropriate") } },
                                onUserTap: { _ in onUserTap(comment.user) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Divider()
            HStack {
                UserBasicAvatarView(user: currentUser)
                    .frame(width: 32, height: 32)
                TextField("Add a comment...", text: $newComment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                Button("Send") {
                    Task {
                        let success = await viewModel.createComment(postId: postId, content: newComment)
                        if success {
                            newComment = ""
                            isInputFocused = false
                        }
                    }
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
            }
            .padding()
            .padding(.bottom, 32)
        }
        .onAppear {
            print("CommentsSheetView appeared for postId: \(postId)")
            Task { await viewModel.loadComments(for: postId, refresh: true) }
        }
        .background(.background)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: PostComment
    let currentUser: UserBasic
    let onLike: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onUserTap: (UserBasic) -> Void
    @State private var showActionSheet = false

    private var timeAgoString: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: comment.createdAt) {
            return shortRelativeTimeString(from: date)
        } else {
            return "--"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: { onUserTap(comment.user) }) {
                UserBasicAvatarView(user: comment.user)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Button(action: { onUserTap(comment.user) }) {
                        Text(comment.user.displayUsername)
                            .font(.subheadline).bold()
                    }
                    .buttonStyle(.plain)
                    Text(timeAgoString)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(comment.content)
                    .font(.body)
            }
            Spacer()
            // Like button at far right
            Button(action: onLike) {
                HStack(spacing: 4) {
                    Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                    if comment.likesCount > 0 {
                        Text("\(comment.likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onLongPressGesture {
            showActionSheet = true
        }
        .confirmationDialog("Actions", isPresented: $showActionSheet, titleVisibility: .visible) {
            if comment.user.id == currentUser.id {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } else {
                Button("Report", role: .destructive) {
                    onReport()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - UserBasicAvatarView

struct UserBasicAvatarView: View {
    let user: UserBasic

    var body: some View {
        if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color(.systemGray5))
                    .overlay(Image(systemName: "person.fill").foregroundColor(.secondary))
            }
            .clipShape(Circle())
        } else {
            Circle().fill(Color(.systemGray5))
                .overlay(Image(systemName: "person.fill").foregroundColor(.secondary))
        }
    }
}

private func shortRelativeTimeString(from date: Date) -> String {
    let now = Date()
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 { return "\(seconds)s ago" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h ago" }
    let days = hours / 24
    return "\(days)d ago"
}
