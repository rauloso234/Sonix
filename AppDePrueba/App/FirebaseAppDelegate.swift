import FirebaseCore
import UIKit

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfPossible()
        return true
    }

    private func configureFirebaseIfPossible() {
        guard FirebaseApp.app() == nil,
              let filePath = Bundle.main.path(
                forResource: "GoogleService-Info",
                ofType: "plist"
              ),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            return
        }

        FirebaseApp.configure(options: options)
    }
}
