import Foundation

struct Habit: Codable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case streak
    }
}