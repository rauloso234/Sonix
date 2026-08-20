import SwiftUI

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var isCollaborative = false
    @State private var visibility: PlaylistVisibility = .privateOnly

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Playlist colaborativa", isOn: $isCollaborative)
                } footer: {
                    Text("Si la haces colaborativa, se generará un código para invitar a otras personas.")
                }

                Section("Visibilidad") {
                    Picker("Visibilidad", selection: $visibility) {
                        Text("Privada").tag(PlaylistVisibility.privateOnly)
                        Text("Pública").tag(PlaylistVisibility.publicVisible)
                    }
                    .pickerStyle(.segmented)
                    Text(visibility == .publicVisible
                         ? "Cualquier usuario puede encontrarla y escucharla."
                         : "Solo tú y los colaboradores autorizados pueden acceder.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                if let errorMessage = playlistViewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nueva playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        guard let owner = authViewModel.currentUser else { return }
                        Task {
                            let created = await playlistViewModel.createPlaylist(
                                name: name,
                                description: description,
                                isCollaborative: isCollaborative,
                                visibility: visibility,
                                owner: owner
                            )
                            if created { dismiss() }
                        }
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || authViewModel.currentUser == nil
                            || playlistViewModel.isLoading
                    )
                }
            }
            .overlay {
                if playlistViewModel.isLoading {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }
}
