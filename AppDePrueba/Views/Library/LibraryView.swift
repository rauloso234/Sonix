import SwiftUI

struct LibraryView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @State private var showingCreatePlaylist = false
    @State private var showingJoinPlaylist = false

    var body: some View {
        Group {
            if playlistViewModel.isLoading && playlistViewModel.ownedPlaylists.isEmpty
                && playlistViewModel.collaborativePlaylists.isEmpty {
                LoadingView(message: "Cargando tu biblioteca…")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        playlistSection(
                            title: "Mis playlists",
                            playlists: playlistViewModel.ownedPlaylists,
                            emptyMessage: "No has creado ninguna playlist."
                        )
                        playlistSection(
                            title: "Playlists colaborativas",
                            playlists: playlistViewModel.collaborativePlaylists,
                            emptyMessage: "No te has unido a ninguna playlist colaborativa."
                        )
                        if let error = playlistViewModel.errorMessage {
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }
                        Button {
                            showingJoinPlaylist = true
                        } label: {
                            Label("Unirse a playlist", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(AppTheme.Spacing.medium)
                }
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Biblioteca")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreatePlaylist = true } label: {
                    Label("Crear playlist", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) { CreatePlaylistView() }
        .sheet(isPresented: $showingJoinPlaylist) { JoinPlaylistView() }
        .task(id: authViewModel.currentUser?.id) {
            guard let userId = authViewModel.currentUser?.id else {
                playlistViewModel.resetForSignedOutSession()
                return
            }
            playlistViewModel.observeOwnedPlaylists(ownerId: userId)
        }
    }

    @ViewBuilder
    private func playlistSection(title: String, playlists: [Playlist], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text(title).font(.title2.bold())
            if playlists.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding(.vertical, AppTheme.Spacing.small)
            } else {
                ForEach(playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        libraryRow(playlist)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func libraryRow(_ playlist: Playlist) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: playlist.isCollaborative ? "person.2.fill" : "music.note.list")
                .font(.title2).frame(width: 56, height: 56)
                .background(AppTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name).fontWeight(.semibold)
                Text(playlist.isCollaborative
                    ? "\(playlist.memberCount) miembros · \(playlist.trackCount) canciones"
                    : "\(playlist.trackCount) canciones")
                    .font(.subheadline).foregroundStyle(AppTheme.Colors.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(AppTheme.Spacing.medium).background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}
