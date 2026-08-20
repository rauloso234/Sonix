import SwiftUI

struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AsyncImage(url: playlist.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                AppTheme.Colors.elevatedSurface
                    .overlay { Image(systemName: "music.note.list").font(.title) }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))

            Text(playlist.name).fontWeight(.semibold).lineLimit(1)
            Text(playlist.isCollaborative
                ? "Colaborativa · \(playlist.trackCount) canciones"
                : "\(playlist.trackCount) canciones")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(width: 160, alignment: .leading)
    }
}
