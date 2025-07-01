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

        let response = await friendsAPI.getCloseFriends()
        self.closeFriends = response.closeFriends
        logger.info("Loaded \(self.closeFriends.count) close friends")

        isLoading = false
    }

    func loadAllFriends() async {
        let response = await friendsAPI.getFriends()
        self.allFriends = response.friends
        logger.info("Loaded \(self.allFriends.count) total friends")
    }

    func updateCloseFriend(_ friend: UserBasic, isCloseFriend: Bool) async {
        if isCloseFriend {
            if !self.closeFriends.contains(where: { $0.id == friend.id }) {
                self.closeFriends.append(friend)
            }
        } else {
            self.closeFriends.removeAll { $0.id == friend.id }
        }

        _ = await friendsAPI.updateCloseFriend(friendId: friend.id, isCloseFriend: isCloseFriend)
        let action = isCloseFriend ? "Added" : "Removed"
        logger.info("\(action) \(friend.displayName) \(isCloseFriend ? "to" : "from") close friends")
    }

    func isCloseFriend(_ userId: Int) -> Bool {
        return closeFriends.contains { $0.id == userId }
    }

    func canAddMoreCloseFriends() -> Bool {
        return true // No limit anymore
    }

    func getCloseFriendsCount() -> Int {
        return closeFriends.count
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
}