import Foundation
import OSLog

@MainActor
class CloseFriendsViewModel: ObservableObject {
    @Published var closeFriends: [UserBasic] = []
    @Published var allFriends: [Friend] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let friendsAPI = FriendsAPIService.shared
    private let logger = Logger(subsystem: "com.adet.friends", category: "CloseFriendsViewModel")

    // MARK: - Public Methods

    func loadCloseFriends() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = await friendsAPI.getCloseFriends()
            closeFriends = response.closeFriends
            logger.info("Loaded \(closeFriends.count) close friends")
        } catch {
            logger.error("Failed to load close friends: \(error.localizedDescription)")
            errorMessage = "Failed to load close friends"
        }

        isLoading = false
    }

    func loadAllFriends() async {
        do {
            let response = await friendsAPI.getFriends()
            allFriends = response.friends
            logger.info("Loaded \(allFriends.count) total friends")
        } catch {
            logger.error("Failed to load friends: \(error.localizedDescription)")
            errorMessage = "Failed to load friends"
        }
    }

    func updateCloseFriend(_ friend: UserBasic, isCloseFriend: Bool) async {
        let originalCloseFriends = closeFriends

        // Optimistic update
        if isCloseFriend {
            if !closeFriends.contains(where: { $0.id == friend.id }) {
                closeFriends.append(friend)
            }
        } else {
            closeFriends.removeAll { $0.id == friend.id }
        }

        do {
            _ = await friendsAPI.updateCloseFriend(friendId: friend.id, isCloseFriend: isCloseFriend)

            let action = isCloseFriend ? "Added" : "Removed"
            logger.info("\(action) \(friend.displayName) \(isCloseFriend ? "to" : "from") close friends")

        } catch {
            // Revert optimistic update on error
            closeFriends = originalCloseFriends
            logger.error("Failed to update close friend status: \(error.localizedDescription)")
            errorMessage = "Failed to update close friend"
        }
    }

    func isCloseFriend(_ userId: Int) -> Bool {
        return closeFriends.contains { $0.id == userId }
    }

    func canAddMoreCloseFriends() -> Bool {
        return closeFriends.count < ContentLimits.maxCloseFriends
    }

    func getCloseFriendsCount() -> Int {
        return closeFriends.count
    }

    func getMaxCloseFriendsCount() -> Int {
        return ContentLimits.maxCloseFriends
    }

    // MARK: - Helper Methods

    func clearError() {
        errorMessage = nil
    }

    func refresh() async {
        await loadCloseFriends()
        await loadAllFriends()
    }
}