import Foundation
import Testing
@testable import AppDePrueba

@MainActor
struct PlaylistFeatureTests {
    @Test func missingVisibilityIsPrivate() {
        #expect(PlaylistVisibility.fromFirestore(nil) == .privateOnly)
        #expect(PlaylistVisibility.fromFirestore("public") == .publicVisible)
    }

    @Test func publicSearchNormalizationRemovesDiacriticsAndBuildsPrefixes() {
        #expect(PlaylistSearchNormalizer.normalize("  Éxitos   Verano 2026 ") == "exitos verano 2026")
        let prefixes = PlaylistSearchNormalizer.searchPrefixes(for: "Éxitos Verano")
        #expect(prefixes.contains("exi"))
        #expect(prefixes.contains("verano"))
        #expect(PlaylistSearchNormalizer.queryTerm(" FIESTA ") == "fiesta")
    }

    @Test func followerIsReadOnlyWhileOwnerAndEditorCanEditTracks() {
        let playlist = makePlaylist()
        #expect(PlaylistAccessPolicy.canEditTracks(userId: "owner", playlist: playlist, role: nil))
        #expect(PlaylistAccessPolicy.canEditTracks(userId: "editor", playlist: playlist, role: .editor))
        #expect(!PlaylistAccessPolicy.canEditTracks(userId: "follower", playlist: playlist, role: nil))
        #expect(!PlaylistAccessPolicy.canManagePlaylist(userId: "follower", playlist: playlist))
    }

    private func makePlaylist() -> Playlist {
        Playlist(
            id: "playlist", name: "Fiesta", description: "", ownerId: "owner",
            ownerDisplayName: "Owner", imageURL: nil, joinCode: nil,
            isCollaborative: false, visibility: .publicVisible,
            createdAt: .now, updatedAt: .now, trackCount: 0, memberCount: 1
        )
    }
}
