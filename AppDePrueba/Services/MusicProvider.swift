import Foundation
import YouTubeKit

protocol MusicProviderProtocol: Sendable {
    func search(query: String) async throws -> [Track]
    func resolvePlaybackURL(videoId: String) async throws -> URL
}

protocol MusicSearchProviding: Sendable {
    func search(query: String) async throws -> [Track]
}

struct YouTubeKitMusicProvider: MusicProviderProtocol {
    private let searchProvider: any MusicSearchProviding

    init(searchProvider: any MusicSearchProviding) {
        self.searchProvider = searchProvider
    }

    func search(query: String) async throws -> [Track] {
        try await searchProvider.search(query: query)
    }

    func resolvePlaybackURL(videoId: String) async throws -> URL {
        guard !videoId.isEmpty else { throw MusicProviderError.videoUnavailable }
        do {
            let streams = try await YouTube(videoID: videoId, methods: [.local]).streams
            try Task.checkCancellation()
            return try Self.selectBestAudioStream(from: streams).url
        } catch is CancellationError {
            throw MusicProviderError.cancelled
        } catch let error as MusicProviderError {
            throw error
        } catch {
            throw MusicProviderError.streamResolutionFailed
        }
    }

    static func selectBestAudioStream(from streams: [YouTubeKit.Stream]) throws -> YouTubeKit.Stream {
        let audioOnly = streams.filter {
            $0.includesAudioTrack && !$0.includesVideoTrack && $0.isNativelyPlayable
        }
        guard !audioOnly.isEmpty else {
            if streams.contains(where: { $0.includesAudioTrack && !$0.includesVideoTrack }) {
                throw MusicProviderError.noCompatibleStream
            }
            throw MusicProviderError.noAudioStreams
        }
        let preferred = audioOnly.filter { $0.fileExtension == .m4a }
        guard let result = (preferred.isEmpty ? audioOnly : preferred)
            .max(by: { ($0.averageBitrate ?? $0.bitrate ?? 0) < ($1.averageBitrate ?? $1.bitrate ?? 0) }) else {
            throw MusicProviderError.noCompatibleStream
        }
        return result
    }
}

struct PipedSearchConfiguration: Sendable {
    let baseURL: URL
    static let production = PipedSearchConfiguration(
        baseURL: URL(string: "https://api.piped.private.coffee")!
    )
}

struct PipedSearchProvider: MusicSearchProviding {
    private let configuration: PipedSearchConfiguration
    private let session: URLSession

    init(configuration: PipedSearchConfiguration = .production) {
        self.configuration = configuration
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func search(query: String) async throws -> [Track] {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "filter", value: "videos")
        ]
        guard let url = components?.url else { throw MusicProviderError.invalidResponse }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw MusicProviderError.invalidResponse
            }
            return try JSONDecoder().decode(PipedSearchResponse.self, from: data).items.compactMap(Track.init(piped:))
        } catch is CancellationError {
            throw MusicProviderError.cancelled
        } catch let error as MusicProviderError {
            throw error
        } catch {
            throw MusicProviderError.network
        }
    }
}

private struct PipedSearchResponse: Decodable { let items: [PipedSearchItem] }
private struct PipedSearchItem: Decodable {
    let url: String
    let type: String
    let title: String
    let thumbnail: URL?
    let uploaderName: String?
    let duration: TimeInterval?
}

private extension Track {
    init?(piped item: PipedSearchItem) {
        guard item.type == "stream", let videoId = VideoIDExtractor.extract(from: item.url) else { return nil }
        self.init(id: videoId, youtubeVideoId: videoId, title: item.title,
                  artist: item.uploaderName ?? "Canal desconocido", thumbnailURL: item.thumbnail,
                  duration: item.duration ?? 0, addedBy: nil, addedByName: nil, addedAt: nil, position: nil)
    }
}
