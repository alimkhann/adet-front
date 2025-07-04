import Foundation

struct Habit: Codable, Identifiable {
    let id: Int
    let userId: Int
    var name: String
    var description: String
    var frequency: String
    var validationTime: String
    var difficulty: String
    var proofStyle: String
    let streak: Int

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