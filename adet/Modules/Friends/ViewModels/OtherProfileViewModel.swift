import Foundation
import SwiftUI
import OSLog

@MainActor
class OtherProfileViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.adet.friends", category: "OtherProfileViewModel")
    private let friendsAPI = FriendsAPIService.shared
    private let toastManager = ToastManager.shared

    // MARK: - Published Properties

    @Published var user: UserBasic?
    @Published var friendshipStatus: FriendshipStatus = .none
    @Published var isLoading = false
    @Published var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var userHabits: [Habit] = []
    @Published var isLoadingHabits = false
    @Published var friendsCount = 0

    // MARK: - Computed Properties

    var canAddFriend: Bool {
        friendshipStatus == .none && !isPerformingAction
    }

    var canRemoveFriend: Bool {
        friendshipStatus == .friends && !isPerformingAction
    }

    var canCancelRequest: Bool {
        friendshipStatus == .requestSent && !isPerformingAction
    }

    var canRespondToRequest: Bool {
        friendshipStatus == .requestReceived && !isPerformingAction
    }

    var actionButtonTitle: String {
        friendshipStatus.actionDisplayName
    }

    var actionButtonColor: Color {
        return .clear
    }

    var actionButtonIcon: String {
        friendshipStatus.icon
    }

    var statusDescription: String {
        switch friendshipStatus {
        case .none:
            return ""
        case .friends:
            return "You are friends"
        case .requestSent:
            return "Friend request sent"
        case .requestReceived:
            return "Wants to be friends"
        }
    }

    var displayName: String {
        guard let user = user else { return "Unknown User" }
        if let name = user.name, !name.isEmpty {
            return name
        } else if let username = user.username, !username.isEmpty {
            return username
        } else {
            return "Unknown User"
        }
    }

    // MARK: - Initialization

    init() {
        logger.info("OtherProfileViewModel initialized")
    }

    // MARK: - Data Loading

    func loadUserProfile(userId: Int) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load user profile and friendship status in parallel
            async let userProfile = friendsAPI.getUserProfile(userId: userId)
            async let friendshipStatusResponse = friendsAPI.getFriendshipStatus(userId: userId)

            let (profile, statusResponse) = try await (userProfile, friendshipStatusResponse)

            // Convert UserProfile to UserBasic - UserProfile and UserBasic now have the same structure
            user = UserBasic(
                id: profile.id,
                username: profile.username,
                name: profile.name,
                bio: profile.bio,
                profileImageUrl: profile.profileImageUrl
            )
            friendshipStatus = statusResponse

            logger.info("Loaded profile for user \(userId) with friendship status: \(self.friendshipStatus.rawValue)")

                        // Load additional data
            await loadUserFriendsCount(userId: userId)
            await loadUserHabits(userId: userId)

            // Debug: Also check if there are any pending requests
            if let outgoingRequest = await friendsAPI.getOutgoingRequestToUser(userId: userId) {
                logger.info("DEBUG: Found outgoing request ID \(outgoingRequest.id) but status shows \(self.friendshipStatus.rawValue)")
                // If we have a pending request but status shows none, fix the status
                if friendshipStatus == .none {
                    friendshipStatus = .requestSent
                    logger.info("DEBUG: Corrected friendship status to request_sent")
                }
            }
        } catch {
            logger.error("Failed to load user profile: \(error.localizedDescription)")
            handleError(error, message: "Failed to load user profile")
        }
    }

    func refreshFriendshipStatus() async {
        guard let user = user else { return }

        do {
            let response = try await friendsAPI.getFriendshipStatus(userId: user.id)
            friendshipStatus = response
            logger.info("Refreshed friendship status: \(self.friendshipStatus.rawValue)")
        } catch {
            logger.error("Failed to refresh friendship status: \(error.localizedDescription)")
        }
    }

    // MARK: - Friend Actions

    func performFriendAction() async {
        guard let user = user, !isPerformingAction else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        switch friendshipStatus {
        case .none:
            await sendFriendRequest(to: user)
        case .friends:
            await removeFriend(user)
        case .requestSent:
            await cancelFriendRequest(to: user)
        case .requestReceived:
            // For received requests, we'll handle this in the main friends view
            break
        }

        // Refresh status after action with a small delay to allow backend to update
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        await refreshFriendshipStatus()
    }

    private func sendFriendRequest(to user: UserBasic) async {
        let success = await friendsAPI.sendFriendRequest(to: user.id)
        if success {
            toastManager.showSuccess("Friend request sent to \(user.displayName)")
            friendshipStatus = .requestSent
            logger.info("Friend request sent successfully to \(user.displayName)")
        } else {
            // Even if the API call failed, check if a request actually exists
            // This handles cases where the backend has a constraint violation but the request exists
            logger.info("API call failed, checking if request already exists...")

            if let existingRequest = await friendsAPI.getOutgoingRequestToUser(userId: user.id) {
                logger.info("Found existing request \(existingRequest.id) despite API failure - updating UI")
                toastManager.showSuccess("Friend request sent to \(user.displayName)")
                friendshipStatus = .requestSent
            } else {
                // Also try refreshing the friendship status as a fallback
                await refreshFriendshipStatus()

                if friendshipStatus == .requestSent {
                    toastManager.showSuccess("Friend request sent to \(user.displayName)")
                    logger.info("Friend request confirmed via status refresh")
                } else {
                    toastManager.showError("Could not send friend request. Please try again.")
                    logger.error("Failed to send friend request to \(user.displayName)")
                }
            }
        }
    }

    private func removeFriend(_ user: UserBasic) async {
        let success = await friendsAPI.removeFriend(friendUserId: user.id)
        if success {
            toastManager.showSuccess("Removed \(user.displayName) from friends")
            friendshipStatus = .none
            logger.info("Removed friend: \(user.displayName)")
        } else {
            toastManager.showError("Failed to remove \(user.displayName) from friends")
        }
    }

    private func cancelFriendRequest(to user: UserBasic) async {
        // Get the outgoing request to this user and cancel it
        guard let request = await friendsAPI.getOutgoingRequestToUser(userId: user.id) else {
            toastManager.showError("Could not find friend request to cancel")
            return
        }

        let success = await friendsAPI.cancelFriendRequest(requestId: request.id)
        if success {
            toastManager.showSuccess("Friend request cancelled")
            friendshipStatus = .none
        } else {
            toastManager.showError("Failed to cancel friend request")
        }
        logger.info("Friend request cancelled for \(user.displayName)")
    }

    // MARK: - Incoming Request Actions

    func acceptIncomingRequest() async {
        guard let user = user, !isPerformingAction else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        // Get the incoming request from this user
        guard let request = await getIncomingRequestFromUser(userId: user.id) else {
            toastManager.showError("Could not find friend request to accept")
            return
        }

        let success = await friendsAPI.acceptFriendRequest(requestId: request.id)
        if success {
            toastManager.showSuccess("Friend request accepted! You are now friends with \(user.displayName)")
            friendshipStatus = .friends
            logger.info("Friend request accepted from \(user.displayName)")
        } else {
            toastManager.showError("Failed to accept friend request")
        }
    }

    func declineIncomingRequest() async {
        guard let user = user, !isPerformingAction else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        // Get the incoming request from this user
        guard let request = await getIncomingRequestFromUser(userId: user.id) else {
            toastManager.showError("Could not find friend request to decline")
            return
        }

        let success = await friendsAPI.declineFriendRequest(requestId: request.id)
        if success {
            toastManager.showSuccess("Friend request declined")
            friendshipStatus = .none
            logger.info("Friend request declined from \(user.displayName)")
        } else {
            toastManager.showError("Failed to decline friend request")
        }
    }

    private func getIncomingRequestFromUser(userId: Int) async -> FriendRequest? {
        do {
            let requests = try await friendsAPI.getFriendRequests()
            return requests.incomingRequests.first { $0.senderId == userId && $0.status == .pending }
        } catch {
            logger.error("Failed to get incoming requests: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private API Methods (Workaround)

    private func acceptFriendRequestAPI(requestId: Int) async -> Bool {
        do {
            guard let token = await AuthService.shared.getValidToken() else { return false }

            let url = URL(string: "http://localhost:8000/api/v1/friends/request/\(requestId)/accept")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to accept friend request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }

            logger.info("Successfully accepted friend request \(requestId)")
            return true
        } catch {
            logger.error("Failed to accept friend request: \(error.localizedDescription)")
            return false
        }
    }

    private func declineFriendRequestAPI(requestId: Int) async -> Bool {
        do {
            guard let token = await AuthService.shared.getValidToken() else { return false }

            let url = URL(string: "http://localhost:8000/api/v1/friends/request/\(requestId)/decline")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to decline friend request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }

            logger.info("Successfully declined friend request \(requestId)")
            return true
        } catch {
            logger.error("Failed to decline friend request: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Profile Stats

    func getProfileStats() -> [ProfileStat] {
        return [
            ProfileStat(title: "Posts", value: "0"),
            ProfileStat(title: "Friends", value: "\(friendsCount)"),
            ProfileStat(title: "Habits", value: "\(userHabits.count)")
        ]
    }

    func loadUserFriendsCount(userId: Int) async {
        let response = await friendsAPI.getUserFriendsCount(userId: userId)
        self.friendsCount = response
        logger.info("Loaded friends count: \(response)")
    }

    func loadUserHabits(userId: Int) async {
        isLoadingHabits = true
        defer { isLoadingHabits = false }

        let response = await friendsAPI.getUserHabits(userId: userId)
        self.userHabits = response
        logger.info("Loaded \(response.count) habits for user \(userId)")
    }

    // MARK: - Navigation Actions

    func navigateToFriendRequests() {
        // This will be handled by the parent view
        logger.info("Navigate to friend requests requested")
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, message: String) {
        errorMessage = message
        toastManager.showError(message)
    }

    func clearError() {
        errorMessage = nil
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        logger.error("\(message)")
    }

    private func showSuccessMessage(_ message: String) {
        logger.info("\(message)")
    }

    // MARK: - Private Helper Methods

}
