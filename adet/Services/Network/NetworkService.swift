import Foundation
import Clerk
import OSLog

// MARK: - NetworkService Actor
actor NetworkService {
    static let shared = NetworkService()
    private let baseURL = URL(string: APIConfig.baseURL)!
    private let logger = Logger(subsystem: "com.adet.network", category: "NetworkService")

    // Configuration for retry logic
    private let maxRetries = 1
    private let retryDelay: TimeInterval = 1.0
    private let timeout: TimeInterval = 60.0

    private init() {}

    // MARK: - Core Network Request Function with Retry Logic
    func makeAuthenticatedRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U? = nil,
        headers: [String: String]? = nil,
        retryCount: Int = 0
    ) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            logger.error("Invalid URL for endpoint: \(endpoint)")
            throw NetworkError.invalidURL
        }

        // Try to get the token with retry logic for network issues
        var token: String?
        let maxTokenRetries = 2

        for tokenRetry in 0...maxTokenRetries {
            do {
                token = try await Clerk.shared.session?.getToken(.init(template: "adet-back"))?.jwt
                if token != nil {
                    break
                }
            } catch {
                logger.warning("Failed to get token on attempt \(tokenRetry + 1): \(error.localizedDescription)")
                if tokenRetry < maxTokenRetries {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    continue
                } else {
                    logger.error("Failed to get token after \(maxTokenRetries + 1) attempts")
                    throw NetworkError.unauthorized
                }
            }
        }

        guard let validToken = token else {
            logger.warning("User is not authenticated or token is unavailable.")
            throw NetworkError.unauthorized
        }
        logger.debug("Clerk JWT received for API request")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(validToken)", forHTTPHeaderField: "Authorization")

        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        logger.info("Making \(method) request to: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response received.")
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            logger.info("Received response with status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
                logger.error("Network request failed with status code \(httpResponse.statusCode). Body: \(errorBody)")

                // Retry on 5xx errors (server errors) but not on 4xx errors (client errors)
                if (500...599).contains(httpResponse.statusCode) && retryCount < maxRetries {
                    logger.info("Retrying request due to server error. Attempt \(retryCount + 1) of \(self.maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(retryCount + 1) * 1_000_000_000))
                    return try await makeAuthenticatedRequest(endpoint: endpoint, method: method, body: body, headers: headers, retryCount: retryCount + 1)
                }

                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorBody)
            }

            // Log the raw JSON string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Received raw JSON response: \(jsonString)")
            }

            // Handle empty responses (like 204 No Content)
            if data.isEmpty && T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            decoder.dateDecodingStrategy = .formatted(formatter)

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Failed to decode response: \(error.localizedDescription)")
                throw NetworkError.decodeError(error)
            }

        } catch let error as NetworkError {
            // Don't retry on network errors (like unauthorized, invalid URL, etc.)
            throw error
        } catch {
            // Handle specific network errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .networkConnectionLost:
                    throw NetworkError.connectionLost
                case .notConnectedToInternet:
                    throw NetworkError.noInternet
                case .timedOut:
                    throw NetworkError.timeout
                default:
                    break
                }
            }

            // Retry on network errors (timeout, connection lost, etc.)
            if retryCount < maxRetries {
                logger.info("Retrying request due to network error: \(error.localizedDescription). Attempt \(retryCount + 1) of \(self.maxRetries)")
                try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(retryCount + 1) * 1_000_000_000))
                return try await makeAuthenticatedRequest(endpoint: endpoint, method: method, body: body, headers: headers, retryCount: retryCount + 1)
            }
            throw NetworkError.unknown(error)
        }
    }

    // Overload for requests without a body
    func makeAuthenticatedRequest(
        endpoint: String,
        method: String,
        headers: [String: String]? = nil
    ) async throws {
        let _: EmptyResponse = try await makeAuthenticatedRequest(endpoint: endpoint, method: method, body: (nil as String?), headers: headers)
    }

    // MARK: - File Upload Method
    func uploadFile<T: Decodable>(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String
    ) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            logger.error("Invalid URL for endpoint: \(endpoint)")
            throw NetworkError.invalidURL
        }

        guard let token = try? await Clerk.shared.session?.getToken(.init(template: "adet-back"))?.jwt else {
            logger.warning("User is not authenticated or token is unavailable.")
            throw NetworkError.unauthorized
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        logger.info("Making file upload request to: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response received.")
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            logger.info("Received response with status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
                logger.error("File upload failed with status code \(httpResponse.statusCode). Body: \(errorBody)")
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorBody)
            }

            // Log the raw JSON string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Received raw JSON response: \(jsonString)")
            }

            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            decoder.dateDecodingStrategy = .formatted(formatter)

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Failed to decode response: \(error.localizedDescription)")
                throw NetworkError.decodeError(error)
            }

        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    // MARK: - Multipart Form Data Method
    func submitMultipartForm<T: Decodable>(
        endpoint: String,
        textFields: [String: String],
        fileData: Data? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        fileFieldName: String = "file"
    ) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            logger.error("Invalid URL for endpoint: \(endpoint)")
            throw NetworkError.invalidURL
        }

        guard let token = try? await Clerk.shared.session?.getToken(.init(template: "adet-back"))?.jwt else {
            logger.warning("User is not authenticated or token is unavailable.")
            throw NetworkError.unauthorized
        }

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build multipart body
        var body = Data()

        // Add text fields
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add file if provided
        if let fileData = fileData, let fileName = fileName, let mimeType = mimeType {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        logger.info("Making multipart form request to: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response received.")
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            logger.info("Received response with status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
                logger.error("Multipart form request failed with status code \(httpResponse.statusCode). Body: \(errorBody)")
                throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, body: errorBody)
            }

            // Log the raw JSON string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Received raw JSON response: \(jsonString)")
            }

            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            decoder.dateDecodingStrategy = .formatted(formatter)

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Failed to decode response: \(error.localizedDescription)")
                throw NetworkError.decodeError(error)
            }

        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    // MARK: - Profile Update
    func updateProfile(name: String?, username: String?, bio: String?) async throws -> User {
        let body = ProfileUpdateRequest(name: name, username: username, bio: bio)
        do {
            return try await makeAuthenticatedRequest(endpoint: "/api/v1/users/me/profile", method: "PATCH", body: body)
        } catch let NetworkError.requestFailed(statusCode, body) where statusCode == 409 {
            throw NetworkError.requestFailed(statusCode: 409, body: body)
        }
    }
}
