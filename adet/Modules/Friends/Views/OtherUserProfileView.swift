import SwiftUI
import OSLog

struct OtherUserProfileView: View {
    let userId: Int

    @StateObject private var viewModel = OtherProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showActionAlert = false

    private let logger = Logger(subsystem: "com.adet.friends", category: "OtherUserProfileView")

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let user = viewModel.user {
                    profileContentView(for: user)
                } else {
                    errorView
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .onAppear {
                logger.info("OtherUserProfileView appeared for user \(userId)")
                Task {
                    await viewModel.loadUserProfile(userId: userId)
                }
            }
            .refreshable {
                await viewModel.loadUserProfile(userId: userId)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading profile...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Profile Not Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This user's profile could not be loaded.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await viewModel.loadUserProfile(userId: userId)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Profile Content

    private func profileContentView(for user: UserBasic) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar: Username
            HStack {
                Text(user.displayUsername)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.leading, 20)
                Spacer()
            }
            .padding(.top, 16)

            // Profile row: pfp, name, stats
            HStack(alignment: .top, spacing: 16) {
                ProfileImageView(
                    user: User(
                        id: user.id,
                        clerkId: "",
                        email: "",
                        name: user.displayName,
                        username: user.username,
                        bio: user.bio,
                        profileImageUrl: user.profileImageUrl,
                        isActive: true,
                        createdAt: Date(),
                        updatedAt: nil
                    ),
                    size: 88,
                    isEditable: false,
                    onImageTap: nil,
                    onDeleteTap: nil,
                    jwtToken: authViewModel.jwtToken
                )
                .padding(.leading, 20)

                VStack(alignment: .leading, spacing: 8) {
                    // Name
                    Text(user.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.leading, 16)

                    // Stats
                    HStack(spacing: 24) {
                        ForEach(viewModel.getProfileStats(), id: \.title) { stat in
                            ProfileStatView(title: stat.title, value: stat.value)
                        }
                    }
                }
                .padding(.top, 8)
                Spacer()
            }
            .padding(.top, 12)

            // Bio below pfp
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
            }

            // Friendship status
            if !viewModel.statusDescription.isEmpty {
                HStack {
                    Image(systemName: viewModel.actionButtonIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(viewModel.statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            // Action buttons
            actionButtonsView(for: user)

            Spacer()
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Action Buttons

    private func actionButtonsView(for user: UserBasic) -> some View {
        VStack(spacing: 8) {
            // Message button (only for friends)
            if viewModel.friendshipStatus == .friends {
                NavigationLink(destination: MessageConversationView(friendUser: user).environmentObject(authViewModel)) {
                    HStack(spacing: 8) {
                        Image(systemName: "message")
                            .font(.subheadline)

                        Text("Message")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(minHeight: 36)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
            }

            HStack(spacing: 8) {
                // Main action button
                Button(action: {
                    if viewModel.friendshipStatus == .friends {
                        showActionAlert = true
                    } else {
                        Task {
                            await viewModel.performFriendAction()
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isPerformingAction {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: viewModel.actionButtonIcon)
                                .font(.subheadline)

                            Text(viewModel.actionButtonTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(minHeight: 36)
                    .frame(maxWidth: .infinity)
                    .background(viewModel.actionButtonColor)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isPerformingAction)

                // Secondary action for requests received
                if viewModel.friendshipStatus == .requestReceived {
                    NavigationLink(destination: FriendsView().environmentObject(authViewModel)) {
                        Text("Respond")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .alert("Remove Friend", isPresented: $showActionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.performFriendAction()
                }
            }
        } message: {
            Text("Are you sure you want to remove \(user.displayName) from your friends list?")
        }
    }
}

//// MARK: - Profile Stat View
//
//private struct ProfileStatView: View {
//    let title: String
//    let value: String
//
//    var body: some View {
//        VStack(spacing: 2) {
//            Text(value)
//                .font(.subheadline)
//                .fontWeight(.semibold)
//                .foregroundColor(.primary)
//
//            Text(title)
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//    }
//}

#Preview {
    NavigationStack {
        OtherUserProfileView(userId: 123)
            .environmentObject(AuthViewModel())
    }
}
