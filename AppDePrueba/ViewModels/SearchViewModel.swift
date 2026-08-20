import Foundation
import Observation

enum SearchState: Equatable {
    case idle, loading, loaded, empty, error
}

@MainActor
@Observable
final class SearchViewModel {
    private let repository: any MusicRepositoryProtocol
    private let playlistRepository: PlaylistRepositoryProtocol
    private var searchTask: Task<Void, Never>?
    private var playlistSearchTask: Task<Void, Never>?
    private(set) var results: [Track] = []
    private(set) var publicPlaylists: [Playlist] = []
    private(set) var state: SearchState = .idle
    private(set) var playlistState: SearchState = .idle
    var errorMessage: String?

    init(repository: any MusicRepositoryProtocol, playlistRepository: PlaylistRepositoryProtocol) {
        self.repository = repository
        self.playlistRepository = playlistRepository
    }

    func queryChanged(_ query: String) {
        searchTask?.cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []; state = .idle; errorMessage = nil
            return
        }
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, let self else { return }
                self.state = .loading
                let tracks = try await self.repository.search(query: query)
                guard !Task.isCancelled else { return }
                self.results = tracks
                self.state = tracks.isEmpty ? .empty : .loaded
                self.errorMessage = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.results = []
                self.state = .error
                self.errorMessage = "No se pudo conectar con el servicio de música."
            }
        }
    }

    func publicPlaylistQueryChanged(_ query: String) {
        playlistSearchTask?.cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            publicPlaylists = []
            playlistState = .idle
            errorMessage = nil
            return
        }
        playlistSearchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard let self, !Task.isCancelled else { return }
                self.playlistState = .loading
                let playlists = try await self.playlistRepository.searchPublicPlaylists(query: query, limit: 20)
                guard !Task.isCancelled else { return }
                self.publicPlaylists = playlists
                self.playlistState = playlists.isEmpty ? .empty : .loaded
                self.errorMessage = nil
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.publicPlaylists = []
                self.playlistState = .error
                self.errorMessage = "No se pudieron buscar playlists públicas."
            }
        }
    }
}
