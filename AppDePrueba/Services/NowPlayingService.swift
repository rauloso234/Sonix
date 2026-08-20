import Foundation
import MediaPlayer
import UIKit

@MainActor
protocol NowPlayingServiceProtocol: AnyObject {
    func configureRemoteCommands(
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        toggle: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void,
        seek: @escaping @MainActor (TimeInterval) -> Void
    )
    func update(
        track: Track,
        elapsedTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        isPlaybackReady: Bool,
        canGoNext: Bool,
        canGoPrevious: Bool
    )
    func clear()
    func shutdown()
}

@MainActor
final class SystemNowPlayingService: NowPlayingServiceProtocol {
    private struct RemoteTarget {
        let command: MPRemoteCommand
        let token: Any
    }

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var remoteTargets: [RemoteTarget] = []
    private var artworkTask: Task<Void, Never>?
    private var currentTrackID: String?
    private var currentArtwork: MPMediaItemArtwork?

    func configureRemoteCommands(
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        toggle: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void,
        seek: @escaping @MainActor (TimeInterval) -> Void
    ) {
        guard remoteTargets.isEmpty else { return }

        addTarget(to: commandCenter.playCommand) { _ in
            Task { @MainActor in play() }
            return .success
        }
        addTarget(to: commandCenter.pauseCommand) { _ in
            Task { @MainActor in pause() }
            return .success
        }
        addTarget(to: commandCenter.togglePlayPauseCommand) { _ in
            Task { @MainActor in toggle() }
            return .success
        }
        addTarget(to: commandCenter.nextTrackCommand) { _ in
            Task { @MainActor in next() }
            return .success
        }
        addTarget(to: commandCenter.previousTrackCommand) { _ in
            Task { @MainActor in previous() }
            return .success
        }
        addTarget(to: commandCenter.changePlaybackPositionCommand) { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in seek(positionEvent.positionTime) }
            return .success
        }
    }

    func update(
        track: Track,
        elapsedTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        isPlaybackReady: Bool,
        canGoNext: Bool,
        canGoPrevious: Bool
    ) {
        if currentTrackID != track.id {
            currentTrackID = track.id
            currentArtwork = nil
            loadArtwork(for: track)
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: max(duration, 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(elapsedTime, 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let currentArtwork { info[MPMediaItemPropertyArtwork] = currentArtwork }
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused

        commandCenter.playCommand.isEnabled = isPlaybackReady && !isPlaying
        commandCenter.pauseCommand.isEnabled = isPlaying
        commandCenter.togglePlayPauseCommand.isEnabled = isPlaybackReady
        commandCenter.nextTrackCommand.isEnabled = canGoNext
        commandCenter.previousTrackCommand.isEnabled = canGoPrevious || elapsedTime > 0
        commandCenter.changePlaybackPositionCommand.isEnabled = isPlaybackReady && duration > 0
    }

    func clear() {
        artworkTask?.cancel()
        artworkTask = nil
        currentTrackID = nil
        currentArtwork = nil
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
    }

    func shutdown() {
        clear()
        for target in remoteTargets { target.command.removeTarget(target.token) }
        remoteTargets.removeAll()
    }

    private func addTarget(
        to command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let token = command.addTarget(handler: handler)
        remoteTargets.append(RemoteTarget(command: command, token: token))
    }

    private func loadArtwork(for track: Track) {
        artworkTask?.cancel()
        guard let url = track.thumbnailURL else { return }
        let trackID = track.id

        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let image = UIImage(data: data),
                      let self,
                      self.currentTrackID == trackID else { return }

                self.currentArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                if var info = self.infoCenter.nowPlayingInfo {
                    info[MPMediaItemPropertyArtwork] = self.currentArtwork
                    self.infoCenter.nowPlayingInfo = info
                }
            } catch {
                // La carátula es opcional; los metadatos y controles siguen disponibles.
            }
        }
    }
}
