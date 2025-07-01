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
            let url = URL(string: "\(baseURL)/friends/")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to get friends - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
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
            let url = URL(string: "\(baseURL)/friends/close-friends")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to get close friends - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
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
            let url = URL(string: "\(baseURL)/friends/close-friends")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let requestBody = CloseFriendRequest(friendId: friendId, isCloseFriend: isCloseFriend)
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to update close friend - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                throw FriendsAPIError.httpError
            }

            return true
        } catch {
            logger.error("Failed to update close friend: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Search Users

    func searchUsers(query: String, limit: Int = 20) async -> UserSearchResponse {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return UserSearchResponse(users: [], count: 0, query: query)
        }

        do {
            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw FriendsAPIError.invalidInput
            }

            let url = URL(string: "\(baseURL)/friends/search?q=\(encodedQuery)&limit=\(limit)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to search users - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                throw FriendsAPIError.httpError
            }

            return try JSONDecoder().decode(UserSearchResponse.self, from: data)
        } catch {
            logger.error("Failed to search users: \(error.localizedDescription)")
            return UserSearchResponse(users: [], count: 0, query: query)
        }
    }

    // MARK: - Send Friend Request

    func sendFriendRequest(to userId: Int, message: String? = nil) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/request/\(userId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let requestBody = ["message": message ?? ""]
            request.httpBody = try JSONData(requestBody)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to send friend request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
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
            logger.error("Failed to get friend requests - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
            throw FriendsAPIError.httpError
        }

        return try JSONDecoder().decode(FriendRequestsResponse.self, from: data)
    }

    // MARK: - Get User Profile

    func getUserProfile(userId: Int) async throws -> UserProfile {
        let url = URL(string: "\(baseURL)/friends/user/\(userId)/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logger.error("Failed to get user profile - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
            throw FriendsAPIError.httpError
        }

        // Debug: Log the raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.info("User profile response: \(jsonString)")
        }

        do {
            let decoder = JSONDecoder()
            let userProfile = try decoder.decode(UserProfile.self, from: data)
            logger.info("Successfully decoded user profile for user ID: \(userProfile.id)")
            return userProfile
        } catch {
            logger.error("Failed to decode user profile: \(error)")
            logger.error("Decoding error details: \(error.localizedDescription)")
            throw FriendsAPIError.decodingError
        }
    }

    // MARK: - Get Friendship Status

    func getFriendshipStatus(userId: Int) async throws -> FriendshipStatus {
        let url = URL(string: "\(baseURL)/friends/user/\(userId)/friendship-status")!
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

        // Debug: Log the raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.info("Friendship status response: \(jsonString)")
        }

        do {
            let response = try JSONDecoder().decode(FriendshipStatusResponse.self, from: data)
            logger.info("Decoded friendship status: \(response.friendshipStatus)")
            return FriendshipStatus(rawValue: response.friendshipStatus) ?? .none
        } catch {
            logger.error("Failed to decode friendship status: \(error.localizedDescription)")
            throw FriendsAPIError.decodingError
        }
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
    let username: String?
    let name: String?
    let bio: String?
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case username = "username"
        case name = "name"
        case bio = "bio"
        case profileImageUrl = "profile_image_url"
    }
}

// MARK: - Error Types

enum FriendsAPIError: Error {
    case httpError
    case invalidInput
    case decodingError

    var localizedDescription: String {
        switch self {
        case .httpError:
            return "Network request failed"
        case .invalidInput:
            return "Invalid input provided"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - Helper Functions

private func JSONData<T: Encodable>(_ object: T) throws -> Data {
    return try JSONEncoder().encode(object)
}
