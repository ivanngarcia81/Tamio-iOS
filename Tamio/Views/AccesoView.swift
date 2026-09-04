import SwiftUI

/// Puerta de sesión. Sin ella los repositorios reales no devuelven nada,
/// porque las políticas RLS exigen `auth.uid()`. Deliberadamente sobria: el
/// diseño definitivo del acceso está pendiente, esto solo desbloquea la
/// conexión sin dejar credenciales escritas en el código.
struct AccesoView: View {
    let sesion: SesionSupabase

    @State private var correo = ""
    @State private var contrasena = ""
    @FocusState private var foco: Campo?

    private enum Campo { case correo, contrasena }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Tamio").font(.largeTitle.weight(.bold))
                Text(L.t("Entra con tu cuenta para ver los datos de tu iglesia.",
                         "Sign in to see your church's data."))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField(L.t("Correo", "Email"), text: $correo)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($foco, equals: .correo)
                    .submitLabel(.next)
                    .onSubmit { foco = .contrasena }

                SecureField(L.t("Contraseña", "Password"), text: $contrasena)
                    .textContentType(.password)
                    .focused($foco, equals: .contrasena)
                    .submitLabel(.go)
                    .onSubmit { entrar() }
            }
            .textFieldStyle(.roundedBorder)

            if let error = sesion.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Paleta.negativo)
                    .multilineTextAlignment(.center)
            }

            Button(action: entrar) {
                if sesion.ocupada {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(L.t("Entrar", "Sign in")).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sesion.ocupada || correo.isEmpty || contrasena.isEmpty)
        }
        .padding(Esp.panel)
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func entrar() {
        Task { await sesion.iniciarSesion(correo: correo, contrasena: contrasena) }
    }
}
