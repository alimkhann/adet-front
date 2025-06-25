import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newUsername: String = ""
    @State private var newName: String = ""
    @State private var newBio: String = ""
    @State private var showImagePicker = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showImageActionSheet = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)
                // Profile Image
                ZStack(alignment: .bottomTrailing) {
                    ProfileImageView(
                        user: authViewModel.user,
                        size: 100,
                        isEditable: false,
                        onImageTap: nil,
                        onDeleteTap: nil,
                        jwtToken: authViewModel.jwtToken
                    )
                    Button(action: { showImageActionSheet = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                    }
                }
                .actionSheet(isPresented: $showImageActionSheet) {
                    ActionSheet(title: Text("Edit Profile Picture"), buttons: [
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

                // Username field
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Username", text: $newUsername)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $newBio)
                            .frame(minHeight: 60, maxHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Save/Cancel buttons
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(minHeight: 36)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSaving)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                newUsername = authViewModel.user?.username ?? ""
                newName = authViewModel.user?.name ?? ""
                newBio = authViewModel.user?.bio ?? ""
            }
        }
    }

    private func uploadSelectedImage(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = "profile_image_\(UUID().uuidString).jpg"
        await authViewModel.uploadProfileImage(imageData, fileName: fileName, mimeType: "image/jpeg")
        selectedImage = nil
    }

    private func saveProfile() async {
        guard !newUsername.isEmpty else { return }
        isSaving = true
        await authViewModel.updateProfile(name: newName, username: newUsername, bio: newBio)
        isSaving = false
        dismiss()
    }
}
