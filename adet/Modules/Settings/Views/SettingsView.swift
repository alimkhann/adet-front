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
    @State private var language = "English"

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section(header: Text("Account")) {
                    HStack(spacing: 16) {
                        ProfileImageView(
                            user: authViewModel.user,
                            size: 48,
                            isEditable: false,
                            onImageTap: nil,
                            onDeleteTap: nil,
                            jwtToken: authViewModel.jwtToken
                        )
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
                        Text("Edit Profile")
                    }
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                    }
                }

                // Notifications Section
                Section(header: Text("Notifications")) {
                    Toggle("Push Notifications", isOn: $pushNotifications)
                    Toggle("Motivational Messages", isOn: $motivationalMessages)
                }

                // App Section
                Section(header: Text("App")) {
                    Picker("Theme", selection: $themeRawValue) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    Toggle("Haptics", isOn: $haptics)
                    Picker("Language", selection: $language) {
                        Text("English").tag("English")
                        Text("Kazakh").tag("Kazakh")
                        Text("Русский").tag("Русский")
                        Text("Chinese (Simplified)").tag("Chinese (Simplified)")
                        Text("Cantonese").tag("Cantonese")
                    }
                }

                // Support Section
                Section(header: Text("Support")) {
                    NavigationLink(destination: FAQView()) {
                        Text("FAQ / Help Center")
                    }
                    NavigationLink(destination: ContactSupportView()) {
                        Text("Contact Support")
                    }
                    NavigationLink(destination: ReportBugView()) {
                        Text("Report a Bug")
                    }
                }

                // About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("Privacy Policy")
                    }
                    NavigationLink(destination: TermsOfServiceView()) {
                        Text("Terms of Service")
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Text("Delete Account")
                    }
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
            return
        }

        let fileName = "profile_image_\(UUID().uuidString).jpg"
        await authViewModel.uploadProfileImage(imageData, fileName: fileName, mimeType: "image/jpeg")

        // Clear the selected image
        selectedImage = nil
    }
}

enum Theme: String, CaseIterable {
    case system, light, dark
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
