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
        .background(Color.suelo)
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

// MARK: - El candado de este Mac

/// **La app tapada, esperando a que la abran.**
///
/// Vive aquí y no en un archivo suyo porque es lo mismo que `AccesoMac`: la
/// pantalla de quien todavía no puede ver las cuentas. La diferencia es cuál de
/// las dos puertas está cerrada — aquélla es la de la iglesia, en el servidor;
/// ésta es la de este ordenador.
///
/// **Las palabras son las del iPhone**, `PantallaBloqueo`, y a propósito: es el
/// mismo candado contado a la misma persona, y dos redacciones distintas
/// envejecen mal. Lo que no se puede compartir es la vista: aquélla vive en
/// `Tamio/Views`, que el Mac no compila, y pinta con colores de UIKit.
struct CandadoMac: View {
    @Bindable var bloqueo: BloqueoBiometrico

    var body: some View {
        ZStack {
            // Opaco del todo: un candado que deja leer el saldo por detrás no
            // es un candado. Va sobre `Color.suelo`, que es el fondo de la app
            // y sigue al tema elegido.
            Color.suelo.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Paleta.brand)

                VStack(spacing: 8) {
                    Text("Tamio").font(.system(size: 22, weight: .bold))
                    Text(L.t("Las cuentas de la iglesia están bloqueadas.",
                             "The church's accounts are locked."))
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await bloqueo.abrir() }
                } label: {
                    Text(L.t("Desbloquear con \(BloqueoBiometrico.nombreBiometria)",
                             "Unlock with \(BloqueoBiometrico.nombreBiometria)"))
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .tint(Paleta.brand)
                .keyboardShortcut(.defaultAction)

                if let error = bloqueo.error {
                    Text(error)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Paleta.negativo)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(40)
        }
        // Se pide en cuanto aparece: tener que pulsar un botón para que salga
        // el diálogo del sistema es un gesto de más en algo que se repite
        // varias veces al día. El botón se queda para reintentar.
        .task { await bloqueo.abrir() }
    }
}
