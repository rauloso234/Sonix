import FirebaseFirestore
import Observation

@MainActor
@Observable
final class PlaylistViewModel {
    private let repository: PlaylistRepositoryProtocol
    private var listener: ListenerRegistration?
    private var observedOwnerId: String?

    private(set) var ownedPlaylists: [Playlist] = []
    private(set) var collaborativePlaylists: [Playlist] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    init(repository: PlaylistRepositoryProtocol) {
        self.repository = repository
    }

    func observeOwnedPlaylists(ownerId: String) {
        guard !ownerId.isEmpty else {
            resetForSignedOutSession()
            return
        }
        guard observedOwnerId != ownerId else { return }
        stopObserving()
        observedOwnerId = ownerId
        isLoading = true

        listener = repository.observeLibrary(userId: ownerId) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isLoading = false
                switch result {
                case .success(let library):
                    self?.ownedPlaylists = library.owned
                    self?.collaborativePlaylists = library.collaborative
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = self?.friendlyMessage(
                        for: error,
                        action: "cargar tus playlists"
                    )
                }
            }
        }
    }

    func createPlaylist(
        name: String,
        description: String,
        isCollaborative: Bool,
        owner: AppUser
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repository.createPlaylist(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                isCollaborative: isCollaborative,
                owner: owner
            )
            return true
        } catch {
            errorMessage = friendlyMessage(for: error, action: "crear la playlist")
            return false
        }
    }

    func joinPlaylist(code: String, user: AppUser) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await repository.joinPlaylist(code: code, user: user)
            return true
        } catch {
            errorMessage = friendlyMessage(for: error, action: "unirte a la playlist")
            return false
        }
    }

    func addTrack(_ track: Track, to playlist: Playlist, user: AppUser) async -> Bool {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            try await repository.addTrack(track, to: playlist, user: user)
            successMessage = "Canción añadida a \(playlist.name)."
            return true
        } catch PlaylistServiceError.duplicateTrack {
            errorMessage = "Esta canción ya está en la playlist."
            return false
        } catch {
            errorMessage = friendlyMessage(for: error, action: "añadir la canción")
            return false
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
        observedOwnerId = nil
    }

    func resetForSignedOutSession() {
        stopObserving()
        ownedPlaylists = []
        collaborativePlaylists = []
        isLoading = false
        errorMessage = nil
    }

    private func friendlyMessage(for error: Error, action: String) -> String {
        if let error = error as? PlaylistServiceError {
            switch error {
            case .unauthenticated: return "Debes iniciar sesión."
            case .invalidInviteCode, .inviteNotFound: return "El código de la playlist no existe."
            case .inviteInactive: return "Esta invitación ya no está disponible."
            case .alreadyMember: return "Ya formas parte de esta playlist."
            case .notCollaborative: return "Esta playlist no admite colaboradores."
            case .inviteCollision: return "No se pudo generar un código único. Inténtalo de nuevo."
            case .duplicateTrack: return "Esta canción ya está en la playlist."
            }
        }
        if let appError = error as? AppError {
            return appError.localizedDescription
        }

        let nsError = error as NSError
        guard let code = FirestoreErrorCode.Code(rawValue: nsError.code) else {
            return "No se pudo \(action). Vuelve a intentarlo."
        }

        switch code {
        case .permissionDenied:
            return "No se pudo \(action) por un problema de permisos."
        case .unauthenticated:
            return "Tu sesión ha caducado. Inicia sesión de nuevo."
        case .unavailable:
            return "Firestore no está disponible ahora. Comprueba tu conexión y vuelve a intentarlo."
        case .notFound:
            return "No se encontró la base de datos de Cloud Firestore."
        default:
            return "No se pudo \(action). Vuelve a intentarlo."
        }
    }
}
