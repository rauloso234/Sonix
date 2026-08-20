import FirebaseAuth
import Foundation

protocol FirebaseAuthServiceProtocol {
    func register(email: String, password: String, displayName: String) async throws -> AppUser
    func login(email: String, password: String) async throws -> AppUser
    func logout() throws
    func resetPassword(email: String) async throws
    func addSessionListener(_ onChange: @escaping (AppUser?) -> Void) -> NSObjectProtocol
    func removeSessionListener(_ handle: NSObjectProtocol)
}

final class FirebaseAuthService: FirebaseAuthServiceProtocol {
    func register(email: String, password: String, displayName: String) async throws -> AppUser {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let request = result.user.createProfileChangeRequest()
        request.displayName = displayName
        try await request.commitChanges()
        return AppUser(firebaseUser: result.user, fallbackDisplayName: displayName)
    }

    func login(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return AppUser(firebaseUser: result.user)
    }

    func logout() throws {
        try Auth.auth().signOut()
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func addSessionListener(_ onChange: @escaping (AppUser?) -> Void) -> NSObjectProtocol {
        Auth.auth().addStateDidChangeListener { _, user in
            onChange(user.map { AppUser(firebaseUser: $0) })
        }
    }

    func removeSessionListener(_ handle: NSObjectProtocol) {
        Auth.auth().removeStateDidChangeListener(handle)
    }
}

private extension AppUser {
    init(firebaseUser: FirebaseAuth.User, fallbackDisplayName: String? = nil) {
        self.init(
            id: firebaseUser.uid,
            displayName: firebaseUser.displayName
                ?? fallbackDisplayName
                ?? firebaseUser.email?.components(separatedBy: "@").first
                ?? "Usuario",
            email: firebaseUser.email ?? "",
            photoURL: firebaseUser.photoURL,
            createdAt: firebaseUser.metadata.creationDate ?? .now
        )
    }
}
