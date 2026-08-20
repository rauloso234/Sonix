import Foundation

protocol AuthRepositoryProtocol {
    func register(email: String, password: String, displayName: String) async throws -> AppUser
    func login(email: String, password: String) async throws -> AppUser
    func logout() throws
    func resetPassword(email: String) async throws
    func observeSession(_ onChange: @escaping (AppUser?) -> Void) -> NSObjectProtocol
    func stopObservingSession(_ handle: NSObjectProtocol)
}

final class FirebaseAuthRepository: AuthRepositoryProtocol {
    private let service: FirebaseAuthServiceProtocol

    init(service: FirebaseAuthServiceProtocol) {
        self.service = service
    }

    func register(email: String, password: String, displayName: String) async throws -> AppUser {
        try await service.register(email: email, password: password, displayName: displayName)
    }

    func login(email: String, password: String) async throws -> AppUser {
        try await service.login(email: email, password: password)
    }

    func logout() throws {
        try service.logout()
    }

    func resetPassword(email: String) async throws {
        try await service.resetPassword(email: email)
    }

    func observeSession(_ onChange: @escaping (AppUser?) -> Void) -> NSObjectProtocol {
        service.addSessionListener(onChange)
    }

    func stopObservingSession(_ handle: NSObjectProtocol) {
        service.removeSessionListener(handle)
    }
}
