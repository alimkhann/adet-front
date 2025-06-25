import SwiftUI
import OSLog

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false

    private let logger = Logger(subsystem: "com.adet.profile", category: "ProfileView")

    init() {
        // Initialize with a temporary AuthViewModel, will be replaced by environment object
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(authViewModel: AuthViewModel()))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Top bar: Username (left) and Settings (right)
                HStack {
                    Text(viewModel.username)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.leading, 20)
                    Spacer()
                    NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.trailing, 20)
                    }
                }
                .padding(.top, 16)

                // Profile row: pfp, name, stats
                HStack(alignment: .top, spacing: 16) {
                    ProfileImageView(
                        user: authViewModel.user,
                        size: viewModel.isPfpPressed ? 80 : 88,
                        isEditable: false,
                        onImageTap: nil,
                        onDeleteTap: nil,
                        jwtToken: authViewModel.jwtToken
                    )
                    .scaleEffect(viewModel.isPfpPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.18, dampingFraction: 0.7), value: viewModel.isPfpPressed)
                    .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 30, pressing: { pressing in
                        viewModel.onPfpPressStateChanged(isPressing: pressing)
                    }, perform: {
                        viewModel.onPfpLongPress()
                    })
                    .padding(.leading, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        // Name
                        Text(viewModel.displayName)
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
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                        Text("Share Profile")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea(edges: .bottom)
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
            .onAppear {
                // Update the ViewModel with the current AuthViewModel
                viewModel.updateAuthViewModel(authViewModel)
                logger.info("ProfileView appeared")
            }
            .overlay(
                // Loading overlay
                Group {
                    if viewModel.isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            )
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
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
