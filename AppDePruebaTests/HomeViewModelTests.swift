import Foundation
import Testing
@testable import AppDePrueba

@MainActor
struct HomeViewModelTests {
    @Test func emptyHistoryProducesHelpfulStateWithoutRecommendations() async {
        let recommendations = HomeRecommendationStub(result: .success([]))
        let viewModel = HomeViewModel(
            historyRepository: HistoryStub(tracks: []), recommendationService: recommendations
        )
        await viewModel.load(userID: "user")
        #expect(viewModel.recentTracks.isEmpty)
        #expect(viewModel.recommendations.isEmpty)
        #expect(viewModel.recommendationMessage != nil)
        #expect(recommendations.callCount == 0)
    }

    @Test func historyLoadsAndBuildsRecommendations() async {
        let recent = [track("recent")]
        let suggested = track("suggested")
        let viewModel = HomeViewModel(
            historyRepository: HistoryStub(tracks: recent),
            recommendationService: HomeRecommendationStub(result: .success([suggested]))
        )
        await viewModel.load(userID: "user")
        #expect(viewModel.recentTracks == recent)
        #expect(viewModel.recommendations == [suggested])
    }

    @Test func recommendationFailureKeepsHistoryVisible() async {
        let recent = [track("recent")]
        let viewModel = HomeViewModel(
            historyRepository: HistoryStub(tracks: recent),
            recommendationService: HomeRecommendationStub(result: .failure(AppError.network))
        )
        await viewModel.load(userID: "user")
        #expect(viewModel.recentTracks == recent)
        #expect(viewModel.recommendations.isEmpty)
        #expect(viewModel.recommendationMessage != nil)
    }

    private func track(_ id: String) -> Track {
        Track(id: id, youtubeVideoId: id, title: "Track \(id)", artist: "Artist", thumbnailURL: nil, duration: 180)
    }
}

private struct HistoryStub: RecentlyPlayedRepositoryProtocol {
    let tracks: [Track]
    func recentTracks(userID: String, limit: Int) async throws -> [Track] { Array(tracks.prefix(limit)) }
    func record(_ track: Track, userID: String) async throws {}
}

@MainActor
private final class HomeRecommendationStub: MusicRecommendationServiceProtocol {
    private(set) var callCount = 0
    let result: Result<[Track], Error>
    init(result: Result<[Track], Error>) { self.result = result }
    func recommendations(basedOn tracks: [Track], excluding excludedIDs: Set<String>, limit: Int) async throws -> [Track] {
        callCount += 1
        return try result.get()
    }
}
