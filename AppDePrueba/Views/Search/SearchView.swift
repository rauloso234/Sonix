import SwiftUI

struct SearchView: View {
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(PlayerManager.self) private var playerManager
    @State private var query = ""
    @State private var trackToAdd: Track?

    var body: some View {
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
                List(viewModel.results) { track in
                    HStack {
                        Button { playerManager.play(track: track) } label: { TrackRow(track: track) }
                            .buttonStyle(.plain)
                        Button { trackToAdd = track } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Añadir a playlist")
                    }
                    .listRowBackground(AppTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Buscar")
        .searchable(text: $query, prompt: "Canciones o artistas")
        .onChange(of: query) { _, value in viewModel.queryChanged(value) }
        .sheet(item: $trackToAdd) { track in AddToPlaylistView(track: track) }
    }
}
