import Foundation
import Testing
@testable import AppDePrueba

@MainActor
struct RecommendationServiceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_MUSIC_INTEGRATION_TESTS"] == "1"))
    func realHeavenlyRecommendationsAreDifferentSongs() async throws {
        let service = MusicRecommendationService(
            repository: MusicRepository(provider: YouTubeKitMusicProvider(searchProvider: PipedSearchProvider()))
        )
        let current = makeTrack(id: "seed", title: "Heavenly Jumpstyle (Nightcore)", artist: "Nightcore")
        let result = try await service.recommendations(basedOn: [current], excluding: [current.id], limit: 5)
        #expect(result.count == 5)
        #expect(result.allSatisfy { !TrackTitleNormalizer.areLikelySameSong(current, $0) })
        for pair in zip(result, result.dropFirst()) {
            #expect(TrackTitleNormalizer.normalizedArtist(pair.0.artist) != TrackTitleNormalizer.normalizedArtist(pair.1.artist))
        }
    }

    @Test func canonicalTitleRemovesVersionLabelsWithoutChangingTrack() {
        let original = "Blinding Lights (Official Video)"
        #expect(TrackTitleNormalizer.canonicalTitle(original) == "blinding lights")
        #expect(TrackTitleNormalizer.canonicalTitle("Blinding Lights - Sped Up + Reverb") == "blinding lights")
        #expect(TrackTitleNormalizer.canonicalTitle("Heavenly Jumpstyle [Nightcore]") == "heavenly jumpstyle")
        #expect(original == "Blinding Lights (Official Video)")
    }

    @Test func sameSongDetectsVersionsButNotAnotherSongInStyle() {
        let original = makeTrack(id: "1", title: "Blinding Lights", artist: "The Weeknd")
        let official = makeTrack(id: "2", title: "Blinding Lights (Official Video)", artist: "The Weeknd Official")
        let spedUp = makeTrack(id: "3", title: "Blinding Lights Sped Up", artist: "Uploader")
        #expect(TrackTitleNormalizer.areLikelySameSong(original, official))
        #expect(TrackTitleNormalizer.areLikelySameSong(original, spedUp))
        #expect(!TrackTitleNormalizer.areLikelySameSong(
            makeTrack(id: "4", title: "Heavenly Jumpstyle", artist: "A"),
            makeTrack(id: "5", title: "Another Jumpstyle Song", artist: "B")
        ))
    }

    @Test func heavenlyVariantsAreRejected() {
        let current = makeTrack(id: "current", title: "Heavenly Jumpstyle (Nightcore)", artist: "Artist 1")
        let candidates = [
            makeTrack(id: "sped", title: "Heavenly Jumpstyle Sped Up", artist: "Channel A"),
            makeTrack(id: "lyrics", title: "Heavenly Jumpstyle (Lyrics)", artist: "Channel B"),
            makeTrack(id: "remix", title: "Heavenly Jumpstyle Remix", artist: "Channel C"),
            makeTrack(id: "another", title: "Another Jumpstyle Song", artist: "Artist 2"),
            makeTrack(id: "dance", title: "Hard Dance Track", artist: "Artist 3"),
            makeTrack(id: "different", title: "Different Nightcore Song", artist: "Artist 4")
        ]
        let service = MusicRecommendationService(repository: StubRecommendationRepository(results: []))
        let result = service.filterAndRank(candidates: candidates, context: [current], excludedIDs: [], limit: 10)
        #expect(Set(result.map(\.id)) == ["another", "dance", "different"])
    }

    @Test func artistDiversityAvoidsConsecutiveArtistWhenPossible() {
        let candidates = [
            makeTrack(id: "A", title: "Song A", artist: "Artist1"),
            makeTrack(id: "B", title: "Song B", artist: "Artist1"),
            makeTrack(id: "C", title: "Song C", artist: "Artist1"),
            makeTrack(id: "D", title: "Song D", artist: "Artist2"),
            makeTrack(id: "E", title: "Song E", artist: "Artist3")
        ]
        let service = MusicRecommendationService(repository: StubRecommendationRepository(results: []))
        let result = service.diversifyArtists(candidates, limit: 5)
        for pair in zip(result, result.dropFirst()).prefix(3) {
            #expect(TrackTitleNormalizer.normalizedArtist(pair.0.artist) != TrackTitleNormalizer.normalizedArtist(pair.1.artist))
        }
    }

    @Test func recommendationsDeduplicateAndRespectExclusions() async throws {
        let excluded = makeTrack(id: "excluded", artist: "Artist A")
        let first = makeTrack(id: "first", artist: "Artist A")
        let duplicate = makeTrack(id: "first", artist: "Artist A")
        let second = makeTrack(id: "second", artist: "Artist B")
        let repository = StubRecommendationRepository(results: [excluded, first, duplicate, second])
        let service = MusicRecommendationService(repository: repository)

        let recommendations = try await service.recommendations(
            basedOn: [makeTrack(id: "seed", artist: "Seed Artist")],
            excluding: ["excluded", "seed"],
            limit: 10
        )

        #expect(recommendations.map(\.youtubeVideoId) == ["first", "second"])
        #expect(Set(recommendations.map(\.youtubeVideoId)).count == recommendations.count)
    }

    @Test func changingQueueCancelsPreviousRecommendationTask() async {
        let service = CancellableRecommendationService()
        let manager = PlayerManager(
            repository: NeverResolvingMusicRepository(),
            nowPlayingService: SilentNowPlayingService(),
            recommendationService: service
        )

        manager.play(track: makeTrack(id: "A", artist: "Artist A"))
        manager.triggerPreloadingForTesting(remainingTime: 20)
        await waitUntil { service.callCount == 1 }
        manager.play(track: makeTrack(id: "B", artist: "Artist B"))
        manager.triggerPreloadingForTesting(remainingTime: 20)
        await waitUntil { service.callCount == 2 && service.cancellationCount == 1 }

        #expect(manager.queue.map(\.id) == ["B"])
        #expect(service.cancellationCount == 1)
        manager.shutdown()
    }

    private func makeTrack(id: String, title: String? = nil, artist: String) -> Track {
        Track(id: id, youtubeVideoId: id, title: title ?? "Track \(id)", artist: artist,
              thumbnailURL: nil, duration: 180)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<500 where !condition() { await Task.yield() }
    }
}

