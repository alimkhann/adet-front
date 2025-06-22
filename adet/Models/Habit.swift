import Foundation

struct Habit: Codable, Identifiable {
    let id: Int
    let userId: Int
    var name: String
    var description: String?
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
}