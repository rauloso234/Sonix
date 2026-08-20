import FirebaseFirestore
import Observation

@MainActor
@Observable
final class PlaylistDetailViewModel {
    private let repository: PlaylistRepositoryProtocol
    private var tracksListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    private(set) var tracks: [Track] = []
    private(set) var members: [PlaylistMember] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(repository: PlaylistRepositoryProtocol) { self.repository = repository }

    func start(playlistId: String, observeMembers: Bool = true) {
        stop()
        isLoading = true
        errorMessage = nil
        tracksListener = repository.observeTracks(playlistId: playlistId) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let tracks): self.tracks = tracks
                case .failure(let error): self.errorMessage = self.message(for: error)
                }
            }
        }
        guard observeMembers else {
            members = []
            return
        }
        membersListener = repository.observeMembers(playlistId: playlistId) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let members): self.members = members
                case .failure(let error): self.errorMessage = self.message(for: error)
                }
            }
        }
    }

    func role(for userId: String?) -> PlaylistRole? {
        guard let userId else { return nil }
        return members.first { $0.userId == userId }?.role
    }

    func stop() {
        tracksListener?.remove()
        membersListener?.remove()
        tracksListener = nil
        membersListener = nil
    }

    private func message(for error: Error) -> String {
        let nsError = error as NSError
        if FirestoreErrorCode.Code(rawValue: nsError.code) == .permissionDenied {
            return "No tienes permiso para acceder a esta playlist."
        }
        if FirestoreErrorCode.Code(rawValue: nsError.code) == .unavailable {
            return "No se pudo conectar con el servidor."
        }
        return "No se pudo cargar la playlist."
    }
}
