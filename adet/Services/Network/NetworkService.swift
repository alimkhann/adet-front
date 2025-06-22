import Foundation
import Clerk
import OSLog

// MARK: - NetworkService Actor
actor NetworkService {
    static let shared = NetworkService()
    private let baseURL = URL(string: "http://localhost:8000")!
    private let logger = Logger(subsystem: "com.adet.network", category: "NetworkService")

    // Configuration for retry logic
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    private let timeout: TimeInterval = 15.0

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

        guard let token = try? await Clerk.shared.session?.getToken(.init(template: "adet-back"))?.jwt else {
            logger.warning("User is not authenticated or token is unavailable.")
            throw NetworkError.unauthorized
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

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
}

// MARK: - Network Response Types
struct EmptyResponse: Codable {}