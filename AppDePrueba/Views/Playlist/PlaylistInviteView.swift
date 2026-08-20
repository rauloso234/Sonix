import SwiftUI

struct PlaylistInviteView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.large) {
                Image(systemName: "person.2.badge.plus").font(.system(size: 52)).foregroundStyle(AppTheme.Colors.accent)
                Text("Invitar amigos").font(.title.bold())
                if let code = playlist.joinCode {
                    Text(code).font(.system(.largeTitle, design: .monospaced).bold()).textSelection(.enabled)
                    Text("Comparte este código para que otros usuarios puedan unirse.")
                        .multilineTextAlignment(.center).foregroundStyle(AppTheme.Colors.secondaryText)
                    ShareLink(item: "Únete a mi playlist \"\(playlist.name)\" con el código \(code)") {
                        Label("Compartir código", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Esta playlist no tiene una invitación activa.").foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
            }
            .padding(AppTheme.Spacing.large).background(AppTheme.Colors.background)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}
