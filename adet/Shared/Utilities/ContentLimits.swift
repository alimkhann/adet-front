import Foundation

struct ContentLimits {
    // MARK: - General Limits
    static let maxTextLength = 280
    static let maxBioLength = 150
    static let maxUsernameLength = 30
    static let minUsernameLength = 3

    // MARK: - Post Limits
    static let maxPostsPerDay = 50
    static let maxImagesPerPost = 5
    static let maxVideoLength = 60 // seconds
    static let maxFileSize = 50 * 1024 * 1024 // 50MB

    // MARK: - Friend Limits
    static let maxFriends = 5000
    static let maxCloseFriends = 999999 // Effectively unlimited
    static let maxFriendRequestsPerDay = 100

    // MARK: - Chat Limits
    static let maxMessageLength = 1000
    static let maxMessagesPerConversation = 10000

    // MARK: - Media Limits
    static let maxImageResolution = 4096 // pixels
    static let maxImageFileSize = 10 * 1024 * 1024 // 10MB
    static let maxVideoFileSize = 100 * 1024 * 1024 // 100MB

    // MARK: - Validation Methods

    static func isValidTextLength(_ text: String) -> Bool {
        return text.count <= maxTextLength
    }

    static func isValidUsername(_ username: String) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= minUsernameLength && trimmed.count <= maxUsernameLength
    }

    static func isValidBio(_ bio: String) -> Bool {
        return bio.count <= maxBioLength
    }
}