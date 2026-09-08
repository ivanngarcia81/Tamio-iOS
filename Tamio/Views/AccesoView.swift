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

// MARK: - Bienvenida

/// **Lo primero que ve alguien que abre Tamio, antes de las credenciales.**
///
/// Cuatro diapositivas que dicen para qué sirve la app, y después el acceso.
/// No es un diseño nuevo: es el `Welcome.tsx` del app web reflejado, con SUS
/// textos —los mismos cuatro títulos y los mismos cuatro párrafos, ya escritos
/// en los dos idiomas— para que las dos apps se presenten igual.
///
/// **Solo el recorrido, no el formulario.** El `Welcome` del web termina
/// pidiendo nombre de iglesia, ciudad y moneda; aquí eso no cabe todavía,
/// porque en iOS no se sabe NADA de la iglesia antes de entrar: las políticas
/// RLS exigen `auth.uid()`. Esa mitad va después del acceso, junto a la
/// pantalla de importar, y las dos están pendientes de decisión.
///
/// **El selector de idioma va en la primera diapositiva**, como en el web, y
/// por un motivo que no es de adorno: quien abre la app en un idioma que no
/// lee necesita poder salir de él antes de que se le pida nada. Es la única
/// pantalla de la app donde el idioma se puede cambiar sin haber entrado.
struct BienvenidaView: View {
    /// Se llama al terminar o al omitir. Quien manda la bandera es la raíz.
    let alTerminar: () -> Void

    @State private var paso = 0
    @State private var prefs = PreferenciasApp.compartidas

    private struct Diapositiva {
        let icono: String
        let titulo: String
        let texto: String
    }

    /// Los cuatro de `bienvenida.slideNTitulo` del web, palabra por palabra.
    /// Los iconos son los equivalentes en SF Symbols de los suyos, y los
    /// cuatro están comprobados contra el catálogo: un nombre que no existe
    /// no da error de compilación, solo deja el hueco vacío.
    private var diapositivas: [Diapositiva] {
        [.init(icono: "chart.line.uptrend.xyaxis",
               titulo: L.t("Las finanzas de tu iglesia, claras",
                           "Your church finances, made clear"),
               texto: L.t("Registra ingresos y gastos en segundos, con categorías, métodos de pago y comprobantes adjuntos. El inicio te muestra el balance del mes de un vistazo, con gráficas.",
                          "Record income and expenses in seconds, with categories, payment methods and attached receipts. The home screen shows the month's balance at a glance, with charts.")),
         .init(icono: "doc.richtext.fill",
               titulo: L.t("Reportes profesionales en PDF",
                           "Professional PDF reports"),
               texto: L.t("Estado financiero mensual, reporte anual y registros imprimibles — con folio de auditoría, firma del tesorero y el logo de tu iglesia. Listos para la asamblea.",
                          "Monthly financial statement, annual report and printable registers — with audit folio, treasurer's signature and your church logo. Assembly-ready.")),
         .init(icono: "person.2.fill",
               titulo: L.t("Miembros y constancias",
                           "Members and statements"),
               texto: L.t("Lleva el directorio de miembros, mira el historial de aportes de cada persona y genera su constancia anual de aportaciones en PDF con un clic.",
                          "Keep the member directory, see each person's contribution history and generate their annual contribution statement in PDF with one click.")),
         .init(icono: "square.and.arrow.down.fill",
               titulo: L.t("Tus datos, seguros y portables",
                           "Your data, safe and portable"),
               texto: L.t("Importa meses anteriores desde CSV, exporta todo cuando quieras y guarda copias de seguridad. Disponible en español e inglés.",
                          "Import previous months from CSV, export everything whenever you want and keep backup copies. Available in Spanish and English."))]
    }

    private var esUltima: Bool { paso == diapositivas.count - 1 }

    var body: some View {
        ZStack {
            Paleta.brand.ignoresSafeArea()

            VStack(spacing: 0) {
                // El recorrido, en un `TabView` de página: el gesto de deslizar
                // sale gratis y es el que la gente ya intenta. Los puntos
                // propios van abajo con los botones, así que se apagan los del
                // sistema — quedarían dos filas de puntos.
                TabView(selection: $paso) {
                    ForEach(Array(diapositivas.enumerated()), id: \.offset) { i, d in
                        diapositiva(d, primera: i == 0).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pie
            }
        }
        // Blanco sobre el verde de marca: es una pantalla de presentación, no
        // una lista de Ajustes, y aquí el color es el fondo y no un acento.
        .foregroundStyle(.white)
        // Esta pantalla ES la marca; que herede el modo oscuro del sistema
        // dejaría el verde con texto gris encima.
        .preferredColorScheme(.dark)
    }

    private func diapositiva(_ d: Diapositiva, primera: Bool) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Image(systemName: d.icono)
                .font(.system(size: 52, weight: .light))
                .padding(.bottom, 6)

            Text(d.titulo)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(d.texto)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: 420)

            if primera { selectorIdioma }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }

