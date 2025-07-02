import Foundation
import SwiftUI
import OSLog

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
    }

    func loadFriendRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            let response = try await friendsService.getFriendRequests()
            incomingRequests = response.incomingRequests
            outgoingRequests = response.outgoingRequests
        } catch {
            showErrorMessage("Failed to load friend requests: \(error.localizedDescription)")
        }
    }

    func loadCloseFriends() async {
        isLoading = true
        defer { isLoading = false }

        let response = await friendsService.getCloseFriends()
        closeFriends = response.closeFriends
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
        } else {
            showErrorMessage("Could not send friend request. Please try again.")
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
        } else {
            showErrorMessage("Failed to remove \(friend.user.displayName) from friends")
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
        } else {
            showErrorMessage("Failed to update close friend status")
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
        } else {
            showErrorMessage("Failed to accept friend request")
        }
    }

    func declineFriendRequest(_ request: FriendRequest) async {
        processingRequests.insert(request.id)
        defer { processingRequests.remove(request.id) }

        let success = await friendsService.declineFriendRequest(requestId: request.id)
        if success {
            incomingRequests.removeAll { $0.id == request.id }
            showSuccessMessage("Friend request declined")
        } else {
            showErrorMessage("Failed to decline friend request")
        }
    }

    func cancelFriendRequest(_ request: FriendRequest) async {
        processingRequests.insert(request.id)
        defer { processingRequests.remove(request.id) }

        let success = await friendsService.cancelFriendRequest(requestId: request.id)
        if success {
            outgoingRequests.removeAll { $0.id == request.id }
            showSuccessMessage("Friend request cancelled")
        } else {
            showErrorMessage("Failed to cancel friend request")
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

    // MARK: - Public Interface

    func refresh() async {
        await loadAllData()
    }
}

// MARK: - Combine Import
import Combine
