import SwiftUI

struct AuthenticationView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
    private let isPreview: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegistration = false
    @State private var showingPasswordReset = false

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    private var canLogin: Bool {
        email.contains("@")
            && !password.isEmpty
            && appState.isFirebaseConfigured
            && !isPreview
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Spacer(minLength: 52)

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(AppTheme.Colors.accent, AppTheme.Colors.secondaryAccent)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        Text("Tu música, en compañía").font(.largeTitle.bold())
                        Text("Inicia sesión para acceder a tus playlists.")
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    VStack(spacing: AppTheme.Spacing.medium) {
                        TextField("Correo electrónico", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Contraseña", text: $password)
                            .textContentType(.password)
                    }
                    .textFieldStyle(AppTextFieldStyle())

                    if isPreview {
                        Label(
                            "La Preview solo muestra el diseño. Ejecuta la app con ▶ para usar Firebase.",
                            systemImage: "play.circle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryAccent)
                    } else if !appState.isFirebaseConfigured {
                        Label("Añade GoogleService-Info.plist al target para conectar Firebase.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.yellow)
                    }

                    if let message = authViewModel.errorMessage {
                        ErrorMessageView(message: message)
                    }

                    Button {
                        Task { await authViewModel.login(email: email, password: password) }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Iniciar sesión")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canLogin || authViewModel.isLoading)

                    Button("¿Has olvidado tu contraseña?") {
                        authViewModel.clearMessages()
                        showingPasswordReset = true
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isPreview)

                    Button("Crear una cuenta") {
                        authViewModel.clearMessages()
                        showingRegistration = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(isPreview)
                }
                .padding(AppTheme.Spacing.large)
            }
        }
        .sheet(isPresented: $showingRegistration) { RegistrationView() }
        .sheet(isPresented: $showingPasswordReset) { ResetPasswordView(initialEmail: email) }
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

#Preview {
    AuthenticationView(isPreview: true)
        .environment(AppState())
        .environment(
            AuthViewModel(
                repository: FirebaseAuthRepository(service: FirebaseAuthService())
            )
        )
        .preferredColorScheme(.dark)
}