    /// El mismo sitio que en el web: la primera diapositiva.
    ///
    /// **Cápsulas propias y no un `Picker(.segmented)`**, por la razón que ya
    /// está escrita en el §0 del traspaso: un segmentado no es de cristal ni
    /// es transparente, dibuja el fondo opaco de UIKit. Sobre el verde de
    /// marca eso dejaba "Español" y "English" en gris oscuro sobre verde
    /// oscuro, ilegibles — se vio en la primera corrida, no leyendo el código.
    ///
    /// Los colores son los mismos dos botones del pie: elegido en blanco con
    /// letra verde, sin elegir en blanco al 18 %. Así la pantalla entera usa
    /// un solo lenguaje de color.
    private var selectorIdioma: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(PreferenciasApp.Idioma.allCases, id: \.self) { idioma in
                    let elegido = prefs.idioma == idioma
                    Button(idioma.etiqueta) { prefs.idioma = idioma }
                        .font(.subheadline.weight(elegido ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(elegido ? AnyShapeStyle(.white)
                                            : AnyShapeStyle(.white.opacity(0.18)),
                                    in: .capsule)
                        .foregroundStyle(elegido ? AnyShapeStyle(Paleta.brand)
                                                 : AnyShapeStyle(.white))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 340)

            Text(L.t("\"Automático\" usa el idioma del sistema.",
                     "\"Automatic\" uses the system language."))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, 14)
    }

    /// Puntos y botones. **No se mueven entre paso y paso**: "Siguiente" es el
    /// objeto que se pulsa cuatro veces seguidas, no un botón nuevo cada vez.
    /// Es la misma razón que está escrita en el web.
    private var pie: some View {
        VStack(spacing: 20) {
            HStack(spacing: 7) {
                ForEach(0..<diapositivas.count, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(i == paso ? 1 : 0.35))
                        .frame(width: 7, height: 7)
                }
            }

            HStack(spacing: 12) {
                Button(L.t("Omitir", "Skip")) { alTerminar() }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(.white.opacity(0.18), in: .capsule)
                    .foregroundStyle(.white)
                    // Sin salida en la última: ahí "Omitir" y "Comenzar"
                    // hacen lo mismo, y dos botones que hacen lo mismo se
                    // leen como si uno fuera a hacer otra cosa.
                    .opacity(esUltima ? 0 : 1)
                    .disabled(esUltima)

                // El primario se INVIERTE sobre el verde: relleno blanco y
                // letra verde. Un botón verde sobre fondo verde no se ve, y
                // es lo mismo que el web tuvo que resolver.
                Button(esUltima ? L.t("Comenzar", "Get started")
                                : L.t("Siguiente", "Next")) {
                    if esUltima { alTerminar() } else { paso += 1 }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.white, in: .capsule)
                .foregroundStyle(Paleta.brand)
                .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: paso)
    }
}

// MARK: - Configuración inicial

/// **La segunda mitad de la bienvenida, ya con sesión.**
///
/// Es el final del `Welcome.tsx` del web —nombre de iglesia, ciudad y moneda—
/// con sus mismos textos. Aquí va después del acceso y no antes por lo de
/// siempre: sin `auth.uid()` no se sabe a qué iglesia pertenece nadie.
///
/// **Cuándo aparece: cuando la iglesia no tiene nombre Y la bajada ya
/// terminó.** Las dos condiciones, no una. La primera sola es una trampa
/// conocida en este repo: la sincronización corre al arrancar, y una pantalla
/// que se dibuje antes de que acabe ve la iglesia vacía aunque tenga tres años
/// de datos en el servidor. Al segundo miembro que entra a una iglesia ya
/// montada no se le puede pedir que la configure otra vez.
///
/// **No lleva el "Explorar con datos de ejemplo" del web.** Allí ese botón
/// siembra la base de la propia iglesia con una congregación ficticia; aquí
/// eso escribiría en el Supabase de verdad. Lo equivalente en iOS es el modo
/// revisión, que se enciende al compilar y no se ofrece al usuario.
///
/// Cualquier miembro de la iglesia puede guardarla: la política
/// `actualizar_mi_iglesia` va por `church_id`, no por rol.
struct ConfiguracionInicialView: View {
    let alTerminar: () -> Void

    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var nombre = ""
    @State private var ciudad = ""
    @State private var moneda = Catalogos.monedaPorDefecto.codigo
    @State private var guardando = false
    @State private var error: String?
    @FocusState private var enfocado: Bool

