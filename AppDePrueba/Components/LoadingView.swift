import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            ProgressView()
            Text(message).foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
}
