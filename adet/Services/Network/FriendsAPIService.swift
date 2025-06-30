import Foundation
import OSLog

actor FriendsAPIService {
    static let shared = FriendsAPIService()
    private let networkService = NetworkService.shared
    private let logger = Logger(subsystem: "com.adet.api", category: "FriendsAPIService")

    private init() {}

    // MARK: - Friends List

    /// Get the current user's friends list
    func getFriends() async throws -> FriendsListResponse {
        logger.info("Fetching friends list")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/",
            method: "GET",
            body: (nil as String?)
        )
    }

    // MARK: - Friend Requests

    /// Get incoming and outgoing friend requests
    func getFriendRequests() async throws -> FriendRequestsResponse {
        logger.info("Fetching friend requests")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/requests",
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Send a friend request to another user
    func sendFriendRequest(to userId: Int, message: String? = nil) async throws -> FriendRequestActionResponse {
        logger.info("Sending friend request to user \(userId)")
        let requestBody = FriendRequestCreateRequest(receiverId: userId, message: message)
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/request/\(userId)",
            method: "POST",
            body: requestBody
        )
    }

    /// Accept a friend request
    func acceptFriendRequest(requestId: Int) async throws -> FriendRequestActionResponse {
        logger.info("Accepting friend request \(requestId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/request/\(requestId)/accept",
            method: "POST",
            body: (nil as String?)
        )
    }

    /// Decline a friend request
    func declineFriendRequest(requestId: Int) async throws -> FriendRequestActionResponse {
        logger.info("Declining friend request \(requestId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/request/\(requestId)/decline",
            method: "POST",
            body: (nil as String?)
        )
    }

    /// Cancel a friend request
    func cancelFriendRequest(requestId: Int) async throws -> FriendRequestActionResponse {
        logger.info("Cancelling friend request \(requestId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/request/\(requestId)/cancel",
            method: "POST",
            body: (nil as String?)
        )
    }

    // MARK: - Friend Management

    /// Remove a friend
    func removeFriend(friendId: Int) async throws -> FriendActionResponse {
        logger.info("Removing friend \(friendId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/\(friendId)",
            method: "DELETE",
            body: (nil as String?)
        )
    }

    // MARK: - User Search

    /// Search users by username
    func searchUsers(query: String, limit: Int = 20) async throws -> UserSearchResponse {
        logger.info("Searching users with query: '\(query)'")

        // URL encode the query parameter
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NetworkError.invalidURL
        }

        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/search?q=\(encodedQuery)&limit=\(limit)",
            method: "GET",
            body: (nil as String?)
        )
    }

    // MARK: - User Profile

    /// Get another user's public profile
    func getUserProfile(userId: Int) async throws -> UserBasic {
        logger.info("Fetching profile for user \(userId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/user/\(userId)/profile",
            method: "GET",
            body: (nil as String?)
        )
    }

    /// Get friendship status between current user and another user
    func getFriendshipStatus(userId: Int) async throws -> FriendshipStatusResponse {
        logger.info("Fetching friendship status for user \(userId)")
        return try await networkService.makeAuthenticatedRequest(
            endpoint: "/api/v1/friends/user/\(userId)/friendship-status",
            method: "GET",
            body: (nil as String?)
        )
    }
}