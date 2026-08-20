import SwiftUI

struct PlaylistDetailView: View {
    private let actionColumns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.small),
        GridItem(.flexible(), spacing: AppTheme.Spacing.small)
    ]
    let playlist: Playlist
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistDetailViewModel.self) private var viewModel
    @Environment(PlayerManager.self) private var playerManager
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @State private var showingInvite = false
    @State private var showingMembers = false
    @State private var showingSearch = false
    @State private var showingEdit = false

    private var currentRole: PlaylistRole? { viewModel.role(for: authViewModel.currentUser?.id) }
    private var canEditTracks: Bool {
        PlaylistAccessPolicy.canEditTracks(
            userId: authViewModel.currentUser?.id,
            playlist: playlist,
            role: currentRole
        )
    }
    private var ownerName: String { playlist.ownerDisplayName }
    private var isOwner: Bool { authViewModel.currentUser?.id == playlist.ownerId }
    private var isIndexedCollaborator: Bool {
        playlistViewModel.collaborativePlaylists.contains { $0.id == playlist.id }
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
        .sheet(isPresented: $showingEdit) { EditPlaylistView(playlist: playlist) }
        .task(id: playlist.id) {
            viewModel.start(playlistId: playlist.id, observeMembers: isOwner || isIndexedCollaborator)
        }
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
            Label("\(playlist.memberCount) miembros · \(viewModel.tracks.count) canciones",
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
            if canShowFollowControl, let user = authViewModel.currentUser {
                Button(playlistViewModel.isFollowing(playlist) ? "Siguiendo" : "Seguir",
                       systemImage: playlistViewModel.isFollowing(playlist) ? "checkmark.circle.fill" : "plus.circle") {
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
            LazyVGrid(columns: actionColumns, spacing: AppTheme.Spacing.small) {
                if isOwner {
                    actionButton(title: "Editar", systemImage: "pencil") { showingEdit = true }
                }
                if canEditTracks {
                    actionButton(title: "Añadir canción", systemImage: "plus") { showingSearch = true }
                }
                if isOwner || isIndexedCollaborator {
                    actionButton(title: "Miembros", systemImage: "person.2") { showingMembers = true }
                }
                if isOwner, playlist.isCollaborative, playlist.joinCode != nil {
                    actionButton(title: "Invitar", systemImage: "square.and.arrow.up") { showingInvite = true }
                }
            }
            if !canEditTracks {
                Text("Tu rol permite consultar y reproducir esta playlist.")
                    .font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, AppTheme.Spacing.small)
                .background(AppTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
        }
        .buttonStyle(.plain)
    }

    private var canShowFollowControl: Bool {
        guard playlist.visibility == .publicVisible,
              let userId = authViewModel.currentUser?.id,
              userId != playlist.ownerId else { return false }
        return currentRole == nil && !isIndexedCollaborator
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
