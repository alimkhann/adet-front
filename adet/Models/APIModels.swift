import Foundation

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

struct MotivationEntryResponse: Codable {
    let id: Int
    let habit_id: Int
    let date: String
    let level: String
}

struct AbilityEntryResponse: Codable {
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

    enum CodingKeys: String, CodingKey {
        case base_difficulty = "base_difficulty"
        case motivation_level = "motivation_level"
        case ability_level = "ability_level"
        case proof_style = "proof_style"
        case user_language = "user_language"
        case user_timezone = "user_timezone"
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

struct TaskSubmissionResponse: Codable {
    let success: Bool
    let task: TaskEntry
    let message: String
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