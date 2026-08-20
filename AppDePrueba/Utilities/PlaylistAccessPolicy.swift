import Foundation

enum PlaylistAccessPolicy {
    static func canEditTracks(userId: String?, playlist: Playlist, role: PlaylistRole?) -> Bool {
        guard let userId else { return false }
        return userId == playlist.ownerId || role?.canEditTracks == true
    }

    static func canManagePlaylist(userId: String?, playlist: Playlist) -> Bool {
        userId == playlist.ownerId
    }
}
