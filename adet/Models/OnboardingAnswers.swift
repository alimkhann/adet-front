import Foundation

struct OnboardingAnswers: Codable {
    var habitName: String = ""
    var habitDescription: String?
    var frequency: String = ""
    var validationTime: String = ""
    var difficulty: String = ""
    var proofStyle: String = ""

    enum CodingKeys: String, CodingKey {
        case habitName = "habit_name"
        case habitDescription = "habit_description"
        case frequency
        case validationTime = "validation_time"
        case difficulty
        case proofStyle = "proof_style"
    }
}