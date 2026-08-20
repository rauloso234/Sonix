import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            switch authViewModel.sessionState {
            case .checking:
                LoadingView(message: "Comprobando sesión…")
            case .signedOut:
                AuthenticationView()
            case .signedIn:
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.Colors.accent)
        .task {
            appState.refreshFirebaseConfiguration()
            guard appState.isFirebaseConfigured else { return }
            authViewModel.startObservingSession()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(
            AuthViewModel(
                repository: FirebaseAuthRepository(service: FirebaseAuthService())
            )
        )
}
