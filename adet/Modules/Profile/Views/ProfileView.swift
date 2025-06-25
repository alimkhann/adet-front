import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showPfpActionSheet = false
    @State private var isPfpPressed = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Top bar: Username (left) and Settings (right)
                HStack {
                    Text(authViewModel.user?.username ?? "Username")
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
                        size: isPfpPressed ? 80 : 88,
                        isEditable: false,
                        onImageTap: nil,
                        onDeleteTap: nil,
                        jwtToken: authViewModel.jwtToken
                    )
                    .scaleEffect(isPfpPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPfpPressed)
                    .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 30, pressing: { pressing in
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
                            isPfpPressed = pressing
                        }
                    }, perform: {
                        showPfpActionSheet = true
                    })
                    .padding(.leading, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        // Name
                        Text((authViewModel.user?.name?.isEmpty == false ? authViewModel.user?.name : authViewModel.user?.username) ?? "Name")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.leading, 16)

                        // Stats
                        HStack(spacing: 24) {
                            ProfileStat(title: "Posts", value: "0")
                            ProfileStat(title: "Friends", value: "0")
                            ProfileStat(title: "Max Streak", value: "0")
                        }
                    }
                    .padding(.top, 8)
                    Spacer()
                }
                .padding(.top, 12)

                // Bio below pfp
                if let bio = authViewModel.user?.bio, !bio.isEmpty {
                    Text(bio)
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
            .actionSheet(isPresented: $showPfpActionSheet) {
                ActionSheet(title: Text("Profile Picture"), buttons: [
                    .default(Text("Choose from library")) { showPhotoLibrary = true },
                    .default(Text("Take photo")) { showCamera = true },
                    .destructive(Text("Remove current picture")) { Task { await authViewModel.deleteProfileImage() } },
                    .cancel()
                ])
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newValue in
                if let image = newValue {
                    Task {
                        await uploadSelectedImage(image)
                    }
                }
            }
        }
    }

    private func uploadSelectedImage(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = "profile_image_\(UUID().uuidString).jpg"
        await authViewModel.uploadProfileImage(imageData, fileName: fileName, mimeType: "image/jpeg")
        selectedImage = nil
    }
}

struct ProfileStat: View {
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
