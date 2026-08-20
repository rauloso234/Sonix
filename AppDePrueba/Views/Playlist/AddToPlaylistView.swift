import SwiftUI

struct AddToPlaylistView: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel

    private var editablePlaylists: [Playlist] {
        playlistViewModel.ownedPlaylists + playlistViewModel.collaborativePlaylists
    }

    var body: some View {
        NavigationStack {
            List {
                if editablePlaylists.isEmpty {
                    Text("No tienes playlists editables.").foregroundStyle(AppTheme.Colors.secondaryText)
                } else {
                    ForEach(editablePlaylists) { playlist in
                        Button {
                            guard let user = authViewModel.currentUser else { return }
                            Task {
                                if await playlistViewModel.addTrack(track, to: playlist, user: user) { dismiss() }
                            }
                        } label: {
                            HStack {
                                Image(systemName: playlist.isCollaborative ? "person.2.fill" : "music.note.list")
                                VStack(alignment: .leading) {
                                    Text(playlist.name)
                                    Text(playlist.isCollaborative ? "Colaborativa" : "Propia")
                                        .font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                Spacer()
                                if playlistViewModel.isLoading { ProgressView() }
                            }
                        }
                        .disabled(playlistViewModel.isLoading)
                    }
                }
                if let error = playlistViewModel.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Añadir a playlist").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        }
    }
}