private struct StubRecommendationRepository: MusicRepositoryProtocol {
    let results: [Track]
    func search(query: String) async throws -> [Track] { results }
    func resolvePlaybackURL(videoId: String) async throws -> URL { throw MusicProviderError.cancelled }
}

private struct NeverResolvingMusicRepository: MusicRepositoryProtocol {
    func search(query: String) async throws -> [Track] { [] }
    func resolvePlaybackURL(videoId: String) async throws -> URL {
        try await Task.sleep(for: .seconds(60))
        throw MusicProviderError.cancelled
    }
}

@MainActor
private final class CancellableRecommendationService: MusicRecommendationServiceProtocol {
    private(set) var callCount = 0
    private(set) var cancellationCount = 0

    func recommendations(
        basedOn tracks: [Track], excluding excludedIDs: Set<String>, limit: Int
    ) async throws -> [Track] {
        callCount += 1
        do {
            try await Task.sleep(for: .seconds(60))
            return []
        } catch is CancellationError {
            cancellationCount += 1
            throw CancellationError()
        }
    }
}

@MainActor
private final class SilentNowPlayingService: NowPlayingServiceProtocol {
    func configureRemoteCommands(
        play: @escaping @MainActor () -> Void, pause: @escaping @MainActor () -> Void,
        toggle: @escaping @MainActor () -> Void, next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void,
        seek: @escaping @MainActor (TimeInterval) -> Void
    ) {}
    func update(
        track: Track, elapsedTime: TimeInterval, duration: TimeInterval,
        isPlaying: Bool, isPlaybackReady: Bool, canGoNext: Bool, canGoPrevious: Bool
    ) {}
    func clear() {}
    func shutdown() {}
}
