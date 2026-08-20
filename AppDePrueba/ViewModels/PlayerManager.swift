import AVFoundation
import Observation

@MainActor
@Observable
final class PlayerManager {
    private let repository: any MusicRepositoryProtocol
    private let player = AVPlayer()
    private var playTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    private(set) var currentTrack: Track?
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var errorMessage: String?

    init(repository: any MusicRepositoryProtocol) {
        self.repository = repository
        configureAudioSession()
        installTimeObserver()
    }

    func shutdown() {
        playTask?.cancel()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    func play(track: Track) {
        queue = [track]
        currentIndex = 0
        load(track)
    }

    func playQueue(_ tracks: [Track], startingAt index: Int) {
        guard tracks.indices.contains(index) else { return }
        queue = tracks
        currentIndex = index
        load(tracks[index])
    }

    func pause() { player.pause(); isPlaying = false }
    func resume() { guard player.currentItem != nil else { return }; player.play(); isPlaying = true }
    func togglePlayPause() { isPlaying ? pause() : resume() }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite, seconds >= 0 else { return }
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
    }

    func next() {
        guard let index = currentIndex, queue.indices.contains(index + 1) else { return }
        currentIndex = index + 1
        load(queue[index + 1])
    }

    func previous() {
        guard let index = currentIndex else { return }
        if currentTime > 5 { seek(to: 0); return }
        guard queue.indices.contains(index - 1) else { return }
        currentIndex = index - 1
        load(queue[index - 1])
    }

    var canGoNext: Bool { currentIndex.map { queue.indices.contains($0 + 1) } ?? false }
    var canGoPrevious: Bool { currentIndex.map { queue.indices.contains($0 - 1) } ?? false }

    private func load(_ track: Track) {
        playTask?.cancel()
        player.pause()
        removeEndObserver()
        currentTrack = track
        currentTime = 0
        duration = track.duration
        isLoading = true
        isPlaying = false
        errorMessage = nil

        playTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.repository.resolvePlaybackURL(videoId: track.youtubeVideoId)
                try Task.checkCancellation()
                let item = AVPlayerItem(url: url)
                self.player.replaceCurrentItem(with: item)
                self.installEndObserver(for: item)
                self.player.play()
                self.isPlaying = true
                self.isLoading = false
            } catch is CancellationError {
                return
            } catch MusicProviderError.cancelled {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.isPlaying = false
                self.errorMessage = "No se pudo reproducir esta canción."
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
                if seconds.isFinite { self.currentTime = seconds }
                if let itemDuration = self.player.currentItem?.duration.seconds, itemDuration.isFinite {
                    self.duration = itemDuration
                }
            }
        }
    }

    private func installEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.canGoNext { self.next() }
                else { self.isPlaying = false; self.currentTime = self.duration }
            }
        }
    }

    private func removeEndObserver() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "No se pudo preparar la reproducción de audio."
        }
    }
}
