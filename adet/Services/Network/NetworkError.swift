import Foundation

// MARK: - Network Error Types
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case requestFailed(statusCode: Int, body: String?)
    case decodeError(Error)
    case unknown(Error)
    case timeout
    case connectionLost
    case noInternet

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .unauthorized:
            return "User is not authenticated."
        case .requestFailed(let statusCode, let body):
            return "Network request failed with status code: \(statusCode). Response: \(body ?? "N/A")"
        case .decodeError(let error):
            return "Failed to decode network response: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unknown network error occurred: \(error.localizedDescription)"
        case .timeout:
            return "Network request timed out."
        case .connectionLost:
            return "Network connection was lost."
        case .noInternet:
            return "No internet connection available."
        }
    }
}