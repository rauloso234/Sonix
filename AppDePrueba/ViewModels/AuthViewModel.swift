import FirebaseAuth
import Observation

enum SessionState {
    case checking
    case signedOut
    case signedIn
}

@MainActor
@Observable
final class AuthViewModel {
    private let repository: AuthRepositoryProtocol
    private var sessionListener: NSObjectProtocol?

    private(set) var sessionState: SessionState = .checking
    private(set) var currentUser: AppUser?
    private(set) var isLoading = false
    var errorMessage: String?
    var passwordResetSent = false

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func startObservingSession() {
        guard sessionListener == nil else { return }

        sessionListener = repository.observeSession { [weak self] user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
                self?.sessionState = user == nil ? .signedOut : .signedIn
            }
        }
    }

    func login(email: String, password: String) async {
        await performAuthAction {
            _ = try await repository.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    func register(displayName: String, email: String, password: String) async {
        await performAuthAction {
            _ = try await repository.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    func logout() {
        do {
            try repository.logout()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        passwordResetSent = false
        defer { isLoading = false }

        do {
            try await repository.resetPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            passwordResetSent = true
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func clearMessages() {
        errorMessage = nil
        passwordResetSent = false
    }

    private func performAuthAction(_ action: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await action()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return AppError.authentication.localizedDescription
        }

        switch code {
        case .invalidEmail:
            return "El correo electrónico no es válido."
        case .wrongPassword, .invalidCredential, .userNotFound:
            return "El correo o la contraseña no son correctos."
        case .emailAlreadyInUse:
            return "Ya existe una cuenta con ese correo."
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres."
        case .networkError:
            return AppError.network.localizedDescription
        case .tooManyRequests:
            return "Demasiados intentos. Espera un momento y vuelve a probar."
        case .operationNotAllowed:
            return "El acceso con correo y contraseña no está habilitado en Firebase."
        case .userDisabled:
            return "Esta cuenta está deshabilitada."
        case .appNotAuthorized:
            return "Firebase no reconoce esta app. Comprueba el Bundle Identifier y el archivo de configuración."
        case .invalidAPIKey:
            return "La configuración de Firebase no es válida."
        default:
            return AppError.authentication.localizedDescription
        }
    }
}
