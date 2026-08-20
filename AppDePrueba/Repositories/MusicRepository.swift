import Foundation

protocol MusicRepositoryProtocol: Sendable {
    func search(query: String) async throws -> [Track]
    func resolvePlaybackURL(videoId: String) async throws -> URL
}

struct MusicRepository: MusicRepositoryProtocol {
    private let provider: any MusicProviderProtocol
    init(provider: any MusicProviderProtocol) { self.provider = provider }
    func search(query: String) async throws -> [Track] { try await provider.search(query: query) }
    func resolvePlaybackURL(videoId: String) async throws -> URL {
        try await provider.resolvePlaybackURL(videoId: videoId)
    }
}
