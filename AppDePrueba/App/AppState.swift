import Observation
import FirebaseCore

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .home
    private(set) var isFirebaseConfigured = false

    func refreshFirebaseConfiguration() {
        isFirebaseConfigured = FirebaseApp.app() != nil
    }

}
