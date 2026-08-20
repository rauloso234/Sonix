import Foundation

protocol MusicRecommendationServiceProtocol: Sendable {
    func recommendations(
        basedOn tracks: [Track],
        excluding excludedIDs: Set<String>,
        limit: Int
    ) async throws -> [Track]
}

struct MusicRecommendationService: MusicRecommendationServiceProtocol {
    private let repository: any MusicRepositoryProtocol

    init(repository: any MusicRepositoryProtocol) {
        self.repository = repository
    }

    func recommendations(
        basedOn tracks: [Track],
        excluding excludedIDs: Set<String>,
        limit: Int
    ) async throws -> [Track] {
        let limit = max(1, min(limit, 20))
        let context = Array(tracks.suffix(10))
        guard !context.isEmpty else { return [] }
        var resultGroups: [[Track]] = []
        let queries = recommendationQueries(for: context)
        for query in queries {
            try Task.checkCancellation()
            do {
                let results = try await repository.search(query: query)
                resultGroups.append(results)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }

        let candidates = interleaved(resultGroups)
        let result = filterAndRank(candidates: candidates, context: context, excludedIDs: excludedIDs, limit: limit)
        #if DEBUG
        print("[Recommendations] Current: \(context.last.map { TrackTitleNormalizer.canonicalTitle($0.title) } ?? "")")
        print("[Recommendations] Candidates: \(candidates.count)")
        print("[Recommendations] Final recommendations: \(result.count)")
        #endif
        return result
    }

    func filterAndRank(candidates: [Track], context: [Track], excludedIDs: Set<String>, limit: Int) -> [Track] {
        let contextStyles = Set(TrackTitleNormalizer.styleTerms(in: context))
        let contextArtists = Set(context.map { TrackTitleNormalizer.normalizedArtist($0.artist) })
        var usedIDs = excludedIDs
        var usedTitles = Set(context.map { TrackTitleNormalizer.canonicalTitle($0.title) })
        var rejectedSameSong = 0
        var unique: [(track: Track, score: Int)] = []
        for candidate in candidates {
            let canonical = TrackTitleNormalizer.canonicalTitle(candidate.title)
            guard !candidate.youtubeVideoId.isEmpty, !usedIDs.contains(candidate.youtubeVideoId), !canonical.isEmpty else { continue }
            guard !usedTitles.contains(canonical),
                  !context.contains(where: { TrackTitleNormalizer.areLikelySameSong($0, candidate) }) else {
                rejectedSameSong += 1
                continue
            }
            usedIDs.insert(candidate.youtubeVideoId)
            usedTitles.insert(canonical)
            let candidateStyles = Set(TrackTitleNormalizer.styleTerms(in: [candidate]))
            let artist = TrackTitleNormalizer.normalizedArtist(candidate.artist)
            var score = candidateStyles.intersection(contextStyles).count * 4
            if !contextArtists.contains(artist) { score += 3 }
            if !artist.isEmpty { score += 1 }
            unique.append((candidate, score))
        }
        let ranked = unique.sorted { $0.score == $1.score ? $0.track.title < $1.track.title : $0.score > $1.score }.map(\.track)
        let result = diversifyArtists(ranked, limit: limit)
        #if DEBUG
        print("[Recommendations] Rejected same song: \(rejectedSameSong)")
        print("[Recommendations] Artists after diversity: \(Set(result.map { TrackTitleNormalizer.normalizedArtist($0.artist) }).count)")
        #endif
        return result
    }

    func diversifyArtists(_ candidates: [Track], limit: Int) -> [Track] {
        var pending = candidates
        var result: [Track] = []
        var lastArtist: String?
        while !pending.isEmpty && result.count < limit {
            let index = pending.firstIndex { TrackTitleNormalizer.normalizedArtist($0.artist) != lastArtist } ?? pending.startIndex
            let selected = pending.remove(at: index)
            result.append(selected)
            lastArtist = TrackTitleNormalizer.normalizedArtist(selected.artist)
        }
        return result
    }

    private func recommendationQueries(for context: [Track]) -> [String] {
        var queries: [String] = []
        let styles = TrackTitleNormalizer.styleTerms(in: context)
        if !styles.isEmpty {
            queries.append(styles.prefix(2).joined(separator: " ") + " music")
            if let first = styles.first { queries.append("\(first) songs") }
        }
        var artists = Set<String>()
        for track in context.reversed() {
            let artist = TrackTitleNormalizer.normalizedArtist(track.artist)
            if !artist.isEmpty, artists.insert(artist).inserted { queries.append("\(track.artist) similar artists music") }
            if queries.count >= 4 { break }
        }
        if queries.isEmpty, let last = context.last {
            queries = ["\(last.artist) similar music", "\(TrackTitleNormalizer.canonicalTitle(last.title)) related songs"]
        }
        return Array(queries.prefix(4))
    }

    private func interleaved(_ groups: [[Track]]) -> [Track] {
        guard let largest = groups.map(\.count).max() else { return [] }
        return (0..<largest).flatMap { index in groups.compactMap { $0.indices.contains(index) ? $0[index] : nil } }
    }
}
