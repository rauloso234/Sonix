import SwiftUI

struct JoinPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PlaylistViewModel.self) private var playlistViewModel
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Código", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { _, value in code = JoinCodeGenerator.normalize(value) }
                } footer: { Text("Introduce el código de 6 caracteres que te han compartido.") }
                if let error = playlistViewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button {
                        guard let user = authViewModel.currentUser else { return }
                        Task {
                            if await playlistViewModel.joinPlaylist(code: code, user: user) { dismiss() }
                        }
                    } label: {
                        HStack {
                            Text("Unirme").frame(maxWidth: .infinity)
                            if playlistViewModel.isLoading { ProgressView() }
                        }
                    }
                    .disabled(!JoinCodeGenerator.isValid(code) || playlistViewModel.isLoading || authViewModel.currentUser == nil)
                }
            }
            .navigationTitle("Unirse a una playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        }
    }
}
