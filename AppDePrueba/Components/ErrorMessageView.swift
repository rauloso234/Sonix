import SwiftUI

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(AppTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}
