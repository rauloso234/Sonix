import SwiftUI

struct EditPlaylistView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @State private var name: String
    @State private var description: String
    @State private var visibility: PlaylistVisibility

    init(playlist: Playlist) {
        self.playlist = playlist
        _name = State(initialValue: playlist.name)
        _description = State(initialValue: playlist.description)
        _visibility = State(initialValue: playlist.visibility == .publicVisible ? .publicVisible : .privateOnly)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción", text: $description, axis: .vertical).lineLimit(3...6)
                }
                Section("Visibilidad") {
                    Picker("Visibilidad", selection: $visibility) {
                        Text("Privada").tag(PlaylistVisibility.privateOnly)
                        Text("Pública").tag(PlaylistVisibility.publicVisible)
                    }.pickerStyle(.segmented)
                }
                if let error = playlistViewModel.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Editar playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard let user = authViewModel.currentUser else { return }
                        Task {
                            if await playlistViewModel.updatePlaylist(
                                playlist, name: name, description: description,
                                visibility: visibility, user: user
                            ) { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || playlistViewModel.isLoading)
                }
            }
        }
    }
}
