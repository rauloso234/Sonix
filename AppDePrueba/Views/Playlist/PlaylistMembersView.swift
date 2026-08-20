import SwiftUI

struct PlaylistMembersView: View {
    let members: [PlaylistMember]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(members) { member in
            HStack {
                AsyncImage(url: member.photoURL) { image in image.resizable().scaledToFill() }
                placeholder: { Image(systemName: "person.crop.circle.fill").resizable() }
                .frame(width: 40, height: 40).clipShape(Circle())
                Text(member.displayName)
                Spacer()
                Text(member.role.localizedName).font(.subheadline).foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .navigationTitle("Miembros")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
    }
}
