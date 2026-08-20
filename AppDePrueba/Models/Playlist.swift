import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    let ownerId: String
    var imageURL: URL?
    var joinCode: String?
    var isCollaborative: Bool
    var visibility: PlaylistVisibility
    let createdAt: Date
    var updatedAt: Date
    var trackCount: Int
    var memberCount: Int
}

struct PlaylistLibrary: Equatable {
    var owned: [Playlist]
    var collaborative: [Playlist]

    static let empty = PlaylistLibrary(owned: [], collaborative: [])
}

enum UserPlaylistType: String, Codable {
    case owned
    case collaborative
}

enum PlaylistVisibility: String, Codable, CaseIterable {
    case privateOnly = "private"
    case shared
    case publicVisible = "public"
}
