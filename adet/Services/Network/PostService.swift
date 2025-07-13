import Foundation

class PostService: ObservableObject {
    static let shared = PostService()

    private let baseURL = APIConfig.apiBaseURL
    private let session = URLSession.shared

    private init() {}

    // MARK: - Create Post

    func createPost(
        habitId: Int?,
        proofUrls: [String],
        proofType: ProofType,
        description: String,
        privacy: PostPrivacy
    ) async throws -> Post {
        let url = URL(string: "\(baseURL)/posts")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let requestBody = CreatePostRequest(
            habitId: habitId,
            proofUrls: proofUrls,
            proofType: proofType,
            description: description,
            privacy: privacy
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 201 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(Post.self, from: data)
    }

    // MARK: - Get Feed

    func getFeed(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        var components = URLComponents(string: "\(baseURL)/posts/feed")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode([Post].self, from: data)
    }

    // MARK: - Get Feed Posts (with pagination)

    func getFeedPosts(cursor: String? = nil, limit: Int = 20) async throws -> PostsResponse {
        var components = URLComponents(string: "\(baseURL)/posts/feed")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostsResponse.self, from: data)
    }

    // MARK: - Get My Posts

    // Custom ISO8601 formatter with microseconds
    private static let iso8601Fractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        return formatter
    }()

    func getMyPosts(cursor: String? = nil, limit: Int = 20) async throws -> PostsResponse {
        // Defensive: Ensure limit is always valid
        let safeLimit: Int
        if limit < 1 || limit > 50 {
            print("[PostService] Invalid limit value: \(limit). Defaulting to 20.")
            safeLimit = 20
        } else {
            safeLimit = limit
        }
        var components = URLComponents(string: "\(baseURL)/posts/me")!
        var queryItems = [URLQueryItem(name: "limit", value: String(safeLimit))]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw NetworkError.requestFailed(statusCode: 0, body: "No valid auth token")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "N/A"
            print("Failed to load my posts: Network request failed with status code: \(httpResponse.statusCode). Response: \(responseString)")
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            } else {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: responseString)
            }
        }

        let responseString = String(data: data, encoding: .utf8) ?? "N/A"
        print("PostsResponse: \(responseString)")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.iso8601Fractional)
        return try decoder.decode(PostsResponse.self, from: data)
    }

    // MARK: - Create Post (updated)

    func createPost(_ postData: PostCreate) async throws -> PostActionResponse {
        let url = URL(string: "\(baseURL)/posts")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(postData)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 201 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostActionResponse.self, from: data)
    }

    // MARK: - Toggle Post Like

    func togglePostLike(postId: Int) async throws -> LikeActionResponse {
        let url = URL(string: "\(baseURL)/posts/\(postId)/like")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(LikeActionResponse.self, from: data)
    }

    // MARK: - Mark Post as Viewed

    func markPostAsViewed(postId: Int) async throws {
        let url = URL(string: "\(baseURL)/posts/\(postId)/view")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        // Accept 200, 201, or 204 as success
        guard (200...204).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }
    }

    // MARK: - Update Post

    func updatePost(id: Int, updateData: PostUpdate) async throws -> PostActionResponse {
        let url = URL(string: "\(baseURL)/posts/\(id)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(updateData)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostActionResponse.self, from: data)
    }

    // MARK: - Update Post Privacy

    func updatePostPrivacy(postId: Int, privacy: PostPrivacy) async throws -> PostActionResponse {
        let url = URL(string: "\(baseURL)/posts/\(postId)/privacy")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let requestBody = ["privacy": privacy.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostActionResponse.self, from: data)
    }

    // MARK: - Get Post Analytics

    func getPostAnalytics(postId: Int) async throws -> PostAnalytics {
        let url = URL(string: "\(baseURL)/posts/\(postId)/analytics")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostAnalytics.self, from: data)
    }

    // MARK: - Get Post Comments (updated)

    func getPostComments(postId: Int, cursor: String? = nil, limit: Int = 20) async throws -> PostCommentsResponse {
        var components = URLComponents(string: "\(baseURL)/posts/\(postId)/comments")!
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostCommentsResponse.self, from: data)
    }

    // MARK: - Create Comment (updated)

    func createComment(_ commentData: PostCommentCreate) async throws -> CommentActionResponse {
        let url = URL(string: "\(baseURL)/posts/\(commentData.postId)/comments")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(commentData)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 201 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(CommentActionResponse.self, from: data)
    }

    // MARK: - Toggle Comment Like

    func toggleCommentLike(commentId: Int) async throws -> LikeActionResponse {
        let url = URL(string: "\(baseURL)/comments/\(commentId)/like")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(LikeActionResponse.self, from: data)
    }

    // MARK: - Get User Posts

    func getUserPosts(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        var components = URLComponents(string: "\(baseURL)/posts/user/\(userId)")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode([Post].self, from: data)
    }

    // MARK: - Like Post

    func likePost(postId: Int) async throws -> PostLike {
        let url = URL(string: "\(baseURL)/posts/\(postId)/like")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 201 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostLike.self, from: data)
    }

    // MARK: - Unlike Post

    func unlikePost(postId: Int) async throws {
        let url = URL(string: "\(baseURL)/posts/\(postId)/like")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 204 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }
    }

    // MARK: - Add Comment

    func addComment(postId: Int, content: String) async throws -> PostComment {
        let url = URL(string: "\(baseURL)/posts/\(postId)/comments")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let requestBody = CreateCommentRequest(content: content)
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 201 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode(PostComment.self, from: data)
    }

    // MARK: - Get Comments

    func getComments(postId: Int, limit: Int = 20, offset: Int = 0) async throws -> [PostComment] {
        var components = URLComponents(string: "\(baseURL)/posts/\(postId)/comments")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }

        return try JSONDecoder().decode([PostComment].self, from: data)
    }

    // MARK: - View Post

    func viewPost(postId: Int) async throws {
        let url = URL(string: "\(baseURL)/posts/\(postId)/view")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add authorization header
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }

        guard httpResponse.statusCode == 201 else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }
    }

    // MARK: - Fetch Single Post by ID
    func fetchPost(by id: Int) async throws -> Post {
        let url = URL(string: "\(baseURL)/posts/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = await AuthService.shared.getValidToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(statusCode: 0, body: "Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorData.detail)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: nil)
        }
        return try JSONDecoder().decode(Post.self, from: data)
    }
}

// MARK: - Request/Response Models

struct CreatePostRequest: Codable {
    let habitId: Int?
    let proofUrls: [String]
    let proofType: ProofType
    let description: String
    let privacy: PostPrivacy

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case proofUrls = "proof_urls"
        case proofType = "proof_type"
        case description
        case privacy
    }
}

struct CreateCommentRequest: Codable {
    let content: String
}
