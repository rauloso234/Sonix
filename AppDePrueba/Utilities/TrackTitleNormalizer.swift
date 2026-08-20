import Foundation

enum TrackTitleNormalizer {
    private static let versionPhrases = [
        "slowed and reverb", "slowed reverb", "sped up", "speed up", "lyric video",
        "official audio", "official video", "music video", "radio edit", "nightcore mix",
        "nightcore", "slowed", "reverb", "lyrics", "lyric", "visualizer", "remastered",
        "remaster", "remix", "cover", "instrumental", "karaoke", "extended", "edit",
        "live", "version", "mix", "audio", "video", "hd", "4k"
    ]
    private static let artistSuffixes = ["official", "music", "records", "recordings"]

    static func canonicalTitle(_ title: String) -> String {
        var value = normalizedText(title)
        value = removingVersionOnlyGroups(from: value)
        for phrase in versionPhrases.sorted(by: { $0.count > $1.count }) {
            value = replacingWholePhrase(phrase, in: value)
        }
        var tokens = collapsed(value).split(separator: " ").map(String.init)
        while tokens.first == "and" { tokens.removeFirst() }
        while tokens.last == "and" { tokens.removeLast() }
        return tokens.joined(separator: " ")
    }

    static func normalizedArtist(_ artist: String) -> String {
        var tokens = normalizedText(artist).split(separator: " ").map(String.init)
        while let last = tokens.last, artistSuffixes.contains(last), tokens.count > 1 { tokens.removeLast() }
        return tokens.joined(separator: " ")
    }

    static func areLikelySameSong(_ lhs: Track, _ rhs: Track) -> Bool {
        let left = canonicalTitle(lhs.title), right = canonicalTitle(rhs.title)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        let leftTokens = Set(left.split(separator: " ").map(String.init))
        let rightTokens = Set(right.split(separator: " ").map(String.init))
        let unionCount = leftTokens.union(rightTokens).count
        guard unionCount > 0 else { return false }
        let similarity = Double(leftTokens.intersection(rightTokens).count) / Double(unionCount)
        let shorter = min(leftTokens.count, rightTokens.count)
        let containment = shorter > 1 && (leftTokens.isSubset(of: rightTokens) || rightTokens.isSubset(of: leftTokens))
        return similarity >= 0.8 || containment
    }

    static func styleTerms(in tracks: [Track]) -> [String] {
        let styles = ["nightcore", "jumpstyle", "hardstyle", "phonk", "house", "techno", "trance",
                      "drum and bass", "dnb", "rock", "metal", "pop", "rap", "hip hop", "reggaeton",
                      "lofi", "chill", "jazz", "punk", "indie", "synthwave", "dance", "edm", "dubstep"]
        let context = normalizedText(tracks.map { "\($0.title) \($0.artist)" }.joined(separator: " "))
        return styles.filter { context.contains($0) }
    }

    private static func normalizedText(_ text: String) -> String {
        collapsed(text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased().replacingOccurrences(of: "+", with: " and ").replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "[^a-z0-9()\\[\\] ]", with: " ", options: .regularExpression))
    }

    private static func removingVersionOnlyGroups(from text: String) -> String {
        var result = text
        guard let regex = try? NSRegularExpression(pattern: "[\\(\\[]([^\\)\\]]+)[\\)\\]]") else { return result }
        for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
            guard let innerRange = Range(match.range(at: 1), in: result), let fullRange = Range(match.range(at: 0), in: result) else { continue }
            if versionPhrases.contains(where: { result[innerRange].contains($0) }) { result.removeSubrange(fullRange) }
        }
        return result
    }

    private static func replacingWholePhrase(_ phrase: String, in text: String) -> String {
        text.replacingOccurrences(of: "(^| )\(NSRegularExpression.escapedPattern(for: phrase))( |$)", with: " ", options: .regularExpression)
    }

    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
    }
}
