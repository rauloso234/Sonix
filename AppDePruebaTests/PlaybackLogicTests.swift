import Foundation
import Testing
@testable import AppDePrueba

@MainActor
struct PlaybackLogicTests {
    @Test func nextAndPreviousIndicesStayInsideQueue() {
        #expect(PlaybackQueueLogic.nextIndex(currentIndex: 0, queueCount: 3) == 1)
        #expect(PlaybackQueueLogic.nextIndex(currentIndex: 2, queueCount: 3) == nil)
        #expect(PlaybackQueueLogic.previousIndex(currentIndex: 2, queueCount: 3) == 1)
        #expect(PlaybackQueueLogic.previousIndex(currentIndex: 0, queueCount: 3) == nil)
    }

    @Test func queueNavigationRejectsInvalidState() {
        #expect(PlaybackQueueLogic.nextIndex(currentIndex: nil, queueCount: 3) == nil)
        #expect(PlaybackQueueLogic.nextIndex(currentIndex: -1, queueCount: 3) == nil)
        #expect(PlaybackQueueLogic.previousIndex(currentIndex: 3, queueCount: 3) == nil)
    }

    @Test func metadataWinsWhenAssetDurationIsClearlyInconsistent() {
        #expect(PlayerManager.effectiveDuration(metadataDuration: 174, assetDuration: 346) == 174)
    }

    @Test func nearbyAssetDurationCanRefineMetadata() {
        #expect(PlayerManager.effectiveDuration(metadataDuration: 174, assetDuration: 176) == 176)
    }

    @Test func validAssetIsFallbackWhenMetadataIsUnavailable() {
        #expect(PlayerManager.effectiveDuration(metadataDuration: 0, assetDuration: 240) == 240)
        #expect(PlayerManager.effectiveDuration(metadataDuration: .nan, assetDuration: .infinity) == 0)
    }

    @Test func playQueueKeepsAllTracksAndSelectedIndex() {
        let tracks = [makeTrack(id: "A", duration: 180),
                      makeTrack(id: "B", duration: 240),
                      makeTrack(id: "C", duration: 210)]
        let manager = makePlayerManager()

        manager.playQueue(tracks, startingAt: 1)

        #expect(manager.queue == tracks)
        #expect(manager.currentIndex == 1)
        #expect(manager.currentTrack == tracks[1])
        #expect(manager.canGoNext)
        #expect(manager.canGoPrevious)
        manager.shutdown()
    }

    @Test func changingTrackResetsTimeAndUsesNewMetadataDuration() {
        let first = makeTrack(id: "A", duration: 180)
        let second = makeTrack(id: "B", duration: 240)
        let manager = makePlayerManager()

        manager.playQueue([first, second], startingAt: 0)
        manager.next()

        #expect(manager.currentTrack == second)
        #expect(manager.currentIndex == 1)
        #expect(manager.currentTime == 0)
        #expect(manager.duration == 240)
        manager.shutdown()
    }

    @Test func automaticEndAdvancesExactlyOnce() {
        let tracks = [makeTrack(id: "A", duration: 180), makeTrack(id: "B", duration: 240)]
        let manager = makePlayerManager()
        manager.playQueue(tracks, startingAt: 0)

        manager.handleCurrentItemEnded()
        manager.handleCurrentItemEnded()

        #expect(manager.currentTrack == tracks[1])
        #expect(manager.currentIndex == 1)
        manager.shutdown()
    }

    @Test func automaticEndStopsWhenAutoplayIsDisabled() {
        let manager = makePlayerManager()
        manager.isAutoplayEnabled = false
        manager.play(track: makeTrack(id: "A", duration: 180))

        manager.handleCurrentItemEnded()

        #expect(manager.currentIndex == 0)
        #expect(manager.queue.count == 1)
        #expect(!manager.isPlaying)
        manager.shutdown()
    }

    @Test func nextStreamPreloadIsRequestedOnlyOnce() async {
        let repository = RecordingMusicRepository()
        let manager = makePlayerManager(repository: repository)
        manager.playQueue(
            [makeTrack(id: "A", duration: 180), makeTrack(id: "B", duration: 240)],
            startingAt: 0
        )

        manager.triggerPreloadingForTesting(remainingTime: 12)
        await waitUntil { repository.requests(for: "B") == 1 }
        manager.triggerPreloadingForTesting(remainingTime: 10)
        manager.triggerPreloadingForTesting(remainingTime: 5)

        #expect(repository.requests(for: "B") == 1)
        #expect(manager.preloadTargetIDForTesting == "B")
        manager.shutdown()
    }

