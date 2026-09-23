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

// MARK: - La bienvenida

/// **La bienvenida del Mac: una sola pantalla que dice dónde está cada cosa.**
///
/// Es la del handoff (`welVals()` y el bloque `welcome` de `Tamio macOS.dc.html`)
/// y no el recorrido de cuatro diapositivas del iPhone. Allí se desliza con el
/// dedo; aquí una ventana enseña las tres áreas a la vez y se quita de en medio
/// con un ↩. Es la regla de que el Mac, el iPad y el iPhone son apps distintas.
///
/// **Va ANTES del acceso**, como en el handoff —`welcome` gana a `locked`— y como
/// en iOS. Por eso el saludo y la iglesia son condicionales: sin sesión no se
/// sabe quién es ni de qué iglesia, porque RLS exige `auth.uid()`. Con sesión
/// —un Mac que ya había entrado, o volviendo a ella desde Ayuda— salen el
/// nombre y la iglesia de verdad, que es lo que dibuja el handoff.
///
/// La bandera es la MISMA del iPhone, `PreferenciasApp.bienvenidaVista`: del
/// aparato, y el reinicio de fábrica la borra.
struct BienvenidaMac: View {
    let sesion: SesionSupabase
    /// Se llama con "Empezar". Quien manda la bandera es la raíz.
    let alEmpezar: () -> Void

    @State private var iglesia = ConfiguracionIglesiaViewModel.compartido
    @Environment(\.colorScheme) private var esquema

    private struct Tarjeta {
        let icono: String
        let titulo: String
        let texto: String
        let donde: String
    }

    /// Los tres textos del handoff, palabra por palabra. Los iconos son los SF
    /// Symbols que dibujan lo mismo que sus trazos: una hoja con renglones, dos
    /// personas y una caja de archivo.
    private var tarjetas: [Tarjeta] {
        [.init(icono: "doc.text",
               titulo: L.t("Dinero que cuadra", "Money that adds up"),
               texto: L.t("Ofrendas, gastos y depósitos, cada uno con su folio, su comprobante y el nombre de quien lo registró.",
                          "Offerings, expenses and deposits, each one with its folio, its receipt and the name of whoever recorded it."),
               donde: L.t("Tesorería · Inicio, Movimientos, Depósitos",
                          "Treasury · Home, Movements, Deposits")),
         .init(icono: "person.2",
               titulo: L.t("Personas a las que se conoce", "People who are known"),
               texto: L.t("El registro, las ausencias, el seguimiento y las cartas de traslado salen de la misma ficha: la persona se escribe una vez.",
                          "The registry, absences, follow-up and transfer letters come out of the same file: you write the person once."),
               donde: L.t("Secretaría · Membresía, Servicios, Cartas",
                          "Secretary · Membership, Services, Letters")),
         .init(icono: "archivebox",
               titulo: L.t("Un registro que se queda", "A record that stays"),
               texto: L.t("Actas, registro y reportes. Nada se borra: una corrección se escribe junto a lo que corrige.",
                          "Minutes, log and reports. Nothing is deleted: a correction is written down next to what it corrects."),
               donde: L.t("Actas, Registro, Reportes", "Minutes, Log, Reports"))]
    }

    private var haySesion: Bool {
        if case .autenticada = sesion.estado { return true }
        return false
    }

    /// El nombre de pila, como en "Welcome to Tamio, Iván.". Sin sesión, nada.
    private var nombre: String? {
        guard haySesion,
              let primero = sesion.perfil.nombre.split(separator: " ").first
        else { return nil }
        return String(primero)
    }

    private var titulo: String {
        if let nombre {
            return L.t("Te damos la bienvenida a Tamio, \(nombre).", "Welcome to Tamio, \(nombre).")
        }
        return L.t("Te damos la bienvenida a Tamio.", "Welcome to Tamio.")
    }

    /// "Cornerstone Church" solo si hay sesión y la iglesia ya tiene nombre;
    /// antes de entrar, la configuración que hay es la de fábrica.
    private var deLaIglesia: String {
        let n = iglesia.config.nombre.trimmingCharacters(in: .whitespaces)
        guard haySesion, !n.isEmpty else {
            return L.t("de tu iglesia", "of your church")
        }
        return L.t("de \(n)", "of \(n)")
    }

    // Los rellenos del handoff que la paleta no tiene con nombre.
    private var rellenoMarca: Color { Paleta.brand.opacity(esquema == .dark ? 0.22 : 0.12) }
    /// `--content`: el suelo de las tres tarjetas.
    private var fondoTarjetas: Color { esquema == .dark ? Color(white: 0x1E / 255) : .white }
    /// `--surface2`: el pie.
    private var fondoPie: Color { esquema == .dark ? Color(white: 0x2B / 255) : Color(white: 0xF6 / 255) }

