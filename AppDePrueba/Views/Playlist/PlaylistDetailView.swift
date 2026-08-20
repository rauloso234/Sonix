import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistDetailViewModel.self) private var viewModel
    @Environment(PlayerManager.self) private var playerManager
    @State private var showingInvite = false
    @State private var showingMembers = false
    @State private var showingSearch = false

    private var currentRole: PlaylistRole? { viewModel.role(for: authViewModel.currentUser?.id) }
    private var canEditTracks: Bool {
        authViewModel.currentUser?.id == playlist.ownerId || currentRole?.canEditTracks == true
    }
    private var ownerName: String {
        viewModel.members.first { $0.userId == playlist.ownerId }?.displayName ?? "Propietario"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header
                actions
                Divider()
                Text("Canciones").font(.title2.bold())
                tracksContent
            }
            .padding(AppTheme.Spacing.medium)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInvite) { PlaylistInviteView(playlist: playlist) }
        .sheet(isPresented: $showingMembers) {
            NavigationStack { PlaylistMembersView(members: viewModel.members) }
        }
        .sheet(isPresented: $showingSearch) { NavigationStack { SearchView() } }
        .task(id: playlist.id) { viewModel.start(playlistId: playlist.id) }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            AsyncImage(url: playlist.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                AppTheme.Colors.elevatedSurface.overlay { Image(systemName: "music.note.list").font(.largeTitle) }
            }
            .frame(maxWidth: .infinity).aspectRatio(1.8, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            Text(playlist.name).font(.largeTitle.bold())
            if !playlist.description.isEmpty { Text(playlist.description).foregroundStyle(AppTheme.Colors.secondaryText) }
            Text("De \(ownerName)").font(.subheadline)
            Label("\(viewModel.members.count) miembros · \(viewModel.tracks.count) canciones",
                  systemImage: playlist.isCollaborative ? "person.2.fill" : "music.note.list")
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var actions: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Button("Reproducir", systemImage: "play.fill") {
                if !viewModel.tracks.isEmpty { playerManager.playQueue(viewModel.tracks, startingAt: 0) }
            }
                .buttonStyle(.borderedProminent).disabled(viewModel.tracks.isEmpty).frame(maxWidth: .infinity)
            HStack {
                Button("Añadir canción", systemImage: "plus") { showingSearch = true }
                    .buttonStyle(.bordered).disabled(!canEditTracks)
                Button("Miembros", systemImage: "person.2") { showingMembers = true }
                    .buttonStyle(.bordered)
                if playlist.isCollaborative, playlist.joinCode != nil {
                    Button("Invitar", systemImage: "square.and.arrow.up") { showingInvite = true }
                        .buttonStyle(.bordered)
                }
            }
            if !canEditTracks {
                Text("Tu rol permite consultar y reproducir esta playlist.")
                    .font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var tracksContent: some View {
        if viewModel.isLoading && viewModel.tracks.isEmpty {
            ProgressView("Cargando canciones…").frame(maxWidth: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.tracks.isEmpty {
            EmptyStateView(title: "No se pudieron cargar las canciones", systemImage: "exclamationmark.triangle", message: error)
        } else if viewModel.tracks.isEmpty {
            EmptyStateView(title: "Esta playlist está vacía", systemImage: "music.note", message: "Añade canciones para empezar a escucharla.")
        } else {
            ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                Button { playerManager.playQueue(viewModel.tracks, startingAt: index) } label: {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                        Text("\(index + 1).").foregroundStyle(AppTheme.Colors.secondaryText).frame(width: 28)
                        TrackRow(track: track)
                    }
                }.buttonStyle(.plain)
            }
        }
    }
}
