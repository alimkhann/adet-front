import Foundation

struct ContentLimits {

    // MARK: - Text Limits

    /// Habit name character limit
    static let habitName: Int = 50

    /// Habit description character limit
    static let habitDescription: Int = 200

    /// Post description character limit (Twitter-style)
    static let postDescription: Int = 280

    /// Comment character limit
    static let comment: Int = 150

    /// User bio character limit
    static let userBio: Int = 150

    /// Message character limit
    static let message: Int = 1000

    /// Username character limit
    static let username: Int = 30

    /// Display name character limit
    static let displayName: Int = 50

    // MARK: - Media Limits

    /// Maximum number of images per post
    static let maxImagesPerPost: Int = 5

    /// Maximum image file size before compression (bytes)
    static let maxImageFileSize: Int = 10_000_000 // 10MB

    /// Maximum video duration (seconds)
    static let maxVideoDuration: TimeInterval = 60 // 60 seconds

    /// Maximum video file size before compression (bytes)
    static let maxVideoFileSize: Int = 50_000_000 // 50MB

    /// Maximum audio recording duration (seconds)
    static let maxAudioDuration: TimeInterval = 300 // 5 minutes

    /// Maximum audio file size (bytes)
    static let maxAudioFileSize: Int = 10_000_000 // 10MB

    // MARK: - Compressed Media Sizes

    /// Profile image compressed size target (bytes)
    static let profileImageCompressedSize: Int = 500_000 // 500KB

    /// Post image compressed size target (bytes)
    static let postImageCompressedSize: Int = 2_000_000 // 2MB

    // MARK: - Social Limits

    /// Maximum number of close friends
    static let maxCloseFriends: Int = 50

    /// Maximum number of friends
    static let maxFriends: Int = 500

    /// Feed display window (days)
    static let feedWindowDays: Int = 3

    // MARK: - Validation Functions

    /// Validates text content against specified limit
    static func validateText(_ text: String, limit: Int) -> (isValid: Bool, remainingChars: Int) {
        let remaining = limit - text.count
        return (remaining >= 0, remaining)
    }

    /// Validates habit name
    static func validateHabitName(_ name: String) -> (isValid: Bool, remainingChars: Int) {
        return validateText(name, limit: habitName)
    }

    /// Validates post description
    static func validatePostDescription(_ description: String) -> (isValid: Bool, remainingChars: Int) {
        return validateText(description, limit: postDescription)
    }

    /// Validates comment
    static func validateComment(_ comment: String) -> (isValid: Bool, remainingChars: Int) {
        return validateText(comment, limit: self.comment)
    }

    /// Validates user bio
    static func validateBio(_ bio: String) -> (isValid: Bool, remainingChars: Int) {
        return validateText(bio, limit: userBio)
    }

    /// Validates media file size
    static func validateFileSize(_ sizeInBytes: Int, maxSize: Int) -> Bool {
        return sizeInBytes <= maxSize
    }

    /// Validates video duration
    static func validateVideoDuration(_ duration: TimeInterval) -> Bool {
        return duration <= maxVideoDuration
    }

    /// Validates audio duration
    static func validateAudioDuration(_ duration: TimeInterval) -> Bool {
        return duration <= maxAudioDuration
    }
}