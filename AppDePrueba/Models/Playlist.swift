import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    let ownerId: String
    var ownerDisplayName: String = "Propietario"
    var imageURL: URL?
    var joinCode: String?
    var isCollaborative: Bool
    var visibility: PlaylistVisibility
    let createdAt: Date
    var updatedAt: Date
    var trackCount: Int
    var memberCount: Int
    var normalizedName: String = ""
    var searchPrefixes: [String] = []
}

struct PlaylistLibrary: Equatable {
    var owned: [Playlist]
    var collaborative: [Playlist]
    var followed: [Playlist]
    var editablePlaylistIDs: Set<String>

    static let empty = PlaylistLibrary(
        owned: [], collaborative: [], followed: [], editablePlaylistIDs: []
    )
}

enum UserPlaylistType: String, Codable {
    case owned
    case collaborative
    case followed
}

enum PlaylistVisibility: String, Codable, CaseIterable {
    case privateOnly = "private"
    case shared
    case publicVisible = "public"
}

extension PlaylistVisibility {
    static func fromFirestore(_ value: Any?) -> PlaylistVisibility {
        guard let rawValue = value as? String,
              let visibility = PlaylistVisibility(rawValue: rawValue) else { return .privateOnly }
        return visibility
    }

    var localizedName: String {
        switch self {
        case .privateOnly: "Privada"
        case .shared: "Compartida"
        case .publicVisible: "Pública"
        }
    }
}
