import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        List {
            Section {
                LabeledContent("Nombre", value: authViewModel.currentUser?.displayName ?? "—")
                LabeledContent("Correo", value: authViewModel.currentUser?.email ?? "—")
            }

            Section {
                Button("Cerrar sesión", role: .destructive) {
                    authViewModel.logout()
                }
            }
        }
        .navigationTitle("Perfil")
    }
}
