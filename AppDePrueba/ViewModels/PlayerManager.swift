import AVFoundation
import Observation

@MainActor
@Observable
final class PlayerManager {
    static let nextTrackPreloadThreshold: TimeInterval = 12
    static let recommendationMetadataPreloadThreshold: TimeInterval = 20

    private struct PreloadedPlayback {
        let trackID: String
        let item: AVPlayerItem
        let sessionID: UUID
    }

    private let repository: any MusicRepositoryProtocol
    private let nowPlayingService: any NowPlayingServiceProtocol
    private let recommendationService: any MusicRecommendationServiceProtocol
    private let historyRepository: (any RecentlyPlayedRepositoryProtocol)?
    private let currentUserID: @MainActor () -> String?
    private let player = AVPlayer()
    private var playTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failedToEndObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var audioSessionObservers: [NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false
    private var loggedDurationItemID: ObjectIdentifier?
    private var failedToEndRetryCount = 0
    private var recommendationTask: Task<Void, Never>?
    private var playbackSessionID = UUID()
    private var prefetchedRecommendations: [Track] = []
    private var recommendedTrackIDs = Set<String>()
    private var recentlyPlayedTracks: [Track] = []
    private var lastPersistedTrackID: String?
    private var isAwaitingRecommendations = false
    private var hasHandledCurrentItemEnd = false
    private var preloadTask: Task<Void, Never>?
    private var preloadedPlayback: PreloadedPlayback?
    private var preloadTargetID: String?
    private var failedPreloadTrackID: String?

    private(set) var currentTrack: Track?
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isLoadingRecommendations = false
    var isAutoplayEnabled = true
    var errorMessage: String?

    init(
        repository: any MusicRepositoryProtocol,
        nowPlayingService: any NowPlayingServiceProtocol,
        recommendationService: any MusicRecommendationServiceProtocol,
        historyRepository: (any RecentlyPlayedRepositoryProtocol)? = nil,
        currentUserID: @escaping @MainActor () -> String? = { nil }
    ) {
        self.repository = repository
        self.nowPlayingService = nowPlayingService
        self.recommendationService = recommendationService
        self.historyRepository = historyRepository
        self.currentUserID = currentUserID
        configureAudioSession()
        installTimeObserver()
        installAudioSessionObservers()
        configureRemoteCommands()
    }

    func shutdown() {
        playTask?.cancel()
        recommendationTask?.cancel()
        preloadTask?.cancel()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        removeItemObservers()
        audioSessionObservers.forEach(NotificationCenter.default.removeObserver)
        audioSessionObservers.removeAll()
        nowPlayingService.shutdown()
    }

    func play(track: Track) {
        beginNewPlaybackSession()
        queue = [track]
        currentIndex = 0
        load(track)
    }

    func playQueue(_ tracks: [Track], startingAt index: Int) {
        guard tracks.indices.contains(index) else { return }
        beginNewPlaybackSession()
        queue = tracks
        currentIndex = index
        load(tracks[index])
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard player.currentItem != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }
    func togglePlayPause() { isPlaying ? pause() : resume() }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite, seconds >= 0,
              duration.isFinite, duration > 0 else { return }
        let clampedSeconds = min(seconds, duration)
        player.seek(to: CMTime(seconds: clampedSeconds, preferredTimescale: 600))
        currentTime = clampedSeconds
        updateNowPlaying()
    }

    func next() {
        if let nextIndex = PlaybackQueueLogic.nextIndex(
            currentIndex: currentIndex,
            queueCount: queue.count
        ) {
            currentIndex = nextIndex
            load(queue[nextIndex])
        } else {
            handleQueueEnd()
        }
    }

    func previous() {
        guard let index = currentIndex else { return }
        if currentTime > 5 { seek(to: 0); return }
        guard let previousIndex = PlaybackQueueLogic.previousIndex(
            currentIndex: index,
            queueCount: queue.count
        ) else { return }
        currentIndex = previousIndex
        load(queue[previousIndex])
    }

    var canGoNext: Bool {
        PlaybackQueueLogic.nextIndex(currentIndex: currentIndex, queueCount: queue.count) != nil
    }
    var canGoPrevious: Bool {
        PlaybackQueueLogic.previousIndex(currentIndex: currentIndex, queueCount: queue.count) != nil
    }
    var canAdvance: Bool { canGoNext || isAutoplayEnabled }
    var isCurrentTrackRecommended: Bool {
        currentTrack.map { recommendedTrackIDs.contains($0.youtubeVideoId) } ?? false
    }

