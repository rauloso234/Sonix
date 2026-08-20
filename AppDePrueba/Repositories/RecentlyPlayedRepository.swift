import Foundation

protocol RecentlyPlayedRepositoryProtocol: Sendable {
    func recentTracks(userID: String, limit: Int) async throws -> [Track]
    func record(_ track: Track, userID: String) async throws
}

struct FirebaseRecentlyPlayedRepository: RecentlyPlayedRepositoryProtocol {
    private let service: any RecentlyPlayedServiceProtocol
    init(service: any RecentlyPlayedServiceProtocol) { self.service = service }

    func recentTracks(userID: String, limit: Int) async throws -> [Track] {
        try await service.recentTracks(userID: userID, limit: limit)
    }

    func record(_ track: Track, userID: String) async throws {
        try await service.record(track, userID: userID)
    }
}
