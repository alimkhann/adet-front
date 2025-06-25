import SwiftUI
import OSLog

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProfileViewModel

    private let logger = Logger(subsystem: "com.adet.profile", category: "EditProfileView")

    init() {
        // Initialize with a temporary AuthViewModel, will be replaced by environment object
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(authViewModel: AuthViewModel()))
    }

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
                    Button(action: { viewModel.showEditImageActionSheet() }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                    }
                }
                .actionSheet(isPresented: $viewModel.showImageActionSheet) {
                    ActionSheet(title: Text("Edit Profile Picture"), buttons: [
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

                // Form Fields
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Name", text: $viewModel.editFormName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Username", text: $viewModel.editFormUsername)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.editFormBio)
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
                        if viewModel.isSavingProfile {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(minHeight: 36)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isSavingProfile || !viewModel.hasUnsavedChanges())
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Update the ViewModel with the current AuthViewModel
                viewModel.updateAuthViewModel(authViewModel)
                viewModel.loadEditFormData()
                logger.info("EditProfileView appeared")
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

    private func saveProfile() async {
        guard viewModel.validateEditForm() else { return }

        let success = await viewModel.saveProfile()
        if success {
            dismiss()
        }
    }
}
