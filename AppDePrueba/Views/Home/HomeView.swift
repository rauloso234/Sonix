import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @Environment(PlayerManager.self) private var playerManager
    @State private var showingPlayer = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.extraLarge) {
                greeting
                if let track = playerManager.currentTrack { continueListening(track) }
                trackSection(title: "Escuchado recientemente", tracks: viewModel.recentTracks)
                playlistSection(title: "Tus playlists", playlists: Array(playlistViewModel.ownedPlaylists.prefix(10)))
                playlistSection(title: "Playlists colaborativas", playlists: Array(playlistViewModel.collaborativePlaylists.prefix(10)))
                playlistSection(title: "Siguiendo", playlists: Array(playlistViewModel.followedPlaylists.prefix(10)))
                recommendationsSection
            }.padding(AppTheme.Spacing.medium)
        }
        .background(AppTheme.Colors.background).navigationTitle("Inicio")
        .refreshable { await refresh(force: true) }
        .task(id: authViewModel.currentUser?.id) { await refresh(force: false) }
        .sheet(isPresented: $showingPlayer) { NavigationStack { PlayerView() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { ProfileView() } label: { Image(systemName: "person.crop.circle") }
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hola, \(authViewModel.currentUser?.displayName ?? "melómano")").font(.largeTitle.bold())
            Text("¿Qué quieres escuchar hoy?").foregroundStyle(AppTheme.Colors.secondaryText)
            if let error = viewModel.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
        }
    }

    private func continueListening(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Continuar escuchando").font(.title2.bold())
            HStack(spacing: AppTheme.Spacing.medium) {
                Button { showingPlayer = true } label: { artwork(for: track, size: 72) }.buttonStyle(.plain)
                Button { showingPlayer = true } label: {
                    VStack(alignment: .leading) {
                        Text(track.title).fontWeight(.semibold).lineLimit(1)
                        Text(track.artist).font(.subheadline).foregroundStyle(AppTheme.Colors.secondaryText).lineLimit(1)
                    }
                }.buttonStyle(.plain)
                Spacer()
                Button { playerManager.togglePlayPause() } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.largeTitle)
                }.buttonStyle(.plain)
            }.padding(AppTheme.Spacing.medium).background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
    }

    @ViewBuilder private func trackSection(title: String, tracks: [Track]) -> some View {
        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text(title).font(.title2.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: AppTheme.Spacing.medium) { ForEach(tracks) { track in trackCard(track) } }
                }
            }
        }
    }

    @ViewBuilder private func playlistSection(title: String, playlists: [Playlist]) -> some View {
        if !playlists.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text(title).font(.title2.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: AppTheme.Spacing.medium) {
                        ForEach(playlists) { playlist in
                            NavigationLink { PlaylistDetailView(playlist: playlist) } label: { PlaylistCard(playlist: playlist) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Recomendado para ti").font(.title2.bold())
            if viewModel.isLoading && viewModel.recommendations.isEmpty { ProgressView() }
            else if !viewModel.recommendations.isEmpty {
                ForEach(viewModel.recommendations) { track in
                    Button { playerManager.play(track: track) } label: { TrackRow(track: track) }.buttonStyle(.plain)
                }
            } else if let message = viewModel.recommendationMessage {
                Text(message).font(.subheadline).foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private func trackCard(_ track: Track) -> some View {
        Button { playerManager.play(track: track) } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                artwork(for: track, size: 132)
                Text(track.title).fontWeight(.semibold).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(AppTheme.Colors.secondaryText).lineLimit(1)
            }.frame(width: 132, alignment: .leading)
        }.buttonStyle(.plain)
    }

    private func artwork(for track: Track, size: CGFloat) -> some View {
        AsyncImage(url: track.thumbnailURL) { image in image.resizable().scaledToFill() } placeholder: {
            AppTheme.Colors.elevatedSurface.overlay { Image(systemName: "music.note") }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }

    private func refresh(force: Bool) async {
        guard let userID = authViewModel.currentUser?.id else { viewModel.reset(); return }
        await viewModel.load(userID: userID, forceRefresh: force)
        #if DEBUG
        print("[Home] Owned playlists: \(playlistViewModel.ownedPlaylists.count)")
        print("[Home] Followed playlists: \(playlistViewModel.followedPlaylists.count)")
        #endif
    }
}
