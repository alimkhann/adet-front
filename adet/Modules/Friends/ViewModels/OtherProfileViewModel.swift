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
        switch friendshipStatus {
        case .none:
            return "Add Friend"
        case .friends:
            return "Remove Friend"
        case .requestSent:
            return "Cancel Request"
        case .requestReceived:
            return "Respond to Request"
        }
    }

    var actionButtonColor: Color {
        switch friendshipStatus {
        case .none:
            return .accentColor
        case .friends:
            return .red
        case .requestSent:
            return .orange
        case .requestReceived:
            return .blue
        }
    }

    var actionButtonIcon: String {
        switch friendshipStatus {
        case .none:
            return "person.badge.plus"
        case .friends:
            return "person.badge.minus"
        case .requestSent:
            return "clock"
        case .requestReceived:
            return "person.crop.circle.badge.questionmark"
        }
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

            user = profile
            friendshipStatus = FriendshipStatus(rawValue: statusResponse.friendshipStatus) ?? .none

            logger.info("Loaded profile for user \(userId) with friendship status: \(self.friendshipStatus.rawValue)")
        } catch {
            logger.error("Failed to load user profile: \(error.localizedDescription)")
            handleError(error, message: "Failed to load user profile")
        }
    }

    func refreshFriendshipStatus() async {
        guard let user = user else { return }

        do {
            let response = try await friendsAPI.getFriendshipStatus(userId: user.id)
            friendshipStatus = FriendshipStatus(rawValue: response.friendshipStatus) ?? .none
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

        // Refresh status after action
        await refreshFriendshipStatus()
    }

    private func sendFriendRequest(to user: UserBasic) async {
        do {
            let response = try await friendsAPI.sendFriendRequest(to: user.id, message: nil)
            if response.success {
                toastManager.showSuccess("Friend request sent to \(user.displayName)")
                friendshipStatus = .requestSent
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Friend request sent to \(user.displayName)")
        } catch {
            logger.error("Failed to send friend request: \(error.localizedDescription)")
            handleError(error, message: "Failed to send friend request")
        }
    }

    private func removeFriend(_ user: UserBasic) async {
        do {
            let response = try await friendsAPI.removeFriend(friendId: user.id)
            if response.success {
                toastManager.showInfo("Removed \(user.displayName) from friends")
                friendshipStatus = .none
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Removed \(user.displayName) from friends")
        } catch {
            logger.error("Failed to remove friend: \(error.localizedDescription)")
            handleError(error, message: "Failed to remove friend")
        }
    }

    private func cancelFriendRequest(to user: UserBasic) async {
        // Note: We need the request ID to cancel, which we don't have here
        // In a real implementation, we might need to store request IDs or fetch them
        // For now, we'll show a message that it needs to be done from the requests tab
        toastManager.showInfo("Cancel requests from the Requests tab")
    }

    // MARK: - Profile Stats

    func getProfileStats() -> [ProfileStat] {
        // TODO: Implement actual stats fetching from backend
        // For now, return placeholder stats
        return [
            ProfileStat(title: "Posts", value: "0"),
            ProfileStat(title: "Friends", value: "0"),
            ProfileStat(title: "Streak", value: "0")
        ]
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
}
