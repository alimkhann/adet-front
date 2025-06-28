import Foundation

// MARK: - AI Task Generation Models

struct AITaskRequest: Codable {
    let baseDifficulty: String // "easy", "medium", "hard"
    let motivationLevel: String // "low", "medium", "high"
    let abilityLevel: String // "hard", "medium", "easy"
    let proofStyle: String // "photo", "video", "audio", "text"
    let userLanguage: String?
    let userTimezone: String?

    enum CodingKeys: String, CodingKey {
        case baseDifficulty = "base_difficulty"
        case motivationLevel = "motivation_level"
        case abilityLevel = "ability_level"
        case proofStyle = "proof_style"
        case userLanguage = "user_language"
        case userTimezone = "user_timezone"
    }
}

struct GeneratedTaskResponse: Codable {
    let taskDescription: String
    let difficultyLevel: Double
    let estimatedDuration: Int
    let successCriteria: String
    let celebrationMessage: String
    let easierAlternative: String?
    let harderAlternative: String?
    let proofRequirements: String
    let calibrationMetadata: CalibrationMetadata?

    enum CodingKeys: String, CodingKey {
        case taskDescription = "task_description"
        case difficultyLevel = "difficulty_level"
        case estimatedDuration = "estimated_duration"
        case successCriteria = "success_criteria"
        case celebrationMessage = "celebration_message"
        case easierAlternative = "easier_alternative"
        case harderAlternative = "harder_alternative"
        case proofRequirements = "proof_requirements"
        case calibrationMetadata = "calibration_metadata"
    }
}

struct CalibrationMetadata: Codable {
    let originalDifficulty: String
    let calibratedDifficulty: Double
    let calibrationReasoning: String
    let calibrationConfidence: Double

    enum CodingKeys: String, CodingKey {
        case originalDifficulty = "original_difficulty"
        case calibratedDifficulty = "calibrated_difficulty"
        case calibrationReasoning = "calibration_reasoning"
        case calibrationConfidence = "calibration_confidence"
    }
}

// MARK: - Task Entry Models

struct TaskEntry: Codable, Identifiable {
    let id: Int
    let habitId: Int
    let userId: Int
    let taskDescription: String
    let difficultyLevel: Double
    let estimatedDuration: Int
    let successCriteria: String
    let celebrationMessage: String
    let easierAlternative: String?
    let harderAlternative: String?
    let proofRequirements: String
    let status: String
    let assignedDate: String
    let dueDate: String
    let completedAt: String?
    let proofType: String?
    let proofContent: String?
    let proofValidationResult: Bool?
    let proofValidationConfidence: Double?
    let proofFeedback: String?
    let aiGenerationMetadata: String?
    let calibrationMetadata: String?
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case taskDescription = "task_description"
        case difficultyLevel = "difficulty_level"
        case estimatedDuration = "estimated_duration"
        case successCriteria = "success_criteria"
        case celebrationMessage = "celebration_message"
        case easierAlternative = "easier_alternative"
        case harderAlternative = "harder_alternative"
        case proofRequirements = "proof_requirements"
        case status
        case assignedDate = "assigned_date"
        case dueDate = "due_date"
        case completedAt = "completed_at"
        case proofType = "proof_type"
        case proofContent = "proof_content"
        case proofValidationResult = "proof_validation_result"
        case proofValidationConfidence = "proof_validation_confidence"
        case proofFeedback = "proof_feedback"
        case aiGenerationMetadata = "ai_generation_metadata"
        case calibrationMetadata = "calibration_metadata"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Task Status Enum

enum TaskStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
    case missed = "missed"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .missed: return "Missed"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        case .missed: return "gray"
        }
    }
}

// MARK: - Proof Type Enum

enum ProofType: String, CaseIterable, Codable {
    case photo = "photo"
    case video = "video"
    case audio = "audio"
    case text = "text"

    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .audio: return "Audio"
        case .text: return "Text"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "camera"
        case .video: return "video"
        case .audio: return "mic"
        case .text: return "text.bubble"
        }
    }
}

// MARK: - Task Proof Submission

struct TaskProofSubmit: Codable {
    let proofType: ProofType
    let proofContent: String

    enum CodingKeys: String, CodingKey {
        case proofType = "proof_type"
        case proofContent = "proof_content"
    }
}

// MARK: - Task Status Update

struct TaskStatusUpdate: Codable {
    let status: TaskStatus
}

// MARK: - Performance Analysis

struct PerformanceAnalysis: Codable {
    let totalTasks: Int
    let completedTasks: Int
    let successRate: Double
    let currentStreak: Int
    let difficultyInsights: [String]

    enum CodingKeys: String, CodingKey {
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case successRate = "success_rate"
        case currentStreak = "current_streak"
        case difficultyInsights = "difficulty_insights"
    }
}

// MARK: - Improvement Suggestions

struct ImprovementSuggestions: Codable {
    let performanceSummary: PerformanceAnalysis
    let improvementSuggestions: String

    enum CodingKeys: String, CodingKey {
        case performanceSummary = "performance_summary"
        case improvementSuggestions = "improvement_suggestions"
    }
}

// MARK: - API Response Wrappers

struct AIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let metadata: [String: String]?
}

struct TaskGenerationResponse: Codable {
    let success: Bool
    let task: GeneratedTaskResponse
    let metadata: [String: String]?
}

struct TaskCreationResponse: Codable {
    let success: Bool
    let task: TaskEntry
    let aiMetadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case success
        case task
        case aiMetadata = "ai_metadata"
    }
}

struct TaskSubmissionResponse: Codable {
    let success: Bool
    let task: TaskEntry
    let message: String
}