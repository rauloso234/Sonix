import Foundation

enum PlaylistSearchNormalizer {
    private static let minimumPrefixLength = 2
    private static let maximumPrefixLength = 12
    private static let maximumTokens = 12

    static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func searchPrefixes(for name: String) -> [String] {
        let words = normalize(name).split(separator: " ").prefix(maximumTokens)
        var prefixes = Set<String>()
        for word in words {
            let cappedWord = String(word.prefix(maximumPrefixLength))
            guard cappedWord.count >= minimumPrefixLength else {
                if !cappedWord.isEmpty { prefixes.insert(cappedWord) }
                continue
            }
            for length in minimumPrefixLength...cappedWord.count {
                prefixes.insert(String(cappedWord.prefix(length)))
            }
        }
        return prefixes.sorted()
    }

    static func queryTerm(_ query: String) -> String? {
        guard let firstWord = normalize(query).split(separator: " ").first else { return nil }
        return String(firstWord.prefix(maximumPrefixLength))
    }
}
