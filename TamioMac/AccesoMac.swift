import SwiftUI

/// **La pantalla de acceso del Mac.**
///
/// No reutiliza `AccesoView`: esa vive en `Views`, que este target no compila,
/// y son 1.044 líneas que cargan además con la bienvenida y el recorrido de
/// estreno del teléfono. Aquí hace falta lo que hace falta en un Mac: una
/// tarjeta centrada, dos casillas y el tabulador funcionando.
///
/// Se apoya en el MISMO `SesionSupabase` que el iPhone, así que quien entra
/// aquí entra igual que allí: mismas credenciales, mismo perfil, mismo rol.
struct AccesoMac: View {
    let sesion: SesionSupabase

    @State private var correo = ""
    @State private var contrasena = ""
    @State private var recuperando = false
    @FocusState private var foco: Casilla?

    private enum Casilla { case correo, contrasena }

    /// **El botón se apaga si falta algo.** Mandar un intento vacío al
    /// servidor solo sirve para que vuelva un error que ya sabíamos.
    private var puedeEntrar: Bool {
        !correo.trimmingCharacters(in: .whitespaces).isEmpty
            && !contrasena.isEmpty
            && !sesion.ocupada
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            tarjeta
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fondoAgrupado)
        .sheet(isPresented: $recuperando) {
            RecuperarContrasenaMac(sesion: sesion, correoInicial: correo)
        }
    }

    private var tarjeta: some View {
        VStack(spacing: 0) {
            Image("LogoTamio")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Tamio")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 14)
            Text(L.t("La tesorería de tu iglesia", "Your church's treasury"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                casilla(L.t("Correo", "Email")) {
                    TextField("", text: $correo, prompt: Text("nombre@iglesia.org"))
                        .textContentType(.username)
                        .focused($foco, equals: .correo)
                        .onSubmit { foco = .contrasena }
                }
                casilla(L.t("Contraseña", "Password")) {
                    SecureField("", text: $contrasena, prompt: Text("••••••••"))
                        .textContentType(.password)
                        .focused($foco, equals: .contrasena)
                        .onSubmit { entrar() }
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.top, 24)

            // El fallo, donde se mira después de pulsar: justo encima del
            // botón y no en una esquina.
            if let error = sesion.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Paleta.negativo)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }

            Button(action: entrar) {
                HStack(spacing: 8) {
                    if sesion.ocupada { ProgressView().controlSize(.small) }
                    Text(sesion.ocupada ? L.t("Entrando…", "Signing in…")
                                        : L.t("Entrar", "Sign in"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Paleta.brand)
            .controlSize(.large)
            .disabled(!puedeEntrar)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 18)

            Button(L.t("¿Olvidaste la contraseña?", "Forgot your password?")) {
                recuperando = true
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
            .padding(.top, 12)
        }
        .padding(34)
        .frame(width: 380)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 8)
        .onAppear { foco = .correo }
    }

    private func casilla<C: View>(_ rotulo: String, @ViewBuilder campo: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            campo()
        }
    }

    private func entrar() {
        guard puedeEntrar else { return }
        Task {
            await sesion.iniciarSesion(
                correo: correo.trimmingCharacters(in: .whitespaces),
                contrasena: contrasena)
        }
    }
}

// MARK: - Recuperar la contraseña

/// Los dos pasos del mismo camino que usa el iPhone: Supabase manda un código
/// de seis cifras al correo y aquí se teclea junto con la contraseña nueva.
///
/// **Sin enlace de redirección**, igual que allí: un enlace abriría el
/// navegador y dejaría la sesión iniciada FUERA de la app, que es lo contrario
/// de lo que quiere quien está mirando esta ventana.
struct RecuperarContrasenaMac: View {
    let sesion: SesionSupabase
    let correoInicial: String

    @Environment(\.dismiss) private var cerrar
    @State private var correo = ""
    @State private var codigo = ""
    @State private var nueva = ""
    @State private var enviado = false
    @State private var trabajando = false
    @State private var fallo: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(enviado ? L.t("Escribe el código", "Enter the code")
                         : L.t("Recuperar la contraseña", "Reset your password"))
                .font(.system(size: 17, weight: .bold))

            Text(enviado
                 ? L.t("Te mandamos un código de seis cifras a \(correo).",
                       "We sent a six-digit code to \(correo).")
                 : L.t("Te mandaremos un código de seis cifras para que puedas poner una nueva.",
                       "We'll send you a six-digit code so you can set a new one."))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if enviado {
                TextField(L.t("Código", "Code"), text: $codigo)
                SecureField(L.t("Contraseña nueva", "New password"), text: $nueva)
            } else {
                TextField(L.t("Correo", "Email"), text: $correo)
            }

            if let fallo {
                Text(fallo)
                    .font(.system(size: 12))
                    .foregroundStyle(Paleta.negativo)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                Button(enviado ? L.t("Cambiarla", "Change it")
                               : L.t("Mandar el código", "Send the code")) {
                    actuar()
                }
                .buttonStyle(.borderedProminent)
                .tint(Paleta.brand)
                .disabled(trabajando || !hayLoNecesario)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
        .frame(width: 360)
        .onAppear { correo = correoInicial }
    }

    private var hayLoNecesario: Bool {
        enviado ? (!codigo.isEmpty && !nueva.isEmpty)
                : !correo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func actuar() {
        trabajando = true
        fallo = nil
        Task {
            let limpio = correo.trimmingCharacters(in: .whitespaces)
            if enviado {
                if let e = await sesion.cambiarContrasena(correo: limpio, codigo: codigo, nueva: nueva) {
                    fallo = e
                } else {
                    cerrar()
                }
            } else {
                if let e = await sesion.enviarCodigoDeRecuperacion(correo: limpio) {
                    fallo = e
                } else {
                    enviado = true
                }
            }
            trabajando = false
        }
    }
}
