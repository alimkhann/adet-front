import Foundation

struct APIConfig {
    // MARK: - Development
    #if DEBUG
//    static let baseURL = "http://10.68.96.157:8000"
//    static let wsBaseURL = "ws://10.68.96.157:8000"
    static let baseURL = "http://localhost:8000"
    static let wsBaseURL = "ws://localhost:8000"
    #else
    // MARK: - Production
    static let baseURL = "https://your-production-domain.com"
    static let wsBaseURL = "wss://your-production-domain.com"
    #endif

    static let apiBaseURL = "\(baseURL)/api/v1"
}
