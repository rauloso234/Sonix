import Foundation

struct AppUser: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: URL?
    let createdAt: Date
}

extension AppUser {
    static let preview = AppUser(
        id: "preview-user",
        displayName: "Raúl",
        email: "preview@example.com",
        photoURL: nil,
        createdAt: .now
    )
}
