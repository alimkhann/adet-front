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
    @State private var pushNotifications = true
    @State private var motivationalMessages = true
    @State private var reminderTime = Date()
    @AppStorage("appTheme") private var themeRawValue: String = Theme.system.rawValue
    private var theme: Theme {
        get { Theme(rawValue: themeRawValue) ?? .system }
        set { themeRawValue = newValue.rawValue }
    }
    @State private var haptics = true
    @AppStorage("appLanguage") private var language: String = "en"

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section(header: Text("account".t(language))) {
                    HStack(spacing: 16) {
                        if let user = authViewModel.user {
                            ProfileImageView(
                                user: user,
                                size: 48,
                                isEditable: false,
                                onImageTap: nil,
                                onDeleteTap: nil,
                                jwtToken: authViewModel.jwtToken
                            )
                        } else {
                            // Fallback when user is nil
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 20))
                                )
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authViewModel.user?.name ?? "Name")
                                .font(.headline)
                            Text("@" + (authViewModel.user?.username ?? "username"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(authViewModel.user?.email ?? "email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: EditProfileView().environmentObject(authViewModel)) {
                        Text("edit_profile".t(language))
                    }
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Text("sign_out".t(language))
                    }
                }

                // Notifications Section
                Section(header: Text("notifications".t(language))) {
                    Toggle("push_notifications".t(language), isOn: $pushNotifications)
                    Toggle("motivational_messages".t(language), isOn: $motivationalMessages)
                }

                // App Section
                Section(header: Text("app".t(language))) {
                    Picker("theme".t(language), selection: $themeRawValue) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    Toggle("haptics".t(language), isOn: $haptics)
                    Picker("language".t(language), selection: $language) {
                        Text("English").tag("en")
                        Text("Русский").tag("ru")
                        Text("Қазақша").tag("kk")
                        Text("简体中文").tag("zh-Hans")
                        Text("粤语").tag("yue")
                    }
                }

                // Support Section
                Section(header: Text("support".t(language))) {
                    NavigationLink(destination: FAQView()) {
                        Text("faq".t(language))
                    }
                    NavigationLink(destination: ContactSupportView()) {
                        Text("contact_support".t(language))
                    }
                    NavigationLink(destination: ReportBugView()) {
                        Text("report_bug".t(language))
                    }
                }

                // About Section
                Section(header: Text("about".t(language))) {
                    HStack {
                        Text("app_version".t(language))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("privacy_policy".t(language))
                    }
                    NavigationLink(destination: TermsOfServiceView()) {
                        Text("terms_of_service".t(language))
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Text("delete_account".t(language))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("settings_title".t(language))
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
            .confirmationDialog("select_profile_image".t(language), isPresented: $showingImagePicker) {
                Button("take_photo".t(language)) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showingCamera = true
                    }
                }
                Button("choose_from_library".t(language)) {
                    showingPhotoLibrary = true
                }
                Button("cancel".t(language), role: .cancel) {}
            } message: {
                Text("choose_how_add_profile_image".t(language))
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .alert("delete_profile_image".t(language), isPresented: $showingDeleteImageAlert) {
                Button("delete_account".t(language), role: .destructive) {
                    Task {
                        await authViewModel.deleteProfileImage()
                    }
                }
                Button("cancel".t(language), role: .cancel) {}
            } message: {
                Text("are_you_sure_delete_image".t(language))
            }
            .alert("sign_out".t(language), isPresented: $showSignOutAlert) {
                Button("sign_out".t(language), role: .destructive) {
                    Task { await authViewModel.signOut() }
                }
                Button("cancel".t(language), role: .cancel) {}
            } message: {
                Text("are_you_sure_sign_out".t(language))
            }
            .alert("delete_account".t(language), isPresented: $showDeleteAlert) {
                Button("delete_account".t(language), role: .destructive) {
                    Task { await authViewModel.deleteClerk() }
                }
                Button("cancel".t(language), role: .cancel) {}
            } message: {
                Text("are_you_sure_delete_account".t(language))
            }
        }
    }

    private func uploadSelectedImage(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let fileName = "profile_image_\(UUID().uuidString).jpg"
        await authViewModel.uploadProfileImage(imageData, fileName: fileName, mimeType: "image/jpeg")

        // Clear the selected image
        selectedImage = nil
    }
}
