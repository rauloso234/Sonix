import Foundation

struct PlaylistMember: Identifiable, Codable, Hashable {
    var id: String { userId }
    let userId: String
    var displayName: String
    var photoURL: URL?
    var role: PlaylistRole
    let joinedAt: Date
}

enum PlaylistRole: String, Codable, CaseIterable {
    case owner
    case editor
    case viewer

    var canEditTracks: Bool {
        self == .owner || self == .editor
    }

    var canManageMembers: Bool {
        self == .owner
    }
}

extension PlaylistRole {
    var localizedName: String {
        switch self {
        case .owner: "Propietario"
        case .editor: "Editor"
        case .viewer: "Lector"
        }
    }
}
