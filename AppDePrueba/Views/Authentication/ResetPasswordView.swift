import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var email: String

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                Text("Te enviaremos un correo para que puedas elegir una nueva contraseña.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                TextField("Correo electrónico", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(AppTextFieldStyle())

                if authViewModel.passwordResetSent {
                    Label("Correo enviado. Revisa también la carpeta de spam.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let message = authViewModel.errorMessage {
                    ErrorMessageView(message: message)
                }

                Button("Enviar correo") {
                    Task { await authViewModel.resetPassword(email: email) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!email.contains("@") || authViewModel.isLoading)

                Spacer()
            }
            .padding(AppTheme.Spacing.large)
            .background(AppTheme.Colors.background)
            .navigationTitle("Recuperar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
