import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerManager.self) private var playerManager
    let openPlayer: () -> Void

    var body: some View {
        if let track = playerManager.currentTrack {
            HStack(spacing: AppTheme.Spacing.small) {
                AsyncImage(url: track.thumbnailURL) { image in image.resizable().scaledToFill() }
                placeholder: { AppTheme.Colors.elevatedSurface.overlay { Image(systemName: "music.note") } }
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                Button(action: openPlayer) {
                    VStack(alignment: .leading) {
                        Text(track.title).lineLimit(1)
                        Text(playerManager.isLoadingRecommendations
                             ? "Buscando canciones similares…"
                             : (playerManager.isLoading ? "Cargando…" : track.artist))
                            .font(.caption).foregroundStyle(AppTheme.Colors.secondaryText).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if playerManager.isLoading { ProgressView() }
                else {
                    Button { playerManager.togglePlayPause() } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill").frame(width: 36, height: 36)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.medium).padding(.vertical, 6)
            .background(.ultraThinMaterial)
        }
    }
}
