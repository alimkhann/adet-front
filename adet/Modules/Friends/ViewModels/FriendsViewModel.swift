import SwiftUI
import OSLog

@MainActor
class FriendsViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.adet.friends", category: "FriendsViewModel")
    private let friendsAPI = FriendsAPIService.shared
    private let toastManager = ToastManager.shared

    // MARK: - Published Properties

    // Friends List
    @Published var friends: [Friend] = []
    @Published var isLoadingFriends = false

    // Friend Requests
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var isLoadingRequests = false

    // Search
    @Published var searchQuery = ""
    @Published var searchResults: [UserBasic] = []
    @Published var isSearching = false
    @Published var isSearchActive = false

    // UI State
    @Published var selectedTab = 0 // 0: Friends, 1: Requests
    @Published var errorMessage: String?

    // Loading states for individual actions
    @Published var processingRequestIds: Set<Int> = []
    @Published var removingFriendIds: Set<Int> = []

    // MARK: - Computed Properties

    var friendsCount: Int {
        friends.count
    }

    var incomingRequestsCount: Int {
        incomingRequests.count
    }

    var outgoingRequestsCount: Int {
        outgoingRequests.count
    }

    var hasAnyFriends: Bool {
        !friends.isEmpty
    }

    var hasIncomingRequests: Bool {
        !incomingRequests.isEmpty
    }

    var hasOutgoingRequests: Bool {
        !outgoingRequests.isEmpty
    }

    var hasSearchResults: Bool {
        !searchResults.isEmpty && !searchQuery.isEmpty
    }

    var shouldShowSearchResults: Bool {
        isSearchActive && !searchQuery.isEmpty
    }

    // MARK: - Initialization

    init() {
        logger.info("FriendsViewModel initialized")
        setupSearchDebouncing()
    }

    // MARK: - Search Setup

    private func setupSearchDebouncing() {
        // Debounce search to avoid too many API calls
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performSearchIfNeeded()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Data Loading

    func loadFriends() async {
        guard !isLoadingFriends else { return }

        isLoadingFriends = true
        defer { isLoadingFriends = false }

        do {
            let response = try await friendsAPI.getFriends()
            friends = response.friends
            logger.info("Loaded \(response.count) friends")
        } catch {
            logger.error("Failed to load friends: \(error.localizedDescription)")
            handleError(error, message: "Failed to load friends")
        }
    }

    func loadFriendRequests() async {
        guard !isLoadingRequests else { return }

        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            let response = try await friendsAPI.getFriendRequests()
            incomingRequests = response.incomingRequests
            outgoingRequests = response.outgoingRequests
            logger.info("Loaded \(response.incomingCount) incoming and \(response.outgoingCount) outgoing requests")
        } catch {
            logger.error("Failed to load friend requests: \(error.localizedDescription)")
            handleError(error, message: "Failed to load friend requests")
        }
    }

    func loadAllData() async {
        await loadFriends()
        await loadFriendRequests()
    }

    // MARK: - Search

    func setSearchActive(_ active: Bool) {
        isSearchActive = active
        if !active {
            searchQuery = ""
            searchResults = []
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearchActive = false
    }

    private func performSearchIfNeeded() {
        Task {
            await performSearch()
        }
    }

    func performSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty && query.count >= 2 else {
            searchResults = []
            return
        }

        guard !isSearching else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            let response = try await friendsAPI.searchUsers(query: query)
            searchResults = response.users
            logger.info("Found \(response.count) users for query '\(query)'")
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            searchResults = []
            handleError(error, message: "Search failed")
        }
    }

    // MARK: - Friend Request Actions

    func sendFriendRequest(to user: UserBasic, message: String? = nil) async {
        do {
            let response = try await friendsAPI.sendFriendRequest(to: user.id, message: message)
            if response.success {
                toastManager.showSuccess("Friend request sent to \(user.displayName)")
                // Reload requests to update the UI
                await loadFriendRequests()
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Friend request sent to \(user.displayName)")
        } catch {
            logger.error("Failed to send friend request: \(error.localizedDescription)")
            handleError(error, message: "Failed to send friend request")
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) async {
        guard !processingRequestIds.contains(request.id) else { return }

        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }

        do {
            let response = try await friendsAPI.acceptFriendRequest(requestId: request.id)
            if response.success {
                toastManager.showSuccess("You are now friends with \(request.sender.displayName)")
                // Reload both friends and requests
                await loadAllData()
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Accepted friend request from \(request.sender.displayName)")
        } catch {
            logger.error("Failed to accept friend request: \(error.localizedDescription)")
            handleError(error, message: "Failed to accept friend request")
        }
    }

    func declineFriendRequest(_ request: FriendRequest) async {
        guard !processingRequestIds.contains(request.id) else { return }

        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }

        do {
            let response = try await friendsAPI.declineFriendRequest(requestId: request.id)
            if response.success {
                toastManager.showInfo("Friend request declined")
                await loadFriendRequests()
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Declined friend request from \(request.sender.displayName)")
        } catch {
            logger.error("Failed to decline friend request: \(error.localizedDescription)")
            handleError(error, message: "Failed to decline friend request")
        }
    }

    func cancelFriendRequest(_ request: FriendRequest) async {
        guard !processingRequestIds.contains(request.id) else { return }

        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }

        do {
            let response = try await friendsAPI.cancelFriendRequest(requestId: request.id)
            if response.success {
                toastManager.showInfo("Friend request cancelled")
                await loadFriendRequests()
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Cancelled friend request to \(request.receiver.displayName)")
        } catch {
            logger.error("Failed to cancel friend request: \(error.localizedDescription)")
            handleError(error, message: "Failed to cancel friend request")
        }
    }

    // MARK: - Friend Management

    func removeFriend(_ friend: Friend) async {
        guard !removingFriendIds.contains(friend.friendId) else { return }

        removingFriendIds.insert(friend.friendId)
        defer { removingFriendIds.remove(friend.friendId) }

        do {
            let response = try await friendsAPI.removeFriend(friendId: friend.friendId)
            if response.success {
                toastManager.showInfo("Removed \(friend.friend.displayName) from friends")
                await loadFriends()
            } else {
                toastManager.showError(response.message)
            }
            logger.info("Removed \(friend.friend.displayName) from friends")
        } catch {
            logger.error("Failed to remove friend: \(error.localizedDescription)")
            handleError(error, message: "Failed to remove friend")
        }
    }

    // MARK: - Helper Methods

    func getFriendshipStatus(for user: UserBasic) async -> FriendshipStatus {
        do {
            let response = try await friendsAPI.getFriendshipStatus(userId: user.id)
            return FriendshipStatus(rawValue: response.friendshipStatus) ?? .none
        } catch {
            logger.error("Failed to get friendship status: \(error.localizedDescription)")
            return .none
        }
    }

    func isProcessingRequest(_ requestId: Int) -> Bool {
        processingRequestIds.contains(requestId)
    }

    func isRemovingFriend(_ friendId: Int) -> Bool {
        removingFriendIds.contains(friendId)
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

// MARK: - Combine Import
import Combine