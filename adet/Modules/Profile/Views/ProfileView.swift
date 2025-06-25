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
            VStack(spacing: 16) {
                // Avatar centered
                HStack {
                    Spacer()
                    ProfileImageView(
                        user: authViewModel.user,
                        size: isPfpPressed ? 90 : 100,
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
                    Spacer()
                }
                .padding(.top, 16)
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

                // Stats centered below avatar
                HStack(spacing: 32) {
                    ProfileStat(title: "Posts", value: "0")
                    ProfileStat(title: "Friends", value: "0")
                    ProfileStat(title: "Max Streak", value: "0")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Edit Profile & Share Profile buttons
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
                .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(authViewModel.user?.username ?? "Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
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

