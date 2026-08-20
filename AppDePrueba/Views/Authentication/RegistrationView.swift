import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""

    private var formIsValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
            && password.count >= 6
            && password == passwordConfirmation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.medium) {
                    TextField("Nombre", text: $displayName)
                        .textContentType(.name)
                    TextField("Correo electrónico", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Contraseña (mínimo 6 caracteres)", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Repite la contraseña", text: $passwordConfirmation)
                        .textContentType(.newPassword)
                }
                .textFieldStyle(AppTextFieldStyle())
                .padding(AppTheme.Spacing.large)

                if !passwordConfirmation.isEmpty && password != passwordConfirmation {
                    ErrorMessageView(message: "Las contraseñas no coinciden.")
                        .padding(.horizontal, AppTheme.Spacing.large)
                } else if let message = authViewModel.errorMessage {
                    ErrorMessageView(message: message)
                        .padding(.horizontal, AppTheme.Spacing.large)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Crear cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task {
                            await authViewModel.register(
                                displayName: displayName,
                                email: email,
                                password: password
                            )
                            if authViewModel.errorMessage == nil { dismiss() }
                        }
                    }
                    .disabled(!formIsValid || authViewModel.isLoading)
                }
            }
            .overlay {
                if authViewModel.isLoading {
                    LoadingView(message: "Creando tu cuenta…")
                        .background(.black.opacity(0.65))
                }
            }
        }
    }
}
