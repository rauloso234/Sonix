import FirebaseFirestore

protocol PlaylistRepositoryProtocol {
    func createPlaylist(name: String, description: String, isCollaborative: Bool, visibility: PlaylistVisibility, owner: AppUser) async throws -> Playlist
    func updatePlaylist(_ playlist: Playlist, name: String, description: String, visibility: PlaylistVisibility, user: AppUser) async throws
    func searchPublicPlaylists(query: String, limit: Int) async throws -> [Playlist]
    func followPlaylist(_ playlist: Playlist, user: AppUser) async throws
    func unfollowPlaylist(_ playlist: Playlist, user: AppUser) async throws
    func observeLibrary(userId: String, onChange: @escaping (Result<PlaylistLibrary, Error>) -> Void) -> ListenerRegistration?
    func observeTracks(playlistId: String, onChange: @escaping (Result<[Track], Error>) -> Void) -> ListenerRegistration
    func observeMembers(playlistId: String, onChange: @escaping (Result<[PlaylistMember], Error>) -> Void) -> ListenerRegistration
    func joinPlaylist(code: String, user: AppUser) async throws -> Playlist
    func addTrack(_ track: Track, to playlist: Playlist, user: AppUser) async throws
}

final class FirebasePlaylistRepository: PlaylistRepositoryProtocol {
    private let service: FirestoreServiceProtocol
    init(service: FirestoreServiceProtocol) { self.service = service }

    func createPlaylist(name: String, description: String, isCollaborative: Bool, visibility: PlaylistVisibility, owner: AppUser) async throws -> Playlist {
        try await service.createPlaylist(name: name, description: description, isCollaborative: isCollaborative, visibility: visibility, owner: owner)
    }

    func updatePlaylist(_ playlist: Playlist, name: String, description: String, visibility: PlaylistVisibility, user: AppUser) async throws {
        try await service.updatePlaylist(playlist, name: name, description: description, visibility: visibility, user: user)
    }

    func searchPublicPlaylists(query: String, limit: Int) async throws -> [Playlist] {
        try await service.searchPublicPlaylists(query: query, limit: limit)
    }

    func followPlaylist(_ playlist: Playlist, user: AppUser) async throws {
        try await service.followPlaylist(playlist, user: user)
    }

    func unfollowPlaylist(_ playlist: Playlist, user: AppUser) async throws {
        try await service.unfollowPlaylist(playlist, user: user)
    }

    func observeLibrary(userId: String, onChange: @escaping (Result<PlaylistLibrary, Error>) -> Void) -> ListenerRegistration? {
        service.observeLibrary(userId: userId, onChange: onChange)
    }

    func observeTracks(playlistId: String, onChange: @escaping (Result<[Track], Error>) -> Void) -> ListenerRegistration {
        service.observeTracks(playlistId: playlistId, onChange: onChange)
    }

    func observeMembers(playlistId: String, onChange: @escaping (Result<[PlaylistMember], Error>) -> Void) -> ListenerRegistration {
        service.observeMembers(playlistId: playlistId, onChange: onChange)
    }

    func joinPlaylist(code: String, user: AppUser) async throws -> Playlist {
        try await service.joinPlaylist(code: code, user: user)
    }

    func addTrack(_ track: Track, to playlist: Playlist, user: AppUser) async throws {
        try await service.addTrack(track, to: playlist, user: user)
    }
}
