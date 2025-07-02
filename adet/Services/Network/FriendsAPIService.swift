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

            // Debug: Log the raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.info("Friends response: \(jsonString)")
            }

            do {
                let decoder = createJSONDecoder()
                let friendsResponse = try decoder.decode(FriendsResponse.self, from: data)
                logger.info("Successfully decoded \(friendsResponse.count) friends")
                return friendsResponse
            } catch let decodingError {
                logger.error("Failed to decode friends response: \(decodingError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    logger.error("Raw JSON that failed to decode: \(jsonString)")
                }

                // Try to decode each friend individually to find the problematic one
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let friendsArray = jsonObject["friends"] as? [[String: Any]] {
                    logger.info("Found \(friendsArray.count) friends in array, attempting individual decode...")

                    for (index, friendDict) in friendsArray.enumerated() {
                        do {
                            let friendData = try JSONSerialization.data(withJSONObject: friendDict)
                            let decoder = createJSONDecoder()
                            let _ = try decoder.decode(Friend.self, from: friendData)
                            logger.info("Friend \(index) decoded successfully")
                        } catch {
                            logger.error("Friend \(index) failed to decode: \(error)")
                            if let friendJSON = try? JSONSerialization.data(withJSONObject: friendDict),
                               let friendString = String(data: friendJSON, encoding: .utf8) {
                                logger.error("Problematic friend JSON: \(friendString)")
                            }
                        }
                    }
                }

                throw decodingError
            }
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
            return UserSearchResponse(users: [], count: 0, query: query)        }
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

            // Create request body with message and receiver_id to match backend schema
            let requestBody = [
                "message": message ?? "",
                "receiver_id": userId
            ] as [String : Any]
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Failed to send friend request - invalid response")
                throw FriendsAPIError.httpError
            }

            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode == 500 {
                                // Log the full error response for debugging
                if let errorData = String(data: data, encoding: .utf8) {
                    logger.error("HTTP 500 error response: \(errorData)")

                    // Check if it's a duplicate request error (could be from cancelled request)
                    if errorData.contains("duplicate key") ||
                       errorData.contains("already exists") ||
                       errorData.contains("UniqueViolationError") ||
                       errorData.contains("friend_requests_sender_id_receiver_id_key") {
                        logger.info("Duplicate key constraint for user \(userId) - likely cancelled request still in DB")
                        // Don't treat as success - this is a genuine error that needs backend cleanup
                        // But provide better error message
                        throw FriendsAPIError.duplicateRequest
                    }
                }

                logger.error("Server error when sending friend request - HTTP 500")
                throw FriendsAPIError.httpError
            } else {
                logger.error("Failed to send friend request - HTTP \(httpResponse.statusCode)")
                throw FriendsAPIError.httpError
            }
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

        // Debug: Log the raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.info("Friend requests response: \(jsonString)")
        }

        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            let response = try decoder.decode(FriendRequestsResponse.self, from: data)
            logger.info("Successfully decoded friend requests - incoming: \(response.incomingCount), outgoing: \(response.outgoingCount)")
            return response
        } catch {
            logger.error("Failed to decode friend requests: \(error)")
            throw FriendsAPIError.decodingError
        }
    }

    // MARK: - Cancel Friend Request

    func cancelFriendRequest(requestId: Int) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/request/\(requestId)/cancel")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to cancel friend request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }

            logger.info("Successfully cancelled friend request \(requestId)")
            return true
        } catch {
            logger.error("Failed to cancel friend request: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Accept Friend Request

    func acceptFriendRequest(requestId: Int) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/request/\(requestId)/accept")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to accept friend request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }

            logger.info("Successfully accepted friend request \(requestId)")
            return true
        } catch {
            logger.error("Failed to accept friend request: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Decline Friend Request

    func declineFriendRequest(requestId: Int) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/request/\(requestId)/decline")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to decline friend request - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }

            logger.info("Successfully declined friend request \(requestId)")
            return true
        } catch {
            logger.error("Failed to decline friend request: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Remove Friend

    func removeFriend(friendUserId: Int) async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/friends/\(friendUserId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to remove friend - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return false
            }

            logger.info("Successfully removed friend with user ID \(friendUserId)")
            return true
        } catch {
            logger.error("Failed to remove friend: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Get Outgoing Request to User

    func getOutgoingRequestToUser(userId: Int) async -> FriendRequest? {
        do {
            let requests = try await getFriendRequests()
            let outgoingRequest = requests.outgoingRequests.first { $0.receiverId == userId && $0.status == .pending }

            if let request = outgoingRequest {
                logger.info("Found existing outgoing request \(request.id) to user \(userId) with status: \(request.status.rawValue)")
            } else {
                logger.info("No pending outgoing request found to user \(userId). Total outgoing requests: \(requests.outgoingRequests.count)")
                for req in requests.outgoingRequests {
                    logger.info("Outgoing request \(req.id): sender=\(req.senderId), receiver=\(req.receiverId), status=\(req.status.rawValue)")
                }
            }

            return outgoingRequest
        } catch {
            logger.error("Failed to get outgoing request to user \(userId): \(error.localizedDescription)")
            return nil
        }
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

            let status = FriendshipStatus(rawValue: response.friendshipStatus) ?? .none
            logger.info("Converted to enum status: \(status.rawValue)")

            return status
        } catch {
            logger.error("Failed to decode friendship status: \(error.localizedDescription)")
            throw FriendsAPIError.decodingError
        }
    }

    // MARK: - Get User Habits

    func getUserHabits(userId: Int) async -> [Habit] {
        do {
            let url = URL(string: "\(baseURL)/friends/user/\(userId)/habits")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to get user habits - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return []
            }

            let decoder = JSONDecoder()
            let habitsList = try decoder.decode([Habit].self, from: data)
            logger.info("Successfully loaded \(habitsList.count) habits for user \(userId)")
            return habitsList
        } catch {
            logger.error("Failed to get user habits: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Get User Friends Count

    func getUserFriendsCount(userId: Int) async -> Int {
        do {
            let url = URL(string: "\(baseURL)/friends/user/\(userId)/friends-count")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            if let token = await AuthService.shared.getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.error("Failed to get user friends count - HTTP \(((response as? HTTPURLResponse)?.statusCode ?? 0))")
                return 0
            }

            let decoder = JSONDecoder()
            let countResponse = try decoder.decode([String: Int].self, from: data)
            let count = countResponse["count"] ?? 0
            logger.info("Successfully loaded friends count \(count) for user \(userId)")
            return count
        } catch {
            logger.error("Failed to get user friends count: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Helper Methods

    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        // Custom date formatter for backend format: "2025-07-01T21:38:18.663885Z"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        // Fallback formatter for ISO8601 without microseconds
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        fallbackFormatter.timeZone = TimeZone(abbreviation: "UTC")

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try primary format first (with microseconds)
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            // Try fallback format (without microseconds)
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 as last resort
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from: \(dateString)")
        }

        return decoder
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
    case duplicateRequest

    var localizedDescription: String {
        switch self {
        case .httpError:
            return "Network request failed"
        case .invalidInput:
            return "Invalid input provided"
        case .decodingError:
            return "Failed to decode response"
        case .duplicateRequest:
            return "A previous request still exists. Please try again in a moment."
        }
    }
}

// MARK: - Helper Functions

private func JSONData<T: Encodable>(_ object: T) throws -> Data {
    return try JSONEncoder().encode(object)
}