    @Test func manualTrackHasPriorityWhileQueueStillHasItems() async {
        let service = RecordingRecommendationService(results: [makeTrack(id: "R", duration: 200)])
        let manager = makePlayerManager(recommendationService: service)
        let tracks = [makeTrack(id: "A", duration: 180), makeTrack(id: "B", duration: 240)]

        manager.playQueue(tracks, startingAt: 0)
        #expect(service.callCount == 0)
        manager.next()

        #expect(manager.currentTrack == tracks[1])
        #expect(manager.currentIndex == 1)
        manager.shutdown()
    }

    @Test func queueEndAppendsRecommendationsAndAdvances() async {
        let recommendation = makeTrack(id: "R", duration: 200)
        let service = RecordingRecommendationService(results: [recommendation])
        let manager = makePlayerManager(recommendationService: service)
        manager.play(track: makeTrack(id: "A", duration: 180))
        await waitUntil { service.callCount == 1 }

        manager.handleQueueEnd()
        await waitUntil { manager.currentTrack?.id == "R" }

        #expect(manager.queue.map(\.id) == ["A", "R"])
        #expect(manager.isCurrentTrackRecommended)
        manager.shutdown()
    }

    @Test func emptyRecommendationsFinishPlayback() async {
        let service = RecordingRecommendationService(results: [])
        let manager = makePlayerManager(recommendationService: service)
        manager.play(track: makeTrack(id: "A", duration: 180))
        await waitUntil { service.callCount == 1 }

        manager.handleQueueEnd()
        await waitUntil { !manager.isLoadingRecommendations }

        #expect(!manager.isPlaying)
        #expect(manager.queue.count == 1)
        manager.shutdown()
    }

    private func makePlayerManager(
        repository: any MusicRepositoryProtocol = SuspendedMusicRepository(),
        recommendationService: any MusicRecommendationServiceProtocol = EmptyRecommendationService()
    ) -> PlayerManager {
        PlayerManager(
            repository: repository,
            nowPlayingService: RecordingNowPlayingService(),
            recommendationService: recommendationService
        )
    }

    private func makeTrack(id: String, duration: TimeInterval) -> Track {
        Track(
            id: id,
            youtubeVideoId: id,
            title: "Track \(id)",
            artist: "Artist",
            thumbnailURL: nil,
            duration: duration
        )
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 where !condition() { await Task.yield() }
    }
}

@MainActor
private final class RecordingMusicRepository: MusicRepositoryProtocol {
    private var requestCounts: [String: Int] = [:]

    func search(query: String) async throws -> [Track] { [] }

    func resolvePlaybackURL(videoId: String) async throws -> URL {
        requestCounts[videoId, default: 0] += 1
        try await Task.sleep(for: .seconds(60))
        throw MusicProviderError.cancelled
    }

    func requests(for videoID: String) -> Int { requestCounts[videoID, default: 0] }
}

private struct EmptyRecommendationService: MusicRecommendationServiceProtocol {
    func recommendations(
        basedOn tracks: [Track],
        excluding excludedIDs: Set<String>,
        limit: Int
    ) async throws -> [Track] { [] }
}

@MainActor
private final class RecordingRecommendationService: MusicRecommendationServiceProtocol {
    private(set) var callCount = 0
    let results: [Track]

    init(results: [Track]) { self.results = results }

    func recommendations(
        basedOn tracks: [Track],
        excluding excludedIDs: Set<String>,
        limit: Int
    ) async throws -> [Track] {
        callCount += 1
        return results.filter { !excludedIDs.contains($0.youtubeVideoId) }
    }
}

private struct SuspendedMusicRepository: MusicRepositoryProtocol {
    func search(query: String) async throws -> [Track] { [] }

    func resolvePlaybackURL(videoId: String) async throws -> URL {
        try await Task.sleep(for: .seconds(60))
        throw MusicProviderError.cancelled
    }
}

@MainActor
private final class RecordingNowPlayingService: NowPlayingServiceProtocol {
    func configureRemoteCommands(
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        toggle: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void,
        seek: @escaping @MainActor (TimeInterval) -> Void
    ) {}

    func update(
        track: Track,
        elapsedTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        isPlaybackReady: Bool,
        canGoNext: Bool,
        canGoPrevious: Bool
    ) {}

    func clear() {}
    func shutdown() {}
}
