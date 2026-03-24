import Foundation

struct AuthUser: Codable {
    let id: String
    let email: String?
    var displayName: String?
}
