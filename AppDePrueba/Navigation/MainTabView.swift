import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @Environment(PlayerManager.self) private var playerManager
    @State private var showingPlayer = false

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Inicio", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                LibraryView()
            }
            .tabItem { Label("Biblioteca", systemImage: "music.note.list") }
            .tag(AppTab.library)
        }
        .tabViewBottomAccessory(isEnabled: playerManager.currentTrack != nil) {
            MiniPlayerView { showingPlayer = true }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .animation(.easeInOut(duration: 0.2), value: playerManager.currentTrack?.id)
        .sheet(isPresented: $showingPlayer) { NavigationStack { PlayerView() } }
        .task(id: authViewModel.currentUser?.id) {
            guard let userId = authViewModel.currentUser?.id else {
                playlistViewModel.resetForSignedOutSession()
                return
            }
            playlistViewModel.observeOwnedPlaylists(ownerId: userId)
        }
    }
}
