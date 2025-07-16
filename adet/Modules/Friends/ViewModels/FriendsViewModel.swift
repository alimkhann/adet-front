import Foundation
import SwiftUI
import OSLog
import Combine
import FirebaseAnalytics

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var closeFriends: [UserBasic] = []
    @Published var searchResults: [UserBasic] = []
    @Published var searchText = ""
    @Published var searchQuery = ""
    @Published var selectedTab = 0
    @Published var isLoading = false
    @Published var isLoadingFriends = false
    @Published var isLoadingRequests = false
    @Published var isSearching = false
    @Published var isSearchActive = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var processingRequests: Set<Int> = []
    private var removingFriends: Set<Int> = []

    private let friendsService = FriendsAPIService.shared
    private let logger = Logger(subsystem: "com.adet.friends", category: "FriendsViewModel")

    // MARK: - Initialization

    init() {
        Task {
            await loadAllData()
        }
    }

    // MARK: - Load Methods

    func loadAllData() async {
        await loadFriends()
        await loadFriendRequests()
        await loadCloseFriends()
    }

    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }

        let response = await friendsService.getFriends()
        friends = response.friends
        AnalyticsHelper.logEvent("friends_loaded", parameters: ["count": friends.count])
    }

    func loadFriendRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            let response = try await friendsService.getFriendRequests()
            incomingRequests = response.incomingRequests
            outgoingRequests = response.outgoingRequests
            AnalyticsHelper.logEvent("friend_requests_loaded", parameters: ["incoming": incomingRequests.count, "outgoing": outgoingRequests.count])
        } catch {
            showErrorMessage("Failed to load friend requests: \(error.localizedDescription)")
            AnalyticsHelper.logError(error)
            AnalyticsHelper.logEvent("friend_requests_load_failed", parameters: ["error": error.localizedDescription])
        }
    }

    func loadCloseFriends() async {
        isLoading = true
        defer { isLoading = false }

        let response = await friendsService.getCloseFriends()
        closeFriends = response.closeFriends
        AnalyticsHelper.logEvent("close_friends_loaded", parameters: ["count": closeFriends.count])
    }

    // MARK: - Friend Actions

    func sendFriendRequest(to user: UserBasic) async {
        isLoading = true
        defer { isLoading = false }

        let success = await friendsService.sendFriendRequest(to: user.id)
        if success {
            showSuccessMessage("Friend request sent to \(user.displayName)")
            // Refresh friend requests to update UI
            await loadFriendRequests()
            AnalyticsHelper.logEvent("friend_request_sent", parameters: ["friend_id": user.id])
        } else {
            showErrorMessage("Could not send friend request. Please try again.")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "send_friend_request"])
            AnalyticsHelper.logError(NSError(domain: "FriendRequest", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not send friend request"]))
        }
    }

    func removeFriend(_ friend: Friend) async {
        removingFriends.insert(friend.friendId)
        defer { removingFriends.remove(friend.friendId) }

        let success = await friendsService.removeFriend(friendUserId: friend.user.id)
        if success {
            friends.removeAll { $0.id == friend.id }
            closeFriends.removeAll { $0.id == friend.user.id }
            showSuccessMessage("Removed \(friend.user.displayName) from friends")
            AnalyticsHelper.logEvent("friend_removed", parameters: ["friend_id": friend.user.id])
        } else {
            showErrorMessage("Failed to remove \(friend.user.displayName) from friends")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "remove_friend"])
            AnalyticsHelper.logError(NSError(domain: "FriendRemove", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to remove friend"]))
        }
    }

    func updateCloseFriend(_ friend: Friend, isClose: Bool) async {
        isLoading = true
        defer { isLoading = false }

        let success = await friendsService.updateCloseFriend(friendId: friend.friendId, isCloseFriend: isClose)
        if success {
            // Update local data
            if let index = friends.firstIndex(where: { $0.id == friend.id }) {
                friends[index].isCloseFriend = isClose
            }

            if isClose {
                if !closeFriends.contains(where: { $0.id == friend.user.id }) {
                    closeFriends.append(friend.user)
                }
                showSuccessMessage("Added \(friend.user.displayName) to close friends")
            } else {
                closeFriends.removeAll { $0.id == friend.user.id }
                showSuccessMessage("Removed \(friend.user.displayName) from close friends")
            }
            AnalyticsHelper.logEvent("close_friend_updated", parameters: ["friend_id": friend.user.id, "is_close": isClose])
        } else {
            showErrorMessage("Failed to update close friend status")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "update_close_friend"])
            AnalyticsHelper.logError(NSError(domain: "CloseFriend", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to update close friend status"]))
        }
    }

    // MARK: - Search Methods

    func setSearchActive(_ active: Bool) {
        isSearchActive = active
        if !active {
            clearSearch()
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearchActive = false
        isSearching = false
    }

    func searchUsers() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        let response = await friendsService.searchUsers(query: searchQuery)
        await MainActor.run {
            self.searchResults = response.users
            logger.info("Found \(response.count) users for query: \(self.searchQuery)")
            AnalyticsHelper.logEvent("friend_search", parameters: ["query": self.searchQuery, "count": response.count])
        }
    }

    // MARK: - Request Processing Methods

    func isProcessingRequest(_ requestId: Int) -> Bool {
        processingRequests.contains(requestId)
    }

    func isRemovingFriend(_ friendId: Int) -> Bool {
        removingFriends.contains(friendId)
    }

    func acceptFriendRequest(_ request: FriendRequest) async {
        processingRequests.insert(request.id)
        defer { processingRequests.remove(request.id) }

        let success = await friendsService.acceptFriendRequest(requestId: request.id)
        if success {
            incomingRequests.removeAll { $0.id == request.id }
            showSuccessMessage("Friend request accepted")
            // Refresh friends list to show the new friend
            await loadFriends()
            AnalyticsHelper.logEvent("friend_request_accepted", parameters: ["request_id": request.id])
        } else {
            showErrorMessage("Failed to accept friend request")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "accept_friend_request"])
            AnalyticsHelper.logError(NSError(domain: "FriendAccept", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to accept friend request"]))
        }
    }

    func declineFriendRequest(_ request: FriendRequest) async {
        processingRequests.insert(request.id)
        defer { processingRequests.remove(request.id) }

        let success = await friendsService.declineFriendRequest(requestId: request.id)
        if success {
            incomingRequests.removeAll { $0.id == request.id }
            showSuccessMessage("Friend request declined")
            AnalyticsHelper.logEvent("friend_request_declined", parameters: ["request_id": request.id])
        } else {
            showErrorMessage("Failed to decline friend request")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "decline_friend_request"])
            AnalyticsHelper.logError(NSError(domain: "FriendDecline", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decline friend request"]))
        }
    }

    func cancelFriendRequest(_ request: FriendRequest) async {
        processingRequests.insert(request.id)
        defer { processingRequests.remove(request.id) }

        let success = await friendsService.cancelFriendRequest(requestId: request.id)
        if success {
            outgoingRequests.removeAll { $0.id == request.id }
            showSuccessMessage("Friend request cancelled")
            AnalyticsHelper.logEvent("friend_request_cancelled", parameters: ["friend_id": request.id])
        } else {
            showErrorMessage("Failed to cancel friend request")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "cancel_friend_request"])
            AnalyticsHelper.logError(NSError(domain: "FriendCancel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to cancel friend request"]))
        }
    }

    // MARK: - Helper Methods

    private func showSuccessMessage(_ message: String) {
        ToastManager.shared.showSuccess(message)
        logger.info("Success: \(message)")
    }

    private func showErrorMessage(_ message: String) {
        ToastManager.shared.showError(message)
        errorMessage = message
        showError = true
        logger.error("Error: \(message)")
        AnalyticsHelper.logError(NSError(domain: "FriendsViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
    }

    // MARK: - Computed Properties

    var shouldShowSearchResults: Bool {
        return isSearchActive && !searchQuery.isEmpty
    }

    var hasSearchResults: Bool {
        return !searchResults.isEmpty
    }

    var friendsCount: Int {
        return friends.count
    }

    var incomingRequestsCount: Int {
        return incomingRequests.count
    }

    var hasAnyFriends: Bool {
        return !friends.isEmpty
    }

    var hasIncomingRequests: Bool {
        return !incomingRequests.isEmpty
    }

    var hasOutgoingRequests: Bool {
        return !outgoingRequests.isEmpty
    }

    var closeFriendsCount: Int {
        return closeFriends.count
    }

    var pendingRequestsCount: Int {
        return incomingRequests.count
    }

    // MARK: - Block and Report Actions

    func blockUser(userId: Int, reason: String?) async -> Bool {
        let success = await friendsService.blockUser(userId: userId, reason: reason)
        if success {
            showSuccessMessage("User blocked successfully")
            AnalyticsHelper.logEvent("friend_blocked", parameters: ["friend_id": userId])
        } else {
            showErrorMessage("Failed to block user")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "block_user"])
        }
        return success
    }

    func reportUser(userId: Int, category: String, description: String?) async -> Bool {
        let success = await friendsService.reportUser(userId: userId, category: category, description: description)
        if success {
            showSuccessMessage("User reported successfully")
            AnalyticsHelper.logEvent("friend_reported", parameters: ["friend_id": userId, "reason": category])
        } else {
            showErrorMessage("Failed to report user")
            AnalyticsHelper.logEvent("error_occurred", parameters: ["context": "report_user"])
        }
        return success
    }

    // Call this in FriendsView and FriendDetailView .onAppear for funneling
    func logScreenViewed(screen: String, friendId: Int? = nil) {
        var params: [String: Any] = ["screen": screen]
        if let friendId = friendId {
            params["friend_id"] = friendId
        }
        AnalyticsHelper.logEvent("screen_viewed", parameters: params)
    }

    // MARK: - Public Interface

    func refresh() async {
        await loadAllData()
    }
}
