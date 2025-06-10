import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let email: String
    var username: String
    var password: String
    var profileImage: String?
    let createdAt: Date
    var updatedAt: Date?
}
