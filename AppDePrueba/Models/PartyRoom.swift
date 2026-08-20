import Foundation

struct PartyRoom: Identifiable, Codable, Hashable {
    let id: String
    let hostUserId: String
    let joinCode: String
    let createdAt: Date
    var status: PartyRoomStatus
}

enum PartyRoomStatus: String, Codable {
    case waiting
    case active
    case ended
}
