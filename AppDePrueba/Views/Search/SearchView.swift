import SwiftUI

struct SearchView: View {
    private enum Scope: String, CaseIterable { case songs = "Canciones", playlists = "Playlists" }
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(PlayerManager.self) private var playerManager
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var query = ""
    @State private var trackToAdd: Track?
    @State private var scope: Scope = .songs

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tipo de búsqueda", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)

            if scope == .songs { songResults } else { playlistResults }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Buscar")
        .searchable(text: $query, prompt: scope == .songs ? "Canciones o artistas" : "Playlists públicas")
        .onChange(of: query) { _, value in submitQuery(value) }
        .onChange(of: scope) { _, _ in submitQuery(query) }
        .sheet(item: $trackToAdd) { track in AddToPlaylistView(track: track) }
    }

    @ViewBuilder
    private var songResults: some View {
        Group {
            switch viewModel.state {
            case .idle:
                EmptyStateView(title: "Busca tu próxima canción", systemImage: "music.note", message: "Escribe una canción o artista.")
            case .loading:
                LoadingView(message: "Buscando canciones…")
            case .empty:
                EmptyStateView(title: "Sin resultados", systemImage: "magnifyingglass", message: "No se encontraron canciones.")
            case .error:
                EmptyStateView(title: "Búsqueda no disponible", systemImage: "wifi.exclamationmark", message: viewModel.errorMessage ?? "El servicio de música no está disponible en este momento.")
            case .loaded:
                List(Array(viewModel.results.enumerated()), id: \.offset) { index, track in
                    HStack {
                        Button {
                            playerManager.playQueue(viewModel.results, startingAt: index)
                        } label: {
                            TrackRow(track: track)
                        }
                            .buttonStyle(.plain)
                        Button { trackToAdd = track } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Añadir a playlist")
                    }
                    .listRowBackground(AppTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private var playlistResults: some View {
        switch viewModel.playlistState {
        case .idle:
            EmptyStateView(title: "Busca playlists públicas", systemImage: "music.note.list", message: "Escribe el nombre de una playlist.")
        case .loading:
            LoadingView(message: "Buscando playlists…")
        case .empty:
            EmptyStateView(title: "Sin playlists", systemImage: "magnifyingglass", message: "No se encontraron playlists públicas.")
        case .error:
            EmptyStateView(title: "Búsqueda no disponible", systemImage: "wifi.exclamationmark", message: viewModel.errorMessage ?? "No se pudo completar la búsqueda.")
        case .loaded:
            List(viewModel.publicPlaylists) { playlist in
                HStack {
                    NavigationLink { PlaylistDetailView(playlist: playlist) } label: {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        AsyncImage(url: playlist.imageURL) { $0.resizable().scaledToFill() }
                        placeholder: { AppTheme.Colors.elevatedSurface.overlay { Image(systemName: "music.note.list") } }
                        .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.name).fontWeight(.semibold)
                            Text(playlist.ownerDisplayName).font(.subheadline)
                            Text("Pública · \(playlist.trackCount) canciones")
                                .font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                    }
                    if playlist.ownerId != authViewModel.currentUser?.id,
                       !playlistViewModel.collaborativePlaylists.contains(where: { $0.id == playlist.id }) {
                        Button(playlistViewModel.isFollowing(playlist) ? "Siguiendo" : "Seguir") {
                            guard let user = authViewModel.currentUser else { return }
                            Task {
                                if playlistViewModel.isFollowing(playlist) {
                                    _ = await playlistViewModel.unfollow(playlist, user: user)
                                } else {
                                    _ = await playlistViewModel.follow(playlist, user: user)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func submitQuery(_ value: String) {
        if scope == .songs { viewModel.queryChanged(value) }
        else { viewModel.publicPlaylistQueryChanged(value) }
    }
}
