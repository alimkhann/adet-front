import SwiftUI
import Clerk

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(Clerk.self) private var clerk
    @State private var isEditingUsername = false
    @State private var newUsername = ""
    @State private var showDeleteAlert = false
    @State private var showSignOutAlert = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingDeleteImageAlert = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false

    var body: some View {
        NavigationStack {
            List {
                if let user = authViewModel.user {
                    Section(header: Text("Account")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(user.email)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(user.username ?? "-")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.orange)
                            Text("Sign Out")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                    .disabled(authViewModel.isSigningOut)
                    .accessibilityIdentifier("SignOut")

                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            if authViewModel.isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(authViewModel.isDeletingAccount)
                    .accessibilityIdentifier("DeleteAccount")
                } header: {
                    Text("Actions")
                }

                Section {
                    Button {
                        Task {
                            await authViewModel.testNetworkConnectivity()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.primary)
                            Text("Test Network Connection")
                                .foregroundColor(.primary)
                            Spacer()
                            if authViewModel.isTestingNetwork {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(authViewModel.isTestingNetwork)

                    if let networkStatus = authViewModel.networkStatus {
                        HStack {
                            Image(systemName: networkStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(networkStatus ? .green : .red)
                            Text(networkStatus ? "Connection OK" : "Connection Failed")
                                .foregroundColor(networkStatus ? .green : .red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Network Diagnostics")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await authViewModel.fetchUser()
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                if let image = newValue {
                    Task {
                        await uploadSelectedImage(image)
                    }
                }
            }
            .confirmationDialog("Select Profile Image", isPresented: $showingImagePicker) {
                Button("Take Photo") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showingCamera = true
                    }
                }
                Button("Choose from Library") {
                    showingPhotoLibrary = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose how you'd like to add your profile image")
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .alert("Delete Profile Image", isPresented: $showingDeleteImageAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        await authViewModel.deleteProfileImage()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete your profile image?")
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authViewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task { await authViewModel.deleteClerk() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }

    private func uploadSelectedImage(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            authViewModel.clerkError = "Failed to process selected image"
            return
        }

        let fileName = "profile_image_\(UUID().uuidString).jpg"
        await authViewModel.uploadProfileImage(imageData, fileName: fileName, mimeType: "image/jpeg")

        // Clear the selected image
        selectedImage = nil
    }
}