    var body: some View {
        VStack(spacing: 0) {
            cabecera
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Paleta.brand)
            Rectangle().fill(Color.filo.opacity(0.10)).frame(height: 0.5)
            fila
            Rectangle().fill(Color.filo.opacity(0.10)).frame(height: 0.5)
            pie
        }
        // El verde sube hasta el borde de arriba, por debajo de los semáforos,
        // como en el handoff: la barra de título no se pinta aparte.
        .ignoresSafeArea()
        .toolbar(removing: .title)
        .toolbarBackground(.hidden, for: .windowToolbar)
    }

    private var cabecera: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("LogoTamio")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                Text("Tamio")
                    .font(.system(size: 19, weight: .bold))
                    .tracking(-0.19)
                Text(L.t("para Mac", "for Mac"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.16), in: Capsule())
                    .padding(.leading, 4)
            }

            Text(titulo)
                .font(.system(size: 36, weight: .bold))
                .tracking(-0.9)
                .frame(maxWidth: 620)
                .padding(.top, 34)

            Text(L.t("La tesorería y la secretaría \(deLaIglesia), juntas en este Mac. Ya tienes una cuenta: esto es solo para que sepas dónde está cada cosa.",
                     "The treasury and the secretary’s desk \(deLaIglesia), together on this Mac. You already have an account: this is only so you know where things are."))
                .font(.system(size: 14.5))
                .lineSpacing(5.5)
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: 560)
                .padding(.top, 14)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.white)
        // 46 de la barra de título que el handoff dibuja dentro del verde, más
        // sus 6 de aire; 38 abajo.
        .padding(.top, 52)
        .padding(.bottom, 38)
        .padding(.horizontal, 54)
    }

    /// Las tres áreas, separadas por un filo de un punto como el `gap:1px` del
    /// handoff sobre su `--sep`.
    private var fila: some View {
        HStack(spacing: 0) {
            ForEach(Array(tarjetas.enumerated()), id: \.offset) { i, t in
                if i > 0 {
                    Rectangle().fill(Color.filo.opacity(0.10)).frame(width: 1)
                }
                tarjeta(t)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(fondoTarjetas)
    }

    private func tarjeta(_ t: Tarjeta) -> some View {
        VStack(spacing: 10) {
            Image(systemName: t.icono)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Paleta.brand)
                .frame(width: 30, height: 30)
                .background(rellenoMarca, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(t.titulo)
                .font(.system(size: 14.5, weight: .semibold))
                .tracking(-0.145)
            Text(t.texto)
                .font(.system(size: 12.5))
                .lineSpacing(5)
                .foregroundStyle(.secondary)
            Text(t.donde)
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 26)
        .padding(.bottom, 30)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var pie: some View {
        VStack(spacing: 16) {
            VStack(spacing: 5) {
                Text(L.t("Funciona sin señal.", "It works with no signal."))
                    .font(.system(size: 12.5, weight: .semibold))
                // La versión, del bundle: el handoff escribe "1.4.0 (218)"
                // como ejemplo, y una inventada manda a buscar fallos a otro
                // sitio (ver `VersionApp`).
                Text(L.t("Lo que registras se queda en este Mac y sube cuando hay internet. Versión \(VersionApp.completa).",
                         "What you record stays on this Mac and goes up when there is internet. Version \(VersionApp.completa)."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Button(action: alEmpezar) {
                HStack(spacing: 8) {
                    Text(L.t("Empezar", "Get started"))
                        .font(.system(size: 14, weight: .semibold))
                    Text("↩")
                        .font(.system(size: 14, weight: .medium))
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(minHeight: 40)
                .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .padding(.horizontal, 54)
        .background(fondoPie)
    }
}

// MARK: - Trae tus datos

/// **«Trae tus datos», la invitación que sigue a la bienvenida** (handoff
/// «Trae tus datos», M1). Misma forma que `BienvenidaMac` —franja verde, fila
/// de tarjetas y pie— porque es su segunda página: dos tarjetas en vez de tres
/// y un pie que dice dónde se encuentra después.
///
/// Solo se enseña con el padrón vacío y a quien puede dar de alta personas; lo
/// decide la raíz (`ofrecerTraerDatosSiToca`). ↩ elige el archivo y Esc lo deja
/// para después, como dicen las notas del handoff.
struct TraerDatosMac: View {
    let importar: () -> Void
    let descargarPlantilla: () -> Void
    let despues: () -> Void

    @Environment(\.colorScheme) private var esquema

    private var rellenoMarca: Color { Paleta.brand.opacity(esquema == .dark ? 0.22 : 0.12) }
    private var fondoTarjetas: Color { esquema == .dark ? Color(white: 0x1E / 255) : .white }
    private var fondoPie: Color { esquema == .dark ? Color(white: 0x2B / 255) : Color(white: 0xF6 / 255) }
    /// `--suelo` del handoff: el recuadro de «Sirve un archivo CSV…».
    private var suelo: Color { esquema == .dark ? Color(white: 0x1C / 255) : Color(red: 0xEA / 255, green: 0xEA / 255, blue: 0xEF / 255) }

    var body: some View {
        VStack(spacing: 0) {
            cabecera
                .frame(maxWidth: .infinity)
                .background(Paleta.brand)
            Rectangle().fill(Color.filo.opacity(0.10)).frame(height: 0.5)
            HStack(spacing: 0) {
                tarjetaImportar
                Rectangle().fill(Color.filo.opacity(0.10)).frame(width: 0.5)
                tarjetaPlantilla
            }
            .frame(maxHeight: .infinity)
            .background(fondoTarjetas)
            Rectangle().fill(Color.filo.opacity(0.10)).frame(height: 0.5)
            pie
        }
        .ignoresSafeArea()
        .toolbar(removing: .title)
        .toolbarBackground(.hidden, for: .windowToolbar)
    }

    private var cabecera: some View {
        VStack(spacing: 0) {
            Image("LogoTamio")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            Text(L.t("Trae a tu gente", "Bring your people"))
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.8)
                .padding(.top, 22)
            Text(L.t("Si ya tienes a las personas de la iglesia en un Excel, una hoja de Google u otro sistema, pásalas a Tamio de una vez. No se guarda nada hasta que lo revises.",
                     "If your church’s people are already in Excel, a Google Sheet or another system, bring them into Tamio in one go. Nothing is saved until you review it."))
                .font(.system(size: 14.5))
                .lineSpacing(5.5)
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: 560)
                .padding(.top, 12)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.white)
        .padding(.top, 52)
        .padding(.bottom, 34)
        .padding(.horizontal, 54)
    }

    private func icono(_ nombre: String) -> some View {
        Image(systemName: nombre)
            .font(.system(size: 15))
            .foregroundStyle(Paleta.brand)
            .frame(width: 30, height: 30)
            .background(rellenoMarca, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var tarjetaImportar: some View {
        VStack(spacing: 10) {
            icono("arrow.down")
            Text(L.t("Importar mi lista de personas", "Import my list of people"))
                .font(.system(size: 15, weight: .semibold))
            Text(L.t("Eliges el archivo, dices qué columna es cuál y ves qué va a pasar antes de guardar.",
                     "Choose the file, say which column is which, and see what will happen before saving."))
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
            // La frase del formato: la única que cambia el día que se lea el
            // .xlsx directamente.
            Text(L.t("Sirve un archivo CSV. En Excel: Archivo › Guardar como › CSV.",
                     "Use a CSV file. In Excel: File › Save As › CSV."))
                .font(.system(size: 12))
                .lineSpacing(3)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(suelo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: 320)
                .padding(.top, 4)
            Button(action: importar) {
                HStack(spacing: 8) {
                    Text(L.t("Elegir archivo…", "Choose file…"))
                        .font(.system(size: 13.5, weight: .semibold))
                    Text("↩").opacity(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 34)
                .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 30)
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var tarjetaPlantilla: some View {
        VStack(spacing: 10) {
            icono("doc.plaintext")
            Text(L.t("Descargar la plantilla", "Download the template"))
                .font(.system(size: 15, weight: .semibold))
            Text(L.t("¿No tienes nada ordenado? Rellena esta hoja con las columnas ya puestas y vuelve.",
                     "Nothing organized yet? Fill in this sheet with the columns already set, then come back."))
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
            Text(PlantillaImportar.personas.nombreDeArchivo)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
            Button(L.t("Descargar", "Download"), action: descargarPlantilla)
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 30)
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var pie: some View {
        HStack(spacing: 12) {
            Text(L.t("Lo encontrarás después en Configuración › Datos.",
                     "You’ll find it later in Settings › Data."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(L.t("Lo haré después", "I’ll do it later"), action: despues)
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Paleta.enlace)
                .keyboardShortcut(.cancelAction)
            Text("esc")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(fondoPie)
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
