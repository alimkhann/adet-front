import Foundation

struct APIConfig {
    // MARK: - Development
    #if DEBUG
    static let baseURL = "http://localhost:8000"
    static let wsBaseURL = "ws://localhost:8000"
    #else
    // MARK: - Production
    static let baseURL = "https://api.tryadet.com"
    static let wsBaseURL = "wss://api.tryadet.com"
    #endif

    static let apiBaseURL = "\(baseURL)/v1"
}
