import FirebaseAuth
import FirebaseFirestore
import Foundation

protocol RecentlyPlayedServiceProtocol: Sendable {
    func recentTracks(userID: String, limit: Int) async throws -> [Track]
    func record(_ track: Track, userID: String) async throws
}

struct FirestoreRecentlyPlayedService: RecentlyPlayedServiceProtocol {
    func recentTracks(userID: String, limit: Int) async throws -> [Track] {
        guard Auth.auth().currentUser?.uid == userID else { throw AppError.authentication }
        #if DEBUG
        print("[History] Loading recently played for authenticated user")
        #endif
        let snapshot: QuerySnapshot
        do {
            snapshot = try await Firestore.firestore().collection("users").document(userID)
                .collection("recentlyPlayed").order(by: "playedAt", descending: true)
                .limit(to: max(1, min(limit, 20))).getDocuments()
        } catch {
            #if DEBUG
            print("[History] Firestore read error code: \((error as NSError).code)")
            #endif
            throw error
        }
        #if DEBUG
        print("[History] Loaded: \(snapshot.documents.count) tracks")
        #endif
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let title = data["title"] as? String, let artist = data["artist"] as? String else { return nil }
            return Track(
                id: data["videoId"] as? String ?? document.documentID,
                youtubeVideoId: data["videoId"] as? String ?? document.documentID,
                title: title, artist: artist,
                thumbnailURL: (data["thumbnailURL"] as? String).flatMap(URL.init(string:)),
                duration: data["duration"] as? TimeInterval ?? 0,
                addedAt: (data["playedAt"] as? Timestamp)?.dateValue()
            )
        }
    }

    func record(_ track: Track, userID: String) async throws {
        guard Auth.auth().currentUser?.uid == userID else { throw AppError.authentication }
        var data: [String: Any] = [
            "videoId": track.youtubeVideoId, "title": track.title, "artist": track.artist,
            "duration": track.duration, "playedAt": FieldValue.serverTimestamp()
        ]
        if let thumbnailURL = track.thumbnailURL { data["thumbnailURL"] = thumbnailURL.absoluteString }
        #if DEBUG
        print("[History] Saving recently played: \(track.title)")
        #endif
        do {
            try await Firestore.firestore().collection("users").document(userID)
                .collection("recentlyPlayed").document(track.youtubeVideoId).setData(data, merge: true)
            #if DEBUG
            print("[History] Save succeeded")
            #endif
        } catch {
            #if DEBUG
            print("[History] Firestore write error code: \((error as NSError).code)")
            #endif
            throw error
        }
    }
}
