import Foundation

// MARK: - API Error Types
enum APIError: Error, LocalizedError {
    case invalidRequest
    case validationFailed(String)
    case resourceNotFound
    case conflict(String)
    case rateLimited
    case serverError(String)
    case maintenanceMode
    case networkError(NetworkError)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The API request was invalid."
        case .validationFailed(let field):
            return "Validation failed for field: \(field)"
        case .resourceNotFound:
            return "The requested resource was not found."
        case .conflict(let message):
            return "Resource conflict: \(message)"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let message):
            return "Server error: \(message)"
        case .maintenanceMode:
            return "Server is currently under maintenance."
        case .networkError(let networkError):
            return networkError.localizedDescription
        }
    }
}