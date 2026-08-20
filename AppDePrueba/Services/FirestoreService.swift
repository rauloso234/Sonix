import FirebaseAuth
import FirebaseFirestore
import Foundation

enum PlaylistServiceError: Error, Equatable {
    case unauthenticated, invalidInviteCode, inviteNotFound, inviteInactive
    case alreadyMember, notCollaborative, inviteCollision
    case duplicateTrack
}

protocol FirestoreServiceProtocol {
    func createPlaylist(name: String, description: String, isCollaborative: Bool, owner: AppUser) async throws -> Playlist
    func observeLibrary(userId: String, onChange: @escaping (Result<PlaylistLibrary, Error>) -> Void) -> ListenerRegistration?
    func observeTracks(playlistId: String, onChange: @escaping (Result<[Track], Error>) -> Void) -> ListenerRegistration
    func observeMembers(playlistId: String, onChange: @escaping (Result<[PlaylistMember], Error>) -> Void) -> ListenerRegistration
    func joinPlaylist(code: String, user: AppUser) async throws -> Playlist
    func addTrack(_ track: Track, to playlist: Playlist, user: AppUser) async throws
}

final class FirestoreService: FirestoreServiceProtocol {
    private var database: Firestore { Firestore.firestore() }

    func createPlaylist(name: String, description: String, isCollaborative: Bool, owner: AppUser) async throws -> Playlist {
        guard let userId = Auth.auth().currentUser?.uid, userId == owner.id else {
            throw PlaylistServiceError.unauthenticated
        }

        for _ in 0..<8 {
            let reference = database.collection("playlists").document()
            let playlist = Playlist(
                id: reference.documentID, name: name, description: description,
                ownerId: userId, imageURL: nil,
                joinCode: isCollaborative ? JoinCodeGenerator.generate() : nil,
                isCollaborative: isCollaborative, visibility: .privateOnly,
                createdAt: .now, updatedAt: .now, trackCount: 0, memberCount: 1
            )
            do {
                try await createPlaylistTransaction(playlist: playlist, owner: owner, reference: reference)
                return playlist
            } catch PlaylistServiceError.inviteCollision {
                continue
            }
        }
        throw PlaylistServiceError.inviteCollision
    }

    func observeLibrary(userId: String, onChange: @escaping (Result<PlaylistLibrary, Error>) -> Void) -> ListenerRegistration? {
        guard !userId.isEmpty, Auth.auth().currentUser?.uid == userId else {
            Task { @MainActor in onChange(.failure(PlaylistServiceError.unauthenticated)) }
            return nil
        }

        return database.collection("userPlaylists").document(userId).collection("items")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in onChange(.failure(error)) }
                    return
                }
                let entries = snapshot?.documents.compactMap(UserPlaylistEntry.init(document:)) ?? []
                Task {
                    guard let self else { return }
                    do {
                        var library = PlaylistLibrary.empty
                        for entry in entries {
                            let document = try await self.database.collection("playlists").document(entry.playlistId).getDocument()
                            guard let playlist = Playlist(document: document) else { continue }
                            if entry.type == .owned { library.owned.append(playlist) }
                            else { library.collaborative.append(playlist) }
                        }
                        // Compatibilidad con playlists creadas antes de existir userPlaylists.
                        let legacyOwned = try await self.database.collection("playlists")
                            .whereField("ownerId", isEqualTo: userId).getDocuments()
                            .documents.compactMap(Playlist.init(document:))
                        let indexedOwnedIds = Set(library.owned.map(\.id))
                        library.owned.append(contentsOf: legacyOwned.filter { !indexedOwnedIds.contains($0.id) })
                        library.owned.sort { $0.updatedAt > $1.updatedAt }
                        library.collaborative.sort { $0.updatedAt > $1.updatedAt }
                        await MainActor.run { onChange(.success(library)) }
                    } catch {
                        await MainActor.run { onChange(.failure(error)) }
                    }
                }
            }
    }

    func observeTracks(playlistId: String, onChange: @escaping (Result<[Track], Error>) -> Void) -> ListenerRegistration {
        database.collection("playlists").document(playlistId).collection("tracks")
            .order(by: "position")
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error { onChange(.failure(error)); return }
                    onChange(.success(snapshot?.documents.compactMap(Track.init(document:)) ?? []))
                }
            }
    }

    func observeMembers(playlistId: String, onChange: @escaping (Result<[PlaylistMember], Error>) -> Void) -> ListenerRegistration {
        database.collection("playlists").document(playlistId).collection("members")
            .order(by: "joinedAt")
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error { onChange(.failure(error)); return }
                    onChange(.success(snapshot?.documents.compactMap(PlaylistMember.init(document:)) ?? []))
                }
            }
    }

    func joinPlaylist(code: String, user: AppUser) async throws -> Playlist {
        guard let userId = Auth.auth().currentUser?.uid, userId == user.id else {
            throw PlaylistServiceError.unauthenticated
        }
        let code = JoinCodeGenerator.normalize(code)
        guard JoinCodeGenerator.isValid(code) else { throw PlaylistServiceError.invalidInviteCode }

        let invite = try await database.collection("playlistInvites").document(code).getDocument()
        guard invite.exists, let data = invite.data(), let playlistId = data["playlistId"] as? String else {
            throw PlaylistServiceError.inviteNotFound
        }
        guard data["active"] as? Bool == true else { throw PlaylistServiceError.inviteInactive }

        let playlistReference = database.collection("playlists").document(playlistId)
        guard let playlist = Playlist(document: try await playlistReference.getDocument()) else {
            throw PlaylistServiceError.inviteNotFound
        }
        guard playlist.isCollaborative else { throw PlaylistServiceError.notCollaborative }
        let memberReference = playlistReference.collection("members").document(userId)
        guard try await !memberReference.getDocument().exists else { throw PlaylistServiceError.alreadyMember }

        let batch = database.batch()
        var member: [String: Any] = [
            "userId": userId, "displayName": user.displayName,
            "role": PlaylistRole.editor.rawValue, "inviteCode": code,
            "joinedAt": FieldValue.serverTimestamp()
        ]
        if let photoURL = user.photoURL { member["photoURL"] = photoURL.absoluteString }
        batch.setData(member, forDocument: memberReference)
        batch.setData(indexData(playlistId: playlistId, role: .editor, type: .collaborative),
                      forDocument: database.collection("userPlaylists").document(userId).collection("items").document(playlistId))
        try await batch.commit()
        return playlist
    }

    func addTrack(_ track: Track, to playlist: Playlist, user: AppUser) async throws {
        guard let userId = Auth.auth().currentUser?.uid, userId == user.id else {
            throw PlaylistServiceError.unauthenticated
        }
        let playlistReference = database.collection("playlists").document(playlist.id)
        let trackReference = playlistReference.collection("tracks").document(track.youtubeVideoId)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let playlistSnapshot = try transaction.getDocument(playlistReference)
                    let trackSnapshot = try transaction.getDocument(trackReference)
                    if trackSnapshot.exists {
                        errorPointer?.pointee = NSError(domain: "DuplicatePlaylistTrack", code: 1)
                        return nil
                    }
                    let playlistData = playlistSnapshot.data() ?? [:]
                    let trackCount = playlistData["trackCount"] as? Int ?? 0
                    let position = playlistData["nextTrackPosition"] as? Int ?? trackCount
                    var data: [String: Any] = [
                        "id": track.youtubeVideoId, "videoId": track.youtubeVideoId,
                        "title": track.title, "artist": track.artist,
                        "duration": track.duration, "addedBy": userId,
                        "addedByName": user.displayName,
                        "addedAt": FieldValue.serverTimestamp(), "position": position
                    ]
                    if let thumbnailURL = track.thumbnailURL { data["thumbnailURL"] = thumbnailURL.absoluteString }
                    transaction.setData(data, forDocument: trackReference)
                    transaction.updateData([
                        "trackCount": trackCount + 1,
                        "nextTrackPosition": position + 1,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: playlistReference)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error = error as NSError?, error.domain == "DuplicatePlaylistTrack" {
                    continuation.resume(throwing: PlaylistServiceError.duplicateTrack)
                } else if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        }
    }

    private func createPlaylistTransaction(playlist: Playlist, owner: AppUser, reference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction({ transaction, errorPointer -> Any? in
                if let code = playlist.joinCode {
                    let invite = self.database.collection("playlistInvites").document(code)
                    do {
                        if try transaction.getDocument(invite).exists {
                            errorPointer?.pointee = NSError(domain: "PlaylistInviteCollision", code: 1)
                            return nil
                        }
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                    transaction.setData([
                        "playlistId": playlist.id, "ownerId": owner.id,
                        "active": true, "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: invite)
                }
                transaction.setData(playlist.firestoreDataWithServerTimestamps, forDocument: reference)
                var member: [String: Any] = [
                    "userId": owner.id, "displayName": owner.displayName,
                    "role": PlaylistRole.owner.rawValue, "joinedAt": FieldValue.serverTimestamp()
                ]
                if let photoURL = owner.photoURL { member["photoURL"] = photoURL.absoluteString }
                transaction.setData(member, forDocument: reference.collection("members").document(owner.id))
                transaction.setData(self.indexData(playlistId: playlist.id, role: .owner, type: .owned),
                    forDocument: self.database.collection("userPlaylists").document(owner.id).collection("items").document(playlist.id))
                return nil
            }, completion: { _, error in
                if let error = error as NSError?, error.domain == "PlaylistInviteCollision" {
                    continuation.resume(throwing: PlaylistServiceError.inviteCollision)
                } else if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            })
        }
    }

    private func indexData(playlistId: String, role: PlaylistRole, type: UserPlaylistType) -> [String: Any] {
        ["playlistId": playlistId, "role": role.rawValue, "type": type.rawValue,
         "joinedAt": FieldValue.serverTimestamp()]
    }
}

private struct UserPlaylistEntry {
    let playlistId: String
    let type: UserPlaylistType
    nonisolated init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let playlistId = data["playlistId"] as? String,
              let value = data["type"] as? String,
              let type = UserPlaylistType(rawValue: value) else { return nil }
        self.playlistId = playlistId
        self.type = type
    }
}

extension Playlist {
    var firestoreDataWithServerTimestamps: [String: Any] {
        var data: [String: Any] = [
            "id": id, "name": name, "description": description, "ownerId": ownerId,
            "isCollaborative": isCollaborative, "visibility": visibility.rawValue,
            "createdAt": FieldValue.serverTimestamp(), "updatedAt": FieldValue.serverTimestamp(),
            "trackCount": trackCount, "memberCount": memberCount
        ]
        if let imageURL { data["imageURL"] = imageURL.absoluteString }
        if let joinCode { data["joinCode"] = joinCode }
        return data
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(), let name = data["name"] as? String,
              let ownerId = data["ownerId"] as? String else { return nil }
        self.init(
            id: document.documentID, name: name,
            description: data["description"] as? String ?? "", ownerId: ownerId,
            imageURL: (data["imageURL"] as? String).flatMap(URL.init(string:)),
            joinCode: data["joinCode"] as? String,
            isCollaborative: data["isCollaborative"] as? Bool ?? false,
            visibility: (data["visibility"] as? String).flatMap(PlaylistVisibility.init(rawValue:)) ?? .privateOnly,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast,
            trackCount: data["trackCount"] as? Int ?? 0, memberCount: data["memberCount"] as? Int ?? 1
        )
    }
}

private extension Track {
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let title = data["title"] as? String, let artist = data["artist"] as? String else { return nil }
        self.init(
            id: data["id"] as? String ?? document.documentID,
            youtubeVideoId: data["youtubeVideoId"] as? String ?? data["videoId"] as? String ?? document.documentID,
            title: title, artist: artist,
            thumbnailURL: (data["thumbnailURL"] as? String).flatMap(URL.init(string:)),
            duration: data["duration"] as? TimeInterval ?? 0,
            addedBy: data["addedBy"] as? String, addedByName: data["addedByName"] as? String,
            addedAt: (data["addedAt"] as? Timestamp)?.dateValue(), position: data["position"] as? Int
        )
    }
}

private extension PlaylistMember {
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let userId = data["userId"] as? String,
              let value = data["role"] as? String, let role = PlaylistRole(rawValue: value) else { return nil }
        self.init(userId: userId, displayName: data["displayName"] as? String ?? "Usuario",
                  photoURL: (data["photoURL"] as? String).flatMap(URL.init(string:)), role: role,
                  joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue() ?? .distantPast)
    }
}
