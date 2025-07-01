import Foundation
import OSLog

class FriendsAPIService: ObservableObject {
    static let shared = FriendsAPIService()

    private let baseURL = "http://localhost:8000/api/v1"
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "com.adet.friends", category: "FriendsAPIService")

    private init() {}

    // MARK: - Get Friends

    func getFriends() async -> FriendsResponse {
        do {
            let url = URL(string: "\(baseURL)/friends")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FriendsAPIError.httpError
            }

            return try JSONDecoder().decode(FriendsResponse.self, from: data)
        } catch {
            logger.error("Failed to get friends: \(error.localizedDescription)")
            return FriendsResponse(friends: [], count: 0)
        }
    }

    // MARK: - Get Close Friends

    func getCloseFriends() async -> CloseFriendsResponse {
        do {
            let url = URL(string: "\(baseURL)/friends/close")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FriendsAPIError.httpError
            }

            return try JSONDecoder().decode(CloseFriendsResponse.self, from: data)
        } catch {
            logger.error("Failed to get close friends: \(error.localizedDescription)")
            return CloseFriendsResponse(closeFriends: [], count: 0)
        }
    }

    // MARK: - Update Close Friend

    func updateCloseFriend(friendId: Int, isCloseFriend: Bool) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/\(friendId)/close")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let requestBody = CloseFriendRequest(friendId: friendId, isCloseFriend: isCloseFriend)
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FriendsAPIError.httpError
            }

            return true
        } catch {
            logger.error("Failed to update close friend: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Send Friend Request

    func sendFriendRequest(to userId: Int) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/request")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let requestBody = ["requested_id": userId]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 201 else {
                throw FriendsAPIError.httpError
            }

            return true
        } catch {
            logger.error("Failed to send friend request: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Get Friend Requests

    func getFriendRequests() async throws -> FriendRequestsResponse {
        let url = URL(string: "\(baseURL)/friends/requests")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FriendsAPIError.httpError
        }

        return try JSONDecoder().decode(FriendRequestsResponse.self, from: data)
    }

    // MARK: - Get User Profile

    func getUserProfile(userId: Int) async throws -> UserProfile {
        let url = URL(string: "\(baseURL)/users/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FriendsAPIError.httpError
        }

        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    // MARK: - Get Friendship Status

    func getFriendshipStatus(userId: Int) async throws -> FriendshipStatus {
        let url = URL(string: "\(baseURL)/friends/status/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FriendsAPIError.httpError
        }

        let result = try JSONDecoder().decode([String: String].self, from: data)
        let statusString = result["status"] ?? "none"
        return FriendshipStatus(rawValue: statusString) ?? .none
    }
}

// MARK: - Response Models

struct FriendsResponse: Codable {
    let friends: [Friend]
    let count: Int
}

struct FriendRequestsResponse: Codable {
    let incomingRequests: [FriendRequest]
    let outgoingRequests: [FriendRequest]
    let incomingCount: Int
    let outgoingCount: Int

    enum CodingKeys: String, CodingKey {
        case incomingRequests = "incoming_requests"
        case outgoingRequests = "outgoing_requests"
        case incomingCount = "incoming_count"
        case outgoingCount = "outgoing_count"
    }
}

struct UserProfile: Codable {
    let id: Int
    let username: String
    let firstName: String
    let lastName: String
    let bio: String?
    let profileImageUrl: String?
    let isActive: Bool
    let friendsCount: Int
    let postsCount: Int

    enum CodingKeys: String, CodingKey {
        case id, username, bio, isActive
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImageUrl = "profile_image_url"
        case friendsCount = "friends_count"
        case postsCount = "posts_count"
    }
}

// MARK: - Error Types

enum FriendsAPIError: Error {
    case httpError
    case decodingError
    case networkError
}