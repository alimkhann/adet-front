import SwiftUI
import OSLog

struct OtherUserProfileView: View {
    let userId: Int

    @StateObject private var viewModel = OtherProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showActionAlert = false
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var selectedTab: ProfileTab = .posts

    private let logger = Logger(subsystem: "com.adet.friends", category: "OtherUserProfileView")

    enum ProfileTab: String, CaseIterable {
        case posts = "Posts"
        case habits = "Habits"

        var systemImage: String {
            switch self {
            case .posts: return "square.grid.3x3"
            case .habits: return "target"
            }
        }
    }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.user != nil {
                        Menu {
                            Button(action: {
                                showBlockAlert = true
                            }) {
                                Label("Block User", systemImage: "hand.raised")
                            }

                            Button(action: {
                                showReportSheet = true
                            }) {
                                Label("Report User", systemImage: "flag")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportUserView(userId: userId)
            }
            .alert("Block User", isPresented: $showBlockAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Block", role: .destructive) {
                    Task {
                        await blockUser()
                    }
                }
            } message: {
                if let user = viewModel.user {
                    Text("Are you sure you want to block \(user.displayName)? They won't be able to find your profile or send you messages.")
                }
            }
            .onAppear {
                logger.info("OtherUserProfileView appeared for user \(userId)")
                Task {
                    await viewModel.loadUserProfile(userId: userId)
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == .habits && viewModel.userHabits.isEmpty {
                    Task {
                        await viewModel.loadUserHabits(userId: userId)
                    }
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

            Button {
                Task {
                    await viewModel.loadUserProfile(userId: userId)
                }
            } label: {
                Text("Retry")
                    .frame(minHeight: 48)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Profile Content

    private func profileContentView(for user: UserBasic) -> some View {
        ScrollView {
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
                            updatedAt: nil,
                            plan: "free"
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

                        // Stats - now including friends count
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

                // Action buttons
                actionButtonsView(for: user)

                // Tab Selector
                tabSelectorSection

                // Content based on selected tab
                contentSection
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Tab Selector Section
    private var tabSelectorSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 20)

            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 16, weight: .medium))
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedTab == tab ? .accentColor : .clear)
                                .animation(.easeInOut(duration: 0.2), value: selectedTab),
                            alignment: .bottom
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(.systemBackground))

            Divider()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            switch selectedTab {
            case .posts:
                postsContentView
            case .habits:
                habitsContentView
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Posts Content View
    private var postsContentView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("No posts yet")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("This user hasn't shared any posts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 40)
            .padding(.top, 60)
        }
    }

    // MARK: - Habits Content View
    private var habitsContentView: some View {
        VStack(spacing: 16) {
            if viewModel.isLoadingHabits {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading habits...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else if viewModel.userHabits.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("No habits yet")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("This user hasn't created any habits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 40)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.userHabits, id: \.id) { habit in
                        HabitCardView(
                            habit: habit,
                            isSelected: false,
                            onTap: { },
                            onLongPress: { },
                            minHeight: 100
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Action Buttons

    private func actionButtonsView(for user: UserBasic) -> some View {
        VStack(spacing: 8) {
            // Action buttons for friends: Remove Friend and Message
            if viewModel.friendshipStatus == .friends {
                HStack(spacing: 12) {
                    // Remove Friend button (left)
                    Button(action: {
                        showActionAlert = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.minus")
                                .font(.subheadline)

                            Text("Remove Friend")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    // Message button (right)
                    NavigationLink(destination: MessageConversationView(friendUser: user).environmentObject(authViewModel)) {
                        HStack(spacing: 8) {
                            Image(systemName: "message")
                                .font(.subheadline)

                            Text("Message")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else if viewModel.friendshipStatus == .requestReceived {
                // For received requests: Accept and Decline buttons
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.declineIncomingRequest()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isPerformingAction {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.subheadline)

                                Text("Decline")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(viewModel.isPerformingAction)

                    Button(action: {
                        Task {
                            await viewModel.acceptIncomingRequest()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isPerformingAction {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.subheadline)

                                Text("Accept")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isPerformingAction)
                }
            } else {
                // For other states: Single action button
                Button(action: {
                    Task {
                        await viewModel.performFriendAction()
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isPerformingAction {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: viewModel.actionButtonIcon)
                                .font(.subheadline)

                            Text(viewModel.actionButtonTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .frame(minHeight: 48)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isPerformingAction)
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

    // MARK: - Actions

    private func blockUser() async {
        guard let user = viewModel.user else { return }

        // TODO: Implement actual block functionality
        logger.info("Blocking user \(user.id)")

        // For now, just show a success message
        ToastManager.shared.showSuccess("Blocked \(user.displayName)")

        // Navigate back
        dismiss()
    }
}



#Preview {
    NavigationStack {
        OtherUserProfileView(userId: 123)
            .environmentObject(AuthViewModel())
    }
}
