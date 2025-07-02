import Foundation
import OSLog

@MainActor
class CloseFriendsViewModel: ObservableObject {
    @Published var closeFriends: [UserBasic] = []
    @Published var allFriends: [Friend] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingChanges: Set<Int> = [] // Track local changes

    private let friendsAPI = FriendsAPIService.shared
    private let logger = Logger(subsystem: "com.adet.friends", category: "CloseFriendsViewModel")
    private var originalCloseFriends: Set<Int> = [] // Track original state

    // MARK: - Public Methods

    func loadCloseFriends() async {
        isLoading = true
        errorMessage = nil

        let response = await friendsAPI.getCloseFriends()
        self.closeFriends = response.closeFriends
        self.originalCloseFriends = Set(response.closeFriends.map { $0.id })
        self.pendingChanges = Set(response.closeFriends.map { $0.id })
        logger.info("Loaded \(self.closeFriends.count) close friends")

        isLoading = false
    }

    func loadAllFriends() async {
        let response = await friendsAPI.getFriends()
        self.allFriends = response.friends
        logger.info("Loaded \(self.allFriends.count) total friends")
    }

    func updateCloseFriend(_ friend: UserBasic, isCloseFriend: Bool) {
        // Only update local state, don't save to backend yet
        if isCloseFriend {
            pendingChanges.insert(friend.id)
            if !self.closeFriends.contains(where: { $0.id == friend.id }) {
                self.closeFriends.append(friend)
            }
        } else {
            pendingChanges.remove(friend.id)
            self.closeFriends.removeAll { $0.id == friend.id }
        }

        logger.info("Local change: \(isCloseFriend ? "Added" : "Removed") \(friend.displayName) \(isCloseFriend ? "to" : "from") close friends (pending)")
    }

    func isCloseFriend(_ userId: Int) -> Bool {
        return pendingChanges.contains(userId)
    }

    func canAddMoreCloseFriends() -> Bool {
        return true // No limit anymore
    }

    func getCloseFriendsCount() -> Int {
        return pendingChanges.count
    }

    func getMaxCloseFriendsCount() -> Int {
        return ContentLimits.maxCloseFriends // For backward compatibility
    }

    // MARK: - Helper Methods

    func refresh() async {
        await loadCloseFriends()
        await loadAllFriends()
    }

    func clearError() {
        errorMessage = nil
    }

    func saveChanges() async {
        // Calculate what needs to be saved
        let currentCloseFriends = pendingChanges
        let toAdd = currentCloseFriends.subtracting(originalCloseFriends)
        let toRemove = originalCloseFriends.subtracting(currentCloseFriends)

        // Save additions
        for friendId in toAdd {
            let success = await friendsAPI.updateCloseFriend(friendId: friendId, isCloseFriend: true)
            if !success {
                logger.error("Failed to add friend \(friendId) to close friends")
            }
        }

        // Save removals
        for friendId in toRemove {
            let success = await friendsAPI.updateCloseFriend(friendId: friendId, isCloseFriend: false)
            if !success {
                logger.error("Failed to remove friend \(friendId) from close friends")
            }
        }

        // Update original state to match current state
        originalCloseFriends = currentCloseFriends
        logger.info("Saved close friends changes: +\(toAdd.count) -\(toRemove.count)")
    }
}