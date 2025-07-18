import Foundation

// MARK: - API Error Model
struct APIError: Codable, Error {
    let detail: String
    let code: String?

    init(detail: String, code: String? = nil) {
        self.detail = detail
        self.code = code
    }
}

// MARK: - API Response Types
struct HealthResponse: Codable {
    let status: String
    let database: String
}

struct EmptyResponse: Codable {}

// MARK: - User API Models
struct UsernameUpdateRequest: Codable {
    let username: String
}

struct ProfileImageUpdateRequest: Codable {
    let profileImageUrl: String

    enum CodingKeys: String, CodingKey {
        case profileImageUrl = "profile_image_url"
    }
}

struct ProfileUpdateRequest: Codable {
    let name: String?
    let username: String?
    let bio: String?
}

// MARK: - Habit API Models
struct HabitCreateRequest: Codable {
    let name: String
    let description: String
    let frequency: String
    let validationTime: String
    let difficulty: String
    let proofStyle: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case frequency
        case validationTime = "validation_time"
        case difficulty
        case proofStyle = "proof_style"
    }
}

// MARK: - Motivation & Ability API Models
struct MotivationEntryRequest: Codable {
    let habit_id: Int
    let date: String
    let level: String
}

struct AbilityEntryRequest: Codable {
    let habit_id: Int
    let date: String
    let level: String
}

public struct MotivationEntryResponse: Codable {
    let id: Int
    let habit_id: Int
    let date: String
    let level: String
}

public struct AbilityEntryResponse: Codable {
    let id: Int
    let habit_id: Int
    let date: String
    let level: String
}

// MARK: - Onboarding API Models
struct OnboardingAnswer: Codable {
    let id: Int
    let user_id: Int
    let habit_name: String
    let habit_description: String
    let frequency: String
    let validation_time: String
    let difficulty: String
    let proof_style: String
}

// MARK: - Task Management API Models
struct AITaskGenerationRequest: Codable {
    let base_difficulty: String
    let motivation_level: String
    let ability_level: String
    let proof_style: String
    let user_language: String?
    let user_timezone: String?
    let user_date: String

    enum CodingKeys: String, CodingKey {
        case base_difficulty = "base_difficulty"
        case motivation_level = "motivation_level"
        case ability_level = "ability_level"
        case proof_style = "proof_style"
        case user_language = "user_language"
        case user_timezone = "user_timezone"
        case user_date = "user_date"
    }
}

struct TaskCreationResponse: Codable {
    let success: Bool
    let task: TaskEntry
}

struct TaskProofSubmissionData: Codable {
    let proof_type: String
    let proof_content: String

    enum CodingKeys: String, CodingKey {
        case proof_type = "proof_type"
        case proof_content = "proof_content"
    }
}

public struct AutoCreatedPost: Codable {
    public let id: Int
    public let privacy: String
    public let description: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case privacy
        case description
        case createdAt = "created_at"
    }
}

public struct TaskSubmissionResponse: Codable {
    let task: TaskEntry
    let validation: TaskValidationResult?
    public let attemptsLeft: Int?
    public let dueDate: String?
    public let autoCreatedPost: AutoCreatedPost?

    enum CodingKeys: String, CodingKey {
        case task
        case validation
        case attemptsLeft = "attempts_left"
        case dueDate = "due_date"
        case autoCreatedPost = "auto_created_post"
    }
}

struct TaskValidationResult: Codable {
    let isValid: Bool?
    let isNsfw: Bool?
    let confidence: Double?
    let feedback: String?
    let reasoning: String?
    let suggestions: [String]?

    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case isNsfw = "is_nsfw"
        case confidence
        case feedback
        case reasoning
        case suggestions
    }
}

struct TaskStatusUpdateRequest: Codable {
    let status: String
}

struct TaskStatusResponse: Codable {
    let success: Bool
    let task: TaskEntry
    let message: String
}

struct ExpiredTasksResponse: Codable {
    let success: Bool
    let expired_tasks: [TaskEntry]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case success
        case expired_tasks = "expired_tasks"
        case count
    }
}

// MARK: - Friends API Models
struct FriendRequestCreateRequest: Codable {
    let receiverId: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
        case message
    }
}

struct FriendsListResponse: Codable {
    let friends: [Friend]
    let count: Int
}

struct UserSearchResponse: Codable {
    let users: [UserBasic]
    let count: Int
    let query: String
}

struct FriendActionResponse: Codable {
    let success: Bool
    let message: String
    let friendship: Friend?
}

struct FriendRequestActionResponse: Codable {
    let success: Bool
    let message: String
    let request: FriendRequest?
}

struct FriendshipStatusResponse: Codable {
    let userId: Int
    let friendshipStatus: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case friendshipStatus = "friendship_status"
    }
}

struct PostModel: Codable, Identifiable {
    let id: Int
    let content: String?
    let imageUrl: String?
    let createdAt: String?
    let authorId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case authorId = "author_id"
    }
}
