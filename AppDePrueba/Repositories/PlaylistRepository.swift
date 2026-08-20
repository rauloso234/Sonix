import FirebaseFirestore

protocol PlaylistRepositoryProtocol {
    func createPlaylist(name: String, description: String, isCollaborative: Bool, owner: AppUser) async throws -> Playlist
    func observeLibrary(userId: String, onChange: @escaping (Result<PlaylistLibrary, Error>) -> Void) -> ListenerRegistration?
    func observeTracks(playlistId: String, onChange: @escaping (Result<[Track], Error>) -> Void) -> ListenerRegistration
    func observeMembers(playlistId: String, onChange: @escaping (Result<[PlaylistMember], Error>) -> Void) -> ListenerRegistration
    func joinPlaylist(code: String, user: AppUser) async throws -> Playlist
    func addTrack(_ track: Track, to playlist: Playlist, user: AppUser) async throws
}

final class FirebasePlaylistRepository: PlaylistRepositoryProtocol {
    private let service: FirestoreServiceProtocol
    init(service: FirestoreServiceProtocol) { self.service = service }

    func createPlaylist(name: String, description: String, isCollaborative: Bool, owner: AppUser) async throws -> Playlist {
        try await service.createPlaylist(name: name, description: description, isCollaborative: isCollaborative, owner: owner)
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
