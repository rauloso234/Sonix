import Foundation

enum VideoIDExtractor {
    static func extract(from value: String) -> String? {
        guard let components = URLComponents(string: value),
              let videoId = components.queryItems?.first(where: { $0.name == "v" })?.value,
              !videoId.isEmpty else { return nil }
        return videoId
    }
}
