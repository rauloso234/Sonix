import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.extraLarge) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hola, \(authViewModel.currentUser?.displayName ?? "melómano")")
                        .font(.largeTitle.bold())
                    Text("¿Qué quieres escuchar hoy?")
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                PlaylistSection(
                    title: "Tus playlists",
                    message: "Aquí aparecerán las playlists que crees."
                )
                PlaylistSection(
                    title: "Playlists colaborativas",
                    message: "Únete con un código para escuchar en compañía."
                )
                PlaylistSection(
                    title: "Añadidas recientemente",
                    message: "Todavía no has añadido canciones."
                )
            }
            .padding(AppTheme.Spacing.medium)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Inicio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
    }
}

private struct PlaylistSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text(title).font(.title2.bold())

            Text(message)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                .padding(AppTheme.Spacing.medium)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
    }
}
