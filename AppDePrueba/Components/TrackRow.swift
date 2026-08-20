import SwiftUI

struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            AsyncImage(url: track.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                AppTheme.Colors.elevatedSurface
                    .overlay { Image(systemName: "music.note") }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                if let name = track.addedByName {
                    Text("Añadida por \(name)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
            Spacer()
            Text(DurationFormatter.string(from: track.duration))
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }
}
