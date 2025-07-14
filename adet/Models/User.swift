import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let clerkId: String
    let email: String
    let name: String?
    let username: String?
    let bio: String?
    let profileImageUrl: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date?
    let plan: String

    enum CodingKeys: String, CodingKey {
        case id
        case clerkId = "clerk_id"
        case email
        case name
        case username
        case bio
        case profileImageUrl = "profile_image_url"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case plan
    }
}

extension User {
    var asUserBasic: UserBasic {
        UserBasic(
            id: self.id,
            username: self.username,
            name: self.name,
            bio: self.bio,
            profileImageUrl: self.profileImageUrl
        )
    }
}
