import Foundation
import Observation

enum SearchState: Equatable {
    case idle, loading, loaded, empty, error
}

@MainActor
@Observable
final class SearchViewModel {
    private let repository: any MusicRepositoryProtocol
    private var searchTask: Task<Void, Never>?
    private(set) var results: [Track] = []
    private(set) var state: SearchState = .idle
    var errorMessage: String?

    init(repository: any MusicRepositoryProtocol) { self.repository = repository }

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
}
