import Foundation

public struct Habit: Codable, Identifiable, Hashable {
    public let id: Int
    public let userId: Int
    public var name: String
    public var description: String
    public var frequency: String
    public var validationTime: String
    public var difficulty: String
    public var proofStyle: String
    public var streak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case frequency
        case validationTime = "validation_time"
        case difficulty
        case proofStyle = "proof_style"
        case streak
    }

    // Convenience initializer for creating a default new habit
    init(id: Int, userId: Int, name: String, description: String, frequency: String, validationTime: String, difficulty: String, proofStyle: String, streak: Int) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.frequency = frequency
        self.validationTime = validationTime
        self.difficulty = difficulty
        self.proofStyle = proofStyle
        self.streak = streak
    }
}