    private var nombreVacio: Bool {
        nombre.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// **Si hay que pedir la configuración inicial.** Vive aquí y no dentro de
    /// la raíz para poder probarla: es una regla con dos condiciones y una de
    /// ellas —la de la sincronización— es justo la que no se ve fallar.
    ///
    /// - `nombre` vacío: iglesia recién creada. Es la misma señal que usa el
    ///   web (`esPrimerArranque` mira `church.nombre`); no hay marca de
    ///   "configurada" en el esquema, y contar movimientos no vale, porque una
    ///   iglesia real puede empezar sin ninguno.
    /// - `ultimaSincronizacion` no nula: la bajada terminó al menos una vez.
    ///   Sin esto, el primer arranque de un aparato ve la base local en blanco
    ///   y le pide al segundo miembro de una iglesia ya montada que la
    ///   configure otra vez — pisándole el nombre.
    static func haceFalta(nombre: String, ultimaSincronizacion: Date?) -> Bool {
        guard ultimaSincronizacion != nil else { return false }
        return nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(Paleta.brand)
                        Text(L.t("Bienvenido a Tamio", "Welcome to Tamio"))
                            .font(.title2.weight(.semibold))
                        Text(L.t("Configura tu iglesia en un minuto — todo se puede cambiar después en Ajustes.",
                                 "Set up your church in a minute — everything can be changed later in Settings."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    // Los rótulos van CORTOS, como en el web: en una fila de
                    // teléfono "Nombre de la iglesia" no deja sitio para
                    // escribir. El largo se queda en Ajustes, que es donde hay
                    // espacio y donde se va a volver a leer.
                    campo(L.t("Iglesia", "Church"), $nombre,
                          L.t("p. ej. Iglesia Nueva Vida", "e.g. New Life Church"))
                        .focused($enfocado)
                        .submitLabel(.go)
                        .onSubmit { if !nombreVacio { comenzar() } }
                    campo(L.t("Ciudad", "City"), $ciudad,
                          L.t("Opcional", "Optional"))
                    HStack {
                        Text(L.t("Moneda", "Currency"))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $moneda) {
                            ForEach(Catalogos.monedas) { m in
                                Text("\(m.codigo) \(m.simbolo)").tag(m.codigo)
                            }
                        }.labelsHidden()
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let error {
                            Text(error).foregroundStyle(Paleta.negativo)
                        }
                        Text(L.t("La moneda se usa en todos los importes y en los PDF. Se puede cambiar después en Ajustes › Iglesia.",
                                 "The currency is used in every amount and in the PDFs. You can change it later in Settings › Church."))
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            // **El botón fuera de la lista y en una barra de abajo.** Dentro
            // de la `List` el teclado lo tapaba entero: el campo se enfoca solo
            // al abrir, así que la primera vista de esta pantalla era un
            // formulario sin forma de continuar. Un `safeAreaInset` sube con
            // el teclado, medido con la app corriendo.
            .safeAreaInset(edge: .bottom) {
                Button(action: comenzar) {
                    if guardando {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(L.t("Comenzar", "Get started"))
                            .frame(maxWidth: .infinity)
                            .font(.body.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(nombreVacio || guardando)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .interactiveDismissDisabled()
        .task {
            moneda = cfg.config.moneda.isEmpty ? Catalogos.monedaPorDefecto.codigo
                                               : cfg.config.moneda
            enfocado = true
        }
    }

    private func campo(_ rotulo: String, _ bind: Binding<String>, _ ejemplo: String) -> some View {
        HStack {
            Text(rotulo).font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: 110, alignment: .leading)
            TextField(ejemplo, text: bind)
                .font(.subheadline).multilineTextAlignment(.trailing)
        }
    }

    /// Guarda y espera. **`guardarYa()` y no dejar que lo recoja el guardado
    /// diferido**: si la app se cierra en los segundos siguientes, la iglesia
    /// se queda sin nombre y la pantalla vuelve a salir en el próximo arranque
    /// como si no se hubiera hecho nada.
    private func comenzar() {
        guardando = true
        error = nil
        cfg.config.nombre = nombre.trimmingCharacters(in: .whitespaces)
        cfg.config.ciudad = ciudad.trimmingCharacters(in: .whitespaces)
        cfg.config.moneda = moneda
        Task {
            await cfg.guardarYa()
            // Que suba ahora y no en el próximo arranque: es el primer dato de
            // esta iglesia y el web lo está esperando.
            await MotorSincronizacion.compartido.sincronizar()
            guardando = false
            alTerminar()
        }
    }
}
