import SwiftUI

struct PlayerView: View {
    @Environment(PlayerManager.self) private var playerManager
    @Environment(\.dismiss) private var dismiss
    @State private var seekingValue: TimeInterval?

    var body: some View {
        Group {
            if let track = playerManager.currentTrack {
                VStack(spacing: AppTheme.Spacing.large) {
                    AsyncImage(url: track.thumbnailURL) { image in image.resizable().scaledToFill() }
                    placeholder: { AppTheme.Colors.elevatedSurface.overlay { Image(systemName: "music.note").font(.largeTitle) } }
                    .frame(maxWidth: 360, maxHeight: 360).aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                    VStack(spacing: 6) {
                        Text(track.title).font(.title2.bold()).multilineTextAlignment(.center)
                        Text(track.artist).foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    VStack {
                        Slider(value: Binding(
                            get: { seekingValue ?? playerManager.currentTime },
                            set: { seekingValue = $0 }
                        ), in: 0...max(playerManager.duration, 1), onEditingChanged: { editing in
                            if !editing, let value = seekingValue { playerManager.seek(to: value); seekingValue = nil }
                        })
                        HStack {
                            Text(DurationFormatter.string(from: seekingValue ?? playerManager.currentTime))
                            Spacer()
                            Text(DurationFormatter.string(from: playerManager.duration))
                        }
                        .font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    HStack(spacing: AppTheme.Spacing.extraLarge) {
                        Button { playerManager.previous() } label: { Image(systemName: "backward.fill") }
                            .disabled(!playerManager.canGoPrevious && playerManager.currentTime <= 5)
                        Button { playerManager.togglePlayPause() } label: {
                            if playerManager.isLoading { ProgressView().frame(width: 56, height: 56) }
                            else { Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 56)) }
                        }
                        .disabled(playerManager.isLoading)
                        Button { playerManager.next() } label: { Image(systemName: "forward.fill") }
                            .disabled(!playerManager.canGoNext)
                    }
                    if let error = playerManager.errorMessage { Text(error).foregroundStyle(.red).font(.footnote) }
                    Spacer()
                }
                .padding(AppTheme.Spacing.large)
            } else {
                EmptyStateView(title: "Nada en reproducción", systemImage: "music.note", message: "Selecciona una canción para empezar.")
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Reproductor").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
    }
}
