import SwiftUI
import OSLog

@MainActor
class ProfileViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.adet.profile", category: "ProfileViewModel")

    // MARK: - Published Properties
    @Published var isPfpPressed = false
    @Published var showPfpActionSheet = false
    @Published var showPhotoLibrary = false
    @Published var showCamera = false
    @Published var selectedImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Edit Profile Form State
    @Published var editFormUsername: String = ""
    @Published var editFormName: String = ""
    @Published var editFormBio: String = ""
    @Published var isSavingProfile = false
    @Published var showImageActionSheet = false

    // MARK: - Dependencies
    private var authViewModel: AuthViewModel

    // MARK: - Computed Properties
    var displayName: String {
        guard let user = authViewModel.user else { return "Name" }
        return (user.name?.isEmpty == false ? user.name : user.username) ?? "Name"
    }

    var username: String {
        authViewModel.user?.username ?? "Username"
    }

    var bio: String? {
        authViewModel.user?.bio
    }

    var hasBio: Bool {
        guard let bio = bio else { return false }
        return !bio.isEmpty
    }

    var profileImageUrl: String? {
        authViewModel.user?.profileImageUrl
    }

    // MARK: - Initialization
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        logger.info("ProfileViewModel initialized")
    }

    // MARK: - AuthViewModel Update
    func updateAuthViewModel(_ newAuthViewModel: AuthViewModel) {
        self.authViewModel = newAuthViewModel
        logger.info("ProfileViewModel updated with new AuthViewModel")
    }

    // MARK: - Profile Image Actions
    func onPfpLongPress() {
        logger.info("Profile image long press detected")
        showPfpActionSheet = true
    }

    func onPfpPressStateChanged(isPressing: Bool) {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) {
            isPfpPressed = isPressing
        }
    }

    func selectPhotoFromLibrary() {
        logger.info("User selected photo from library")
        showPhotoLibrary = true
    }

    func takePhoto() {
        logger.info("User selected to take photo")
        showCamera = true
    }

    func removeCurrentPicture() async {
        logger.info("User requested to remove current profile picture")
        isLoading = true
        defer { isLoading = false }

        await authViewModel.deleteProfileImage()
        logger.info("Profile picture removal operation completed")
    }

    // MARK: - Image Upload
    func uploadSelectedImage(_ image: UIImage) async {
        logger.info("Starting profile image upload")
        isLoading = true
        defer { isLoading = false }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to convert image to JPEG data")
            errorMessage = "Failed to process image"
            return
        }

        let fileName = "profile_image_\(UUID().uuidString).jpg"
        logger.info("Uploading profile image: \(fileName)")

        await authViewModel.uploadProfileImage(imageData, fileName: fileName, mimeType: "image/jpeg")
        logger.info("Profile image upload operation completed")
        selectedImage = nil
    }

    // MARK: - Profile Statistics
    func getProfileStats() -> [ProfileStat] {
        // TODO: Implement actual stats fetching from backend
        return [
            ProfileStat(title: "Posts", value: "0"),
            ProfileStat(title: "Friends", value: "0"),
            ProfileStat(title: "Max Streak", value: "0")
        ]
    }

    // MARK: - Navigation Actions
    func navigateToEditProfile() {
        logger.info("User navigated to edit profile")
    }

    func navigateToSettings() {
        logger.info("User navigated to settings")
    }

    func navigateToShareProfile() {
        logger.info("User navigated to share profile")
    }

    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Edit Profile Methods
    func loadEditFormData() {
        logger.info("Loading edit form data from current user")
        editFormUsername = authViewModel.user?.username ?? ""
        editFormName = authViewModel.user?.name ?? ""
        editFormBio = authViewModel.user?.bio ?? ""
    }

    func showEditImageActionSheet() {
        logger.info("User tapped edit image button")
        showImageActionSheet = true
    }

    func saveProfile() async -> Bool {
        guard !editFormUsername.isEmpty else {
            logger.warning("Attempted to save profile with empty username")
            errorMessage = "Username cannot be empty"
            return false
        }

        logger.info("Saving profile changes")
        isSavingProfile = true
        defer { isSavingProfile = false }

        // Call the AuthViewModel's updateProfile method
        await authViewModel.updateProfile(name: editFormName, username: editFormUsername, bio: editFormBio)

        // Check if there was an error (AuthViewModel handles errors via toast)
        // For now, assume success if we reach here
        logger.info("Profile save operation completed")
        return true
    }

    func validateEditForm() -> Bool {
        if editFormUsername.isEmpty {
            errorMessage = "Username cannot be empty"
            return false
        }

        if editFormUsername.count < 3 {
            errorMessage = "Username must be at least 3 characters"
            return false
        }

        if editFormBio.count > 200 {
            errorMessage = "Bio cannot exceed 200 characters"
            return false
        }

        return true
    }

    func hasUnsavedChanges() -> Bool {
        let currentUser = authViewModel.user
        return editFormUsername != (currentUser?.username ?? "") ||
               editFormName != (currentUser?.name ?? "") ||
               editFormBio != (currentUser?.bio ?? "")
    }
}

// MARK: - Profile Stat Model
struct ProfileStat {
    let title: String
    let value: String
}

