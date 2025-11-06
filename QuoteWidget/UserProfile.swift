import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var name: String?
    var profileImageUrl: String?
    var email: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profileImageUrl = "profile_image_url"
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
