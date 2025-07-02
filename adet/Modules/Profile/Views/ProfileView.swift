import SwiftUI
import OSLog

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var postsViewModel = PostsViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedTab: ProfileTab = .posts

    private let logger = Logger(subsystem: "com.adet.profile", category: "ProfileView")

    enum ProfileTab: String, CaseIterable {
        case posts = "Posts"
        case habits = "Habits"
        case analytics = "Analytics"

        var systemImage: String {
            switch self {
            case .posts: return "square.grid.3x3"
            case .habits: return "target"
            case .analytics: return "chart.bar"
            }
        }
    }

    init() {
        // Initialize with a temporary AuthViewModel, will be replaced by environment object
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(authViewModel: AuthViewModel()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Section
                    profileHeaderSection

                    // Tab Selector
                    tabSelectorSection

                    // Content based on selected tab
                    contentSection
                }
            }
            .background(Color(.systemBackground))
            .onAppear {
                // Update the ViewModel with the current AuthViewModel
                viewModel.updateAuthViewModel(authViewModel)
                loadUserPosts()
                Task {
                    await viewModel.loadFriendsCount()
                    await viewModel.loadUserHabits()
                }
                logger.info("ProfileView appeared")
            }
            .overlay(loadingOverlay)
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .actionSheet(isPresented: $viewModel.showPfpActionSheet) {
                ActionSheet(title: Text("Profile Picture"), buttons: [
                    .default(Text("Choose from library")) { viewModel.selectPhotoFromLibrary() },
                    .default(Text("Take photo")) { viewModel.takePhoto() },
                    .destructive(Text("Remove current picture")) {
                        Task { await viewModel.removeCurrentPicture() }
                    },
                    .cancel()
                ])
            }
            .sheet(isPresented: $viewModel.showPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $viewModel.selectedImage)
            }
            .sheet(isPresented: $viewModel.showCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $viewModel.selectedImage)
            }
            .onChange(of: viewModel.selectedImage) { _, newValue in
                if let image = newValue {
                    Task {
                        await viewModel.uploadSelectedImage(image)
                    }
                }
            }
        }
    }

    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top bar: Username (left) and Settings (right)
            HStack {
                Text(viewModel.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Profile row: pfp, name, stats
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let user = authViewModel.user {
                        ProfileImageView(
                            user: user,
                            size: viewModel.isPfpPressed ? 80 : 88,
                            isEditable: false,
                            onImageTap: nil,
                            onDeleteTap: nil,
                            jwtToken: authViewModel.jwtToken
                        )
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 88, height: 88)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 35))
                            )
                    }
                }
                .scaleEffect(viewModel.isPfpPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.7), value: viewModel.isPfpPressed)
                .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 30, pressing: { pressing in
                    viewModel.onPfpPressStateChanged(isPressing: pressing)
                }, perform: {
                    viewModel.onPfpLongPress()
                })

                VStack(alignment: .leading, spacing: 8) {
                    // Name
                    Text(viewModel.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Stats - Include posts count here to avoid duplication
                    HStack(spacing: 16) {
                        ForEach(viewModel.getProfileStats(), id: \.title) { stat in
                            ProfileStatView(title: stat.title, value: stat.value)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Bio below pfp
            if viewModel.hasBio {
                Text(viewModel.bio ?? "")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
            }

            // Buttons below bio
            HStack(spacing: 8) {
                NavigationLink(destination: EditProfileView().environmentObject(authViewModel)) {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minHeight: 36)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: {
                    shareProfile()
                }) {
                    Text("Share Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minHeight: 36)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
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
            case .analytics:
                analyticsContentView
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Posts Content View
    private var postsContentView: some View {
        VStack(spacing: 16) {
            if postsViewModel.isLoadingMyPosts {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading posts...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else if postsViewModel.myPosts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("No posts yet")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Share your habit progress to start building your story!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 40)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(postsViewModel.myPosts) { post in
                        PostCardView(
                            post: post,
                            onLike: {
                                Task {
                                    await postsViewModel.toggleLike(for: post)
                                }
                            },
                            onComment: {
                                // Navigate to comments
                            },
                            onView: {
                                Task {
                                    await postsViewModel.markPostAsViewed(post)
                                }
                            },
                            onShare: {
                                SharingHelper.shared.sharePost(post)
                            },
                            onUserTap: {
                                // User tapped their own profile - no action needed
                            }
                        )
                        .padding(.horizontal, 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
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

                        Text("Create your first habit to start your journey!")
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

    // MARK: - Analytics Content View
    private var analyticsContentView: some View {
        VStack(spacing: 16) {
            Text("Analytics view coming soon...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 40)
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }

    // MARK: - Helper Methods
    private func loadUserPosts() {
        Task {
            await postsViewModel.loadMyPosts(refresh: true)
        }
    }

    private func shareProfile() {
        let shareText = "Check out my progress on Adet! 🎯\n\nJoin me in building better habits with AI-powered tracking and motivation."

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            }
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Profile Stat View Component
struct ProfileStatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 64)
    }
}
