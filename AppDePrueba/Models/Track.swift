import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: String
    let youtubeVideoId: String
    let title: String
    let artist: String
    let thumbnailURL: URL?
    let duration: TimeInterval
    var addedBy: String?
    var addedByName: String?
    var addedAt: Date?
    var position: Int?
}
