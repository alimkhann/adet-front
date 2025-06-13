import Foundation
import OSLog

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodeError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .requestFailed(let statusCode):
            return "API request failed with status code: \(statusCode)."
        case .decodeError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

class APIManager {
    static let shared = APIManager()
    private let baseURL = URL(string: "http://localhost:8000")!  // adjust if needed
    private let logger = Logger(subsystem: "com.adet.api", category: "APIManager")

    private init() {}

    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Requests WITH a body
    func request<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            logger.error("Invalid URL for endpoint: \(endpoint)")
            throw APIError.invalidURL
        }
        logger.info("Making \(method) request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        if let headers = headers {
            for (k, v) in headers {
                request.setValue(v, forHTTPHeaderField: k)
            }
        }

        if let body = body {
            if let contentType = request.value(forHTTPHeaderField: "Content-Type"), contentType == "application/x-www-form-urlencoded", let stringBody = body as? String {
                request.httpBody = stringBody.data(using: .utf8)
            } else {
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                do {
                    request.httpBody = try JSONEncoder().encode(body)
                } catch {
                    let ns = error as NSError
                    logger.error("Failed to encode request body: \(ns.localizedDescription) (Code: \(ns.code))")
                    throw APIError.unknown(error)
                }
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response received.")
                throw APIError.unknown(URLError(.badServerResponse))
            }
            logger.info("Received response status: \(http.statusCode)")

            guard (200...299).contains(http.statusCode) else {
                logger.error("Server error \(http.statusCode). Response: \(String(data: data, encoding: .utf8) ?? "N/A")")
                throw APIError.requestFailed(statusCode: http.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = APIManager.iso8601DateFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \"\(dateString)\"")
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Decoding failed: \(error.localizedDescription)")
                throw APIError.decodeError(error)
            }
        } catch let urlErr as URLError {
            logger.error("URLSession failed: \(urlErr.localizedDescription, privacy: .public) (Code: \(urlErr.code.rawValue, privacy: .public))")
            throw APIError.unknown(urlErr)
        } catch let apiErr as APIError {
            throw apiErr
        } catch {
            logger.error("Unknown network error: \(error.localizedDescription)")
            throw APIError.unknown(error)
        }
    }

    // MARK: - Requests WITHOUT a body
    func request<T: Decodable>(
        endpoint: String,
        method: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            logger.error("Invalid URL for endpoint: \(endpoint)")
            throw APIError.invalidURL
        }
        logger.info("Making \(method) request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let headers = headers {
            for (k, v) in headers { request.addValue(v, forHTTPHeaderField: k) }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                logger.error("Invalid HTTP response received.")
                throw APIError.unknown(URLError(.badServerResponse))
            }
            logger.info("Received response status: \(http.statusCode)")

            guard (200...299).contains(http.statusCode) else {
                logger.error("Server error \(http.statusCode). Response: \(String(data: data, encoding: .utf8) ?? "N/A")")
                throw APIError.requestFailed(statusCode: http.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = APIManager.iso8601DateFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \"\(dateString)\"")
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("Decoding failed: \(error.localizedDescription)")
                throw APIError.decodeError(error)
            }
        } catch let urlErr as URLError {
            logger.error("URLSession failed: \(urlErr.localizedDescription, privacy: .public) (Code: \(urlErr.code.rawValue, privacy: .public))")
            throw APIError.unknown(urlErr)
        } catch let apiErr as APIError {
            throw apiErr
        } catch {
            logger.error("Unknown network error: \(error.localizedDescription)")
            throw APIError.unknown(error)
        }
    }
}