    private func load(_ track: Track, isRetry: Bool = false) {
        let preloadedItem = takePreloadedItem(for: track)
        playTask?.cancel()
        if preloadedItem == nil { clearPlaybackPreload() }
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeItemObservers()
        currentTime = 0
        duration = 0
        loggedDurationItemID = nil
        hasHandledCurrentItemEnd = false
        if !isRetry { failedToEndRetryCount = 0 }
        currentTrack = track
        duration = Self.effectiveDuration(metadataDuration: track.duration, assetDuration: nil)
        isLoading = true
        isPlaying = false
        errorMessage = nil
        isLoadingRecommendations = false
        isAwaitingRecommendations = false
        debugTrack(track)
        updateNowPlaying()

        if let preloadedItem {
            #if DEBUG
            print("[Player] Using preloaded item: \(track.title)")
            #endif
            player.replaceCurrentItem(with: preloadedItem)
            installItemObservers(for: preloadedItem)
            return
        }

        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.repository.resolvePlaybackURL(videoId: track.youtubeVideoId)
                try Task.checkCancellation()
                let item = AVPlayerItem(url: url)
                self.player.replaceCurrentItem(with: item)
                self.installItemObservers(for: item)
            } catch is CancellationError {
                return
            } catch MusicProviderError.cancelled {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.isPlaying = false
                self.errorMessage = "No se pudo reproducir esta canción."
                self.updateNowPlaying()
            }
        }
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite, seconds >= 0 {
                    self.currentTime = self.duration > 0 ? min(seconds, self.duration) : seconds
                    self.handlePreloading(remainingTime: max(0, self.duration - self.currentTime))
                    if self.isPlaying,
                       self.duration > 0,
                       seconds >= self.duration - 0.15 {
                        self.handleCurrentItemEnded()
                    }
                }
            }
        }
    }

    private func installItemObservers(for item: AVPlayerItem) {
        removeItemObservers()
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, let item, self.player.currentItem === item else { return }
                    self.handleStatusChange(for: item)
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.handleCurrentItemEnded()
            }
        }
        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, self.player.currentItem === item else { return }
                self.handleFailureToPlayToEnd(notification)
            }
        }
    }

    private func removeItemObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        if let failedToEndObserver { NotificationCenter.default.removeObserver(failedToEndObserver) }
        failedToEndObserver = nil
    }

    private func handleStatusChange(for item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            let itemDuration = item.duration.seconds
            duration = Self.effectiveDuration(
                metadataDuration: currentTrack?.duration ?? 0,
                assetDuration: itemDuration
            )
            debugDurationsIfNeeded(for: item, itemDuration: itemDuration)
            player.play()
            isPlaying = true
            isLoading = false
            recordSuccessfulPlaybackIfNeeded()
            updateNowPlaying()
        case .failed:
            isLoading = false
            isPlaying = false
            errorMessage = "No se pudo preparar esta canción para reproducirla."
            updateNowPlaying()
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handleFailureToPlayToEnd(_ notification: Notification) {
        #if DEBUG
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
        print("[Player] Failed to play to end: \(String(describing: error))")
        #endif
        guard failedToEndRetryCount == 0, let currentTrack else {
            isPlaying = false
            isLoading = false
            errorMessage = "La reproducción se interrumpió antes de terminar."
            updateNowPlaying()
            return
        }
        failedToEndRetryCount = 1
        load(currentTrack, isRetry: true)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "No se pudo preparar la reproducción de audio."
        }
    }

    private func installAudioSessionObservers() {
        let center = NotificationCenter.default
        audioSessionObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { self?.handleAudioInterruption(notification) }
        })
        audioSessionObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { self?.handleRouteChange(notification) }
        })
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            pause()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            guard wasPlayingBeforeInterruption, options.contains(.shouldResume) else {
                wasPlayingBeforeInterruption = false
                return
            }
            wasPlayingBeforeInterruption = false
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                resume()
            } catch {
                errorMessage = "No se pudo reanudar el audio después de la interrupción."
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
              reason == .oldDeviceUnavailable else { return }
        pause()
    }

    private func configureRemoteCommands() {
        nowPlayingService.configureRemoteCommands(
            play: { [weak self] in self?.resume() },
            pause: { [weak self] in self?.pause() },
            toggle: { [weak self] in self?.togglePlayPause() },
            next: { [weak self] in self?.next() },
            previous: { [weak self] in self?.previous() },
            seek: { [weak self] seconds in self?.seek(to: seconds) }
        )
    }

    private func updateNowPlaying() {
        guard let currentTrack else {
            nowPlayingService.clear()
            return
        }
        nowPlayingService.update(
            track: currentTrack,
            elapsedTime: currentTime,
            duration: duration,
            isPlaying: isPlaying,
            isPlaybackReady: player.currentItem != nil && !isLoading,
            canGoNext: canAdvance,
            canGoPrevious: canGoPrevious
        )
    }

    private func beginNewPlaybackSession() {
        recommendationTask?.cancel()
        recommendationTask = nil
        playbackSessionID = UUID()
        prefetchedRecommendations = []
        recommendedTrackIDs = []
        isAwaitingRecommendations = false
        isLoadingRecommendations = false
        clearPlaybackPreload()
    }

    private func recordSuccessfulPlaybackIfNeeded() {
        guard let currentTrack, lastPersistedTrackID != currentTrack.youtubeVideoId else { return }
        lastPersistedTrackID = currentTrack.youtubeVideoId
        recentlyPlayedTracks.removeAll { $0.youtubeVideoId == currentTrack.youtubeVideoId }
        recentlyPlayedTracks.append(currentTrack)
        if recentlyPlayedTracks.count > 75 {
            recentlyPlayedTracks.removeFirst(recentlyPlayedTracks.count - 75)
        }
        guard let historyRepository, let userID = currentUserID() else { return }
        Task { try? await historyRepository.record(currentTrack, userID: userID) }
    }

    private func prefetchRecommendationsIfNeeded() {
        guard isAutoplayEnabled,
              let currentIndex,
              currentIndex == queue.count - 1,
              recommendationTask == nil,
              prefetchedRecommendations.isEmpty else { return }
        let sessionID = playbackSessionID
        let context = Array((recentlyPlayedTracks + queue).suffix(10))
        let excluded = Set(queue.map(\.youtubeVideoId)).union(recentlyPlayedTracks.map(\.youtubeVideoId))

        #if DEBUG
        print("[Autoplay] Loading recommendations")
        #endif

        recommendationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let tracks = try await self.recommendationService.recommendations(
                    basedOn: context,
                    excluding: excluded,
                    limit: 10
                )
                try Task.checkCancellation()
                guard self.playbackSessionID == sessionID else { return }
                self.prefetchedRecommendations = tracks
                self.recommendationTask = nil
                #if DEBUG
                print("[Autoplay] Recommendations ready: \(tracks.count)")
                #endif
                if self.duration - self.currentTime <= Self.nextTrackPreloadThreshold {
                    self.preloadNextTrackIfNeeded()
                }
                if self.isAwaitingRecommendations { self.consumeRecommendationsOrFinish() }
            } catch {
                guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                self.recommendationTask = nil
                self.prefetchedRecommendations = []
                if self.isAwaitingRecommendations { self.finishPlaybackAtQueueEnd() }
            }
        }
    }

    func handleQueueEnd() {
        if let nextIndex = PlaybackQueueLogic.nextIndex(currentIndex: currentIndex, queueCount: queue.count) {
            currentIndex = nextIndex
            load(queue[nextIndex])
            return
        }
        guard isAutoplayEnabled else {
            finishPlaybackAtQueueEnd()
            return
        }
        isAwaitingRecommendations = true
        isLoadingRecommendations = true
        isPlaying = false
        currentTime = duration
        updateNowPlaying()
        if prefetchedRecommendations.isEmpty {
            prefetchRecommendationsIfNeeded()
        } else {
            consumeRecommendationsOrFinish()
        }
    }

    func handleCurrentItemEnded() {
        guard !hasHandledCurrentItemEnd else { return }
        hasHandledCurrentItemEnd = true
        #if DEBUG
        print("""
        [Player] Current track ended: \(currentTrack?.title ?? "Desconocida")
        [Player] currentIndex: \(String(describing: currentIndex))
        [Player] queue.count: \(queue.count)
        [Player] hasNext: \(canGoNext)
        """)
        #endif
        handleQueueEnd()
    }

    // Internal hooks keep timing tests deterministic without exposing playback state to the UI.
    func triggerPreloadingForTesting(remainingTime: TimeInterval) {
        handlePreloading(remainingTime: remainingTime)
    }

    var preloadTargetIDForTesting: String? {
        preloadedPlayback?.trackID ?? preloadTargetID ?? failedPreloadTrackID
    }

    private func consumeRecommendationsOrFinish() {
        let existingIDs = Set(queue.map(\.youtubeVideoId))
        let additions = prefetchedRecommendations.filter { !existingIDs.contains($0.youtubeVideoId) }
        prefetchedRecommendations = []
        guard !additions.isEmpty else {
            finishPlaybackAtQueueEnd()
            return
        }
        queue.append(contentsOf: additions)
        recommendedTrackIDs.formUnion(additions.map(\.youtubeVideoId))
        isAwaitingRecommendations = false
        isLoadingRecommendations = false
        next()
    }

    private func finishPlaybackAtQueueEnd() {
        isAwaitingRecommendations = false
        isLoadingRecommendations = false
        isPlaying = false
        currentTime = duration
        updateNowPlaying()
    }

    private func handlePreloading(remainingTime: TimeInterval) {
        guard remainingTime.isFinite, remainingTime >= 0 else { return }
        if isAutoplayEnabled,
           !canGoNext,
           remainingTime <= Self.recommendationMetadataPreloadThreshold {
            prefetchRecommendationsIfNeeded()
        }
        if remainingTime <= Self.nextTrackPreloadThreshold {
            preloadNextTrackIfNeeded()
        }
    }

    private func preloadNextTrackIfNeeded() {
        guard let track = nextTrackCandidateForPreload(),
              track.youtubeVideoId != currentTrack?.youtubeVideoId,
              failedPreloadTrackID != track.youtubeVideoId,
              preloadedPlayback?.trackID != track.youtubeVideoId,
              preloadTargetID != track.youtubeVideoId else { return }

        clearPlaybackPreload()
        let sessionID = playbackSessionID
        let trackID = track.youtubeVideoId
        preloadTargetID = trackID
        #if DEBUG
        print("[Player] Preloading next: \(track.title)")
        #endif

        preloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.repository.resolvePlaybackURL(videoId: trackID)
                try Task.checkCancellation()
                let item = AVPlayerItem(url: url)
                let isPlayable = try await item.asset.load(.isPlayable)
                try Task.checkCancellation()
                guard isPlayable,
                      self.playbackSessionID == sessionID,
                      self.nextTrackCandidateForPreload()?.youtubeVideoId == trackID else { return }
                self.preloadedPlayback = PreloadedPlayback(
                    trackID: trackID,
                    item: item,
                    sessionID: sessionID
                )
                self.preloadTargetID = nil
                self.preloadTask = nil
                #if DEBUG
                print("[Player] Next item ready: \(track.title)")
                #endif
            } catch {
                guard !Task.isCancelled, self.playbackSessionID == sessionID else { return }
                self.failedPreloadTrackID = trackID
                self.preloadTargetID = nil
                self.preloadTask = nil
            }
        }
    }

    private func nextTrackCandidateForPreload() -> Track? {
        if let currentIndex,
           let nextIndex = PlaybackQueueLogic.nextIndex(currentIndex: currentIndex, queueCount: queue.count) {
            return queue[nextIndex]
        }
        guard isAutoplayEnabled else { return nil }
        return prefetchedRecommendations.first
    }

    private func takePreloadedItem(for track: Track) -> AVPlayerItem? {
        guard let preloadedPlayback,
              preloadedPlayback.sessionID == playbackSessionID,
              preloadedPlayback.trackID == track.youtubeVideoId else { return nil }
        let item = preloadedPlayback.item
        self.preloadedPlayback = nil
        preloadTask?.cancel()
        preloadTask = nil
        preloadTargetID = nil
        failedPreloadTrackID = nil
        return item
    }

    private func clearPlaybackPreload() {
        preloadTask?.cancel()
        preloadTask = nil
        preloadedPlayback = nil
        preloadTargetID = nil
        failedPreloadTrackID = nil
    }

    static func effectiveDuration(
        metadataDuration: TimeInterval,
        assetDuration: TimeInterval?
    ) -> TimeInterval {
        let metadataIsValid = metadataDuration.isFinite && metadataDuration > 0
        let assetIsValid = assetDuration.map { $0.isFinite && $0 > 0 } ?? false

        guard metadataIsValid else { return assetIsValid ? assetDuration! : 0 }
        guard assetIsValid, let assetDuration else { return metadataDuration }

        let acceptableDifference = max(5, metadataDuration * 0.1)
        return abs(assetDuration - metadataDuration) <= acceptableDifference
            ? assetDuration
            : metadataDuration
    }

    private func debugTrack(_ track: Track) {
        #if DEBUG
        print("""
        [Player] Track title: \(track.title)
        [Player] Track videoId: \(track.youtubeVideoId)
        [Player] Track.duration: \(track.duration)
        """)
        #endif
    }

    private func debugDurationsIfNeeded(for item: AVPlayerItem, itemDuration: TimeInterval) {
        #if DEBUG
        let itemID = ObjectIdentifier(item)
        guard loggedDurationItemID != itemID else { return }
        loggedDurationItemID = itemID
        let currentSeconds = player.currentTime().seconds
        print("""
        [Player] AVPlayerItem.duration: \(itemDuration)
        [Player] Asset duration: se carga de forma asíncrona
        [Player] currentTime: \(currentSeconds)
        """)
        Task { [weak self, weak item] in
            guard let item,
                  let assetTime = try? await item.asset.load(.duration),
                  let self,
                  self.player.currentItem === item else { return }
            print("[Player] Asset duration: \(assetTime.seconds)")
        }
        #endif
    }
}
