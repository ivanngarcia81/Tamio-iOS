import SwiftUI

// MARK: - La piel de la puerta

/// **El verde de la puerta de Tamio, fijo y escrito a mano.**
///
/// Los tres tonos del degradado no salen del catálogo, y no es un descuido:
/// `Paleta.brand` cambia con el modo del sistema —#157A4B en claro y #2FBF71
/// en oscuro— y estas pantallas van SIEMPRE sobre el mismo verde oscuro, con
/// letra blanca encima. Sacarlos del catálogo dejaría la bienvenida en verde
/// chillón para media base de usuarios y el blanco sin contraste sobre él.
///
/// El del medio SÍ es el `TamioBrand` claro, letra por letra: es el verde de
/// la marca, y el degradado solo lo aclara arriba y lo apaga abajo.
enum Marca {
    static let verdeAlto = Color(red: 0x1E / 255, green: 0x95 / 255, blue: 0x60 / 255)
    static let verde     = Color(red: 0x15 / 255, green: 0x7A / 255, blue: 0x4B / 255)
    static let verdeHondo = Color(red: 0x0E / 255, green: 0x5B / 255, blue: 0x3A / 255)
}

extension Font {

    /// **El tamaño del diseño, pero escalando con Dynamic Type.**
    ///
    /// `Font.system(size:)` es un tamaño FIJO: no se mueve por mucho que el
    /// usuario suba la letra en Ajustes. La bienvenida y el acceso estaban
    /// escritas así entera —doce tamaños a mano, ni un `relativeTo` ni un
    /// `ScaledMetric`—, y medido con la app corriendo en AX1 los rótulos daban
    /// exactamente el mismo alto que en tamaño normal: el título 81.3 pt, el
    /// botón 56.0, "Tamio" 52.7. O sea que **la puerta de la app era la única
    /// pantalla que ignoraba el ajuste**, y justo la primera que ve alguien que
    /// lo tiene puesto porque le hace falta.
    ///
    /// `UIFontMetrics` devuelve ese mismo tamaño escalado por la categoría
    /// vigente, así que a tamaño normal el diseño no se mueve ni un píxel y a
    /// partir de ahí crece. El `relativeTo` dice CON QUÉ escala: los estilos
    /// grandes crecen menos que los pequeños, y usar `.body` para todo haría
    /// que un titular de 44 pt se disparara.
    static func escalada(_ tamano: CGFloat,
                         weight peso: Font.Weight = .regular,
                         relativeTo estilo: UIFont.TextStyle) -> Font {
        .system(size: UIFontMetrics(forTextStyle: estilo).scaledValue(for: tamano),
                weight: peso)
    }
}

/// **El fondo de la bienvenida y del acceso: un degradado y tres halos.**
///
/// Va aparte porque lo comparten las dos pantallas, y tienen que compartirlo:
/// quien pasa el recorrido cae en el acceso, y quien ya lo pasó abre la app
/// directo en el acceso. Si el fondo no fuera EL MISMO, la segunda vez que se
/// abre Tamio la puerta sería otra pantalla distinta.
///
/// Los halos son `RadialGradient` que se apagan a transparente, no círculos
/// difuminados: un `.blur` sobre un círculo sólido cuesta una pasada de
/// desenfoque en cada cuadro, y dos de ellos se mueven.
struct FondoMarca: View {
    /// Los dos halos que respiran. Se apaga en las capturas y en las pruebas
    /// de interfaz, donde una animación infinita deja a XCUITest esperando
    /// para siempre a que la pantalla se quede quieta.
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var flotando = false

    var body: some View {
        LinearGradient(stops: [.init(color: Marca.verdeAlto, location: 0),
                               .init(color: Marca.verde, location: 0.48),
                               .init(color: Marca.verdeHondo, location: 1)],
                       startPoint: UnitPoint(x: 0.42, y: 0),
                       endPoint: UnitPoint(x: 0.58, y: 1))
            // **`overlay` y no un `ZStack`, y `clipped()` detrás.** Los halos
            // miden 520 y salen del borde a propósito; en un `ZStack` eso hace
            // crecer al ZStack hasta caber los tres, y el fondo arrastraba
            // consigo el ancho de la pantalla entera — el título de la
            // bienvenida salía cortado por los dos lados. Un `overlay` mide lo
            // que mide el degradado y `clipped()` recorta lo que asoma.
            .overlay {
                halo(Color(red: 0.47, green: 1, blue: 0.75), opacidad: 0.38, lado: 460)
                    .offset(x: -190, y: -230)
                    .offset(y: flotando ? -10 : 0)
                    .animation(vaivén(11), value: flotando)

                halo(Color(red: 0.08, green: 0.35, blue: 0.24), opacidad: 0.55, lado: 520)
                    .offset(x: 200, y: 330)

                halo(.white, opacidad: 0.16, lado: 300)
                    .offset(x: 190, y: 60)
                    .offset(y: flotando ? -10 : 0)
                    .animation(vaivén(14), value: flotando)
            }
            .clipped()
            .ignoresSafeArea()
            .onAppear { if !menosMovimiento { flotando = true } }
    }

    private func halo(_ color: Color, opacidad: Double, lado: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(opacidad), color.opacity(0)],
                       center: .center, startRadius: 0, endRadius: lado * 0.34)
            .frame(width: lado, height: lado)
    }

    private func vaivén(_ segundos: Double) -> Animation {
        .easeInOut(duration: segundos).repeatForever(autoreverses: true)
    }
}

/// **El vidrio de la puerta: blanco translúcido con un filo de luz arriba.**
///
/// **No es `glassEffect`, y la excepción está medida.** El cristal de iOS 26
/// se adapta a lo que tiene detrás, y sobre este verde no se adapta igual en
/// los dos aparatos: la misma baldosa, con el mismo código, sale blanca
/// esmerilada en el iPhone 17 Pro y verde oscura en el iPad Pro 13". Para la
/// barra de una pantalla de la app eso da igual y hasta es lo que se quiere;
/// para la PUERTA no, porque es lo primero que se ve de Tamio y no puede
/// cambiar de identidad según el aparato desde el que se mire.
///
/// Así que el vidrio se pinta: un degradado de blanco al 34 % → 14 %, y
/// encima el filo —blanco al 55 % arriba, al 12 % abajo— que es lo que hace
/// que se lea como una pieza con grosor y no como una mancha clara.
struct VidrioMarca: ViewModifier {
    var radio: CGFloat = 28
    var opacidadAlta: Double = 0.34
    var opacidadBaja: Double = 0.14
    var sombra: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(opacidadAlta),
                                                  .white.opacity(opacidadBaja)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: radio, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.55),
                                                                  .white.opacity(0.12)],
                                                         startPoint: .top,
                                                         endPoint: .bottom),
                                          lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(sombra ? 0.35 : 0), radius: 15, x: 0, y: 14)
            }
    }
}

extension View {
    func vidrioMarca(radio: CGFloat = 28,
                     alta: Double = 0.34, baja: Double = 0.14,
                     sombra: Bool = true) -> some View {
        modifier(VidrioMarca(radio: radio, opacidadAlta: alta,
                             opacidadBaja: baja, sombra: sombra))
    }
}

/// La baldosa que lleva el icono de cada diapositiva, y el logo en la puerta.
struct BaldosaCristal<Contenido: View>: View {
    var lado: CGFloat = 92
    var radio: CGFloat = 28
    var alta: Double = 0.34
    var baja: Double = 0.14
    @ViewBuilder var contenido: Contenido

    var body: some View {
        contenido
            .frame(width: lado, height: lado)
            .vidrioMarca(radio: radio, alta: alta, baja: baja)
    }
}

/// El botón blanco de la marca: relleno blanco y letra verde honda.
///
/// **Se invierte sobre el verde**, que es lo que el web tuvo que resolver
/// también: un botón verde sobre fondo verde no se ve.
struct BotonMarca: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.escalada(18, weight: .semibold, relativeTo: .headline))
            .foregroundStyle(Marca.verdeHondo)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(.white, in: .rect(cornerRadius: 28))
            .shadow(color: .black.opacity(0.35), radius: 17, x: 0, y: 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// El botón secundario: cristal sobre el verde, letra blanca.
struct BotonMarcaCristal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.escalada(18, weight: .medium, relativeTo: .headline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .vidrioMarca(radio: 28, alta: 0.26, baja: 0.14, sombra: false)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Bienvenida

/// **Lo primero que ve alguien que abre Tamio, antes de las credenciales.**
///
/// Cuatro diapositivas que dicen para qué sirve la app, y después el acceso.
/// Los textos son los del `Welcome.tsx` del app web —los mismos títulos y los
/// mismos párrafos, ya escritos en los dos idiomas— para que las dos apps se
/// presenten igual.
///
/// **Dos de los cuatro se separan del web a propósito**, y conviene saber por
/// qué antes de "arreglarlo" devolviéndolos:
///
/// - La tercera dice *Membresía y secretaría* y no *Miembros y constancias*.
///   En iOS la secretaría entera existe —fichas, asistencia, cartas, actas con
///   folio, agenda—; prometer solo el directorio y la constancia anual vende
///   menos de lo que hay.
/// - La cuarta empieza por *Funciona sin señal y sincroniza al volver*. Eso es
///   de esta app y el web no lo tiene: el web ES el servidor. Es también lo
///   que más se pregunta de una app de iglesia, donde el salón suele estar en
///   un sótano sin cobertura.
///
/// Si un día el web adopta estos dos textos, se borra este párrafo y vuelven a
/// ser el mismo cuatro a cuatro.
///
/// **Solo el recorrido, no el formulario.** El `Welcome` del web termina
/// pidiendo nombre de iglesia, ciudad y moneda; aquí eso no cabe todavía,
/// porque en iOS no se sabe NADA de la iglesia antes de entrar: las políticas
/// RLS exigen `auth.uid()`. Esa mitad es `ConfiguracionInicialView`, y va
/// después del acceso.
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
    @Environment(\.horizontalSizeClass) private var claseAncho

    /// iPad, o iPhone en apaisado: hay altura de sobra y el bloque se centra.
    private var anchoRegular: Bool { claseAncho == .regular }

    private struct Diapositiva {
        let icono: String
        let titulo: String
        let texto: String
    }

    /// Los iconos son SF Symbols, y los cuatro están comprobados contra el
    /// catálogo: un nombre que no existe no da error de compilación, solo deja
    /// el hueco vacío.
    private var diapositivas: [Diapositiva] {
        [.init(icono: "chart.line.uptrend.xyaxis",
               titulo: L.t("Las finanzas de tu iglesia, claras",
                           "Your church finances, made clear"),
               texto: L.t("Registra ingresos y gastos en segundos, con categorías, métodos de pago y comprobantes adjuntos. El inicio te muestra el balance del mes de un vistazo.",
                          "Record income and expenses in seconds, with categories, payment methods and attached receipts. The home screen shows the month's balance at a glance.")),
         .init(icono: "doc.richtext.fill",
               titulo: L.t("Reportes profesionales en PDF",
                           "Professional PDF reports"),
               texto: L.t("Estado financiero mensual, reporte anual y registros imprimibles — con folio de auditoría, firma del tesorero y el logo de tu iglesia. Listos para la asamblea.",
                          "Monthly financial statement, annual report and printable registers — with audit folio, treasurer's signature and your church logo. Assembly-ready.")),
         .init(icono: "person.2.fill",
               titulo: L.t("Membresía y secretaría, al día",
                           "Membership and secretariat, up to date"),
               texto: L.t("Fichas de miembros, asistencia, cartas y actas con folio propio, agenda de servicios y actividades. Cada dato con el permiso de su rol.",
                          "Member records, attendance, letters and minutes with their own folio, service and activity calendar. Every piece of data behind its role's permission.")),
         .init(icono: "square.and.arrow.down.fill",
               titulo: L.t("Tus datos, seguros y portables",
                           "Your data, safe and portable"),
               texto: L.t("Funciona sin señal y sincroniza al volver. Importa meses anteriores desde CSV, exporta todo cuando quieras y guarda respaldos cifrados.",
                          "Works with no signal and syncs when it comes back. Import previous months from CSV, export everything whenever you want and keep encrypted backups."))]
    }

    private var esUltima: Bool { paso == diapositivas.count - 1 }

    var body: some View {
        ZStack {
            FondoMarca()

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

    /// **Alineada a la izquierda y no centrada.** Un párrafo de cuatro líneas
    /// centrado obliga al ojo a buscar dónde empieza cada renglón; el título
    /// grande de iOS 26 nace pegado al margen y el texto tiene que seguirlo.
    private func diapositiva(_ d: Diapositiva, primera: Bool) -> some View {
        // **Se puede desplazar, pero solo si hace falta.**
        // `.scrollBounceBehavior(.basedOnSize)` deja la diapositiva quieta
        // mientras el contenido cabe —que es siempre a tamaño normal, y ahí no
        // cambia ni un píxel—, y la vuelve desplazable en cuanto no cabe. Sin
        // esto, al hacer que la tipografía escalara, en AX1 el pie del selector
        // de idioma —"«Automatic» usa el idioma del sistema"— se quedaba fuera
        // de la página y no había forma de llegar a él.
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            // El de arriba solo en pantalla ancha: con uno solo, el de abajo
            // empuja el bloque contra el techo y el `alignment` del `frame` no
            // pinta nada. Con los dos, se reparten y el bloque queda centrado.
            if anchoRegular { Spacer(minLength: 0) }

            BaldosaCristal {
                Image(systemName: d.icono)
                    .font(.escalada(40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 34)

            Text(d.titulo)
                .font(.escalada(34, weight: .bold, relativeTo: .largeTitle))
                .tracking(-1)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            Text(d.texto)
                .font(.escalada(17, relativeTo: .body))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            if primera { selectorIdioma.padding(.top, 26) }

            Spacer(minLength: 0)
        }
        // **En el teléfono el bloque arranca a un tercio de la altura, como en
        // la maqueta; en el iPad se centra.** No es un capricho: la maqueta
        // está dibujada sobre 852 puntos de alto y ahí 132 deja el título
        // donde cae la mirada, pero sobre los 1366 de un iPad Pro los mismos
        // 132 dejan el texto pegado al borde de arriba y mil puntos de verde
        // vacío debajo. Se comprobó en el simulador de los dos.
        //
        // No se centra en el teléfono porque la primera diapositiva —la del
        // selector de idioma— es más alta que las otras tres, y centrando se
        // veía saltar el título al pasar de la primera a la segunda. En el
        // iPad ese salto también existe, pero sobre tanto hueco no se nota.
        .padding(.top, anchoRegular ? 0 : 132)
        .padding(.horizontal, 28)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    /// El mismo sitio que en el web: la primera diapositiva.
    ///
    /// **Cápsulas propias y no un `Picker(.segmented)`**, por la razón que ya
    /// está escrita en el §0 del traspaso: un segmentado no es de cristal ni
    /// es transparente, dibuja el fondo opaco de UIKit. Sobre el verde de
    /// marca eso dejaba "Español" y "English" en gris oscuro sobre verde
    /// oscuro, ilegibles — se vio en la primera corrida, no leyendo el código.
    ///
    /// El carril SÍ es de cristal, y las tres cápsulas van dentro: elegida en
    /// blanco con letra verde, las otras dos transparentes con letra blanca.
    private var selectorIdioma: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(PreferenciasApp.Idioma.allCases, id: \.self) { idioma in
                    let elegido = prefs.idioma == idioma
                    Button(idioma.etiqueta) { prefs.idioma = idioma }
                        .font(.escalada(15, weight: .semibold, relativeTo: .subheadline))
                        // Tres cápsulas de ancho igual: con la letra grande
                        // "Automatic" no cabía y salía "Automa…". Recortar el
                        // nombre de un idioma es peor que encogerlo.
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(elegido ? AnyShapeStyle(.white)
                                            : AnyShapeStyle(.clear),
                                    in: .rect(cornerRadius: 18))
                        .foregroundStyle(elegido ? AnyShapeStyle(Marca.verdeHondo)
                                                 : AnyShapeStyle(.white.opacity(0.9)))
                }
            }
            .buttonStyle(.plain)
            .padding(4)
            .vidrioMarca(radio: 22, alta: 0.22, baja: 0.12, sombra: false)

            Text(L.t("«Automático» usa el idioma del sistema.",
                     "\"Automatic\" uses the system language."))
                .font(.escalada(13, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.leading, 2)
        }
    }

    /// Puntos y botones. **No se mueven entre paso y paso**: "Siguiente" es el
    /// objeto que se pulsa cuatro veces seguidas, no un botón nuevo cada vez.
    /// Es la misma razón que está escrita en el web.
    private var pie: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<diapositivas.count, id: \.self) { i in
                    Button { paso = i } label: {
                        Circle()
                            .fill(.white.opacity(i == paso ? 1 : 0.35))
                            .frame(width: 8, height: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L.t("Paso \(i + 1)", "Step \(i + 1)"))
                }
            }

            // **El ancho a mano y no con `layoutPriority`.** La maqueta da al
            // primario 1.35 veces el secundario, y una prioridad de disposición
            // no reparte proporciones: reparte QUIÉN SE SIRVE PRIMERO. Con los
            // dos botones pidiendo `.infinity`, el de más prioridad se quedaba
            // el ancho entero y "Omitir" desaparecía por la izquierda — se vio
            // en la primera corrida en el simulador.
            GeometryReader { g in
                let hueco: CGFloat = 12
                HStack(spacing: esUltima ? 0 : hueco) {
                    // Sin salida en la última: ahí "Omitir" y "Comenzar" hacen
                    // lo mismo, y dos botones que hacen lo mismo se leen como
                    // si uno fuera a hacer otra cosa.
                    if !esUltima {
                        Button(L.t("Omitir", "Skip")) { alTerminar() }
                            .buttonStyle(BotonMarcaCristal())
                            .frame(width: (g.size.width - hueco) / 2.35)
                    }

                    Button(esUltima ? L.t("Comenzar", "Get started")
                                    : L.t("Siguiente", "Next")) {
                        if esUltima { alTerminar() } else { paso += 1 }
                    }
                    .buttonStyle(BotonMarca())
                }
            }
            .frame(height: 56)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.2), value: paso)
    }
}

// MARK: - Acceso

/// **La puerta de sesión, y la quinta pantalla de la maqueta de bienvenida.**
///
/// Sin ella los repositorios reales no devuelven nada, porque las políticas
/// RLS exigen `auth.uid()`.
///
/// **Comparte el fondo con la bienvenida a propósito.** El recorrido termina
/// aquí, y quien ya lo pasó abre la app directamente aquí: si esta pantalla
/// fuera el formulario gris de una lista de Ajustes, la segunda vez que se
/// abre Tamio la puerta sería otra app.
///
/// Los campos SÍ son blancos y opacos, y son lo único de la pantalla que no es
/// de cristal: se escribe dentro de ellos, y texto negro sobre un cristal que
/// deja pasar el verde no se lee. El cristal es la tarjeta que los envuelve.
struct AccesoView: View {
    let sesion: SesionSupabase

    @State private var correo = ""
    @State private var contrasena = ""
    @State private var recuperando = false
    @FocusState private var foco: Campo?

    private enum Campo { case correo, contrasena }

    private var incompleto: Bool { correo.isEmpty || contrasena.isEmpty }
    /// El aviso de "faltan datos", que es NUESTRO: `SesionSupabase.error` es
    /// `private(set)` y guarda lo que contestó el servidor.
    @State private var aviso: String?

    var body: some View {
        ZStack {
            FondoMarca()

            // **Centrado a lo alto, y dentro de un `ScrollView` de todas
            // formas.** La maqueta centra el bloque; el `minHeight` del
            // tamaño del contenedor lo centra mientras quepa, y en cuanto no
            // quepa —letra grande, o el teclado abierto en un iPhone SE— deja
            // de centrar y se puede desplazar. Un `VStack` con `Spacer` a los
            // lados centraría igual, pero recortaría en vez de desplazarse.
            GeometryReader { g in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BaldosaCristal(lado: 92, radio: 27, alta: 0.4, baja: 0.16) {
                        Image("LogoTamio")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 82, height: 82)
                            .clipShape(.rect(cornerRadius: 22))
                    }
                    .padding(.bottom, 22)

                    Text("Tamio")
                        .font(.escalada(44, weight: .bold, relativeTo: .largeTitle))
                        .tracking(-1.6)
                        .padding(.bottom, 10)

                    Text(L.t("Entra con tu cuenta para ver los datos de tu iglesia.",
                             "Sign in to see your church's data."))
                        .font(.escalada(17, relativeTo: .body))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 30)

                    tarjetaCampos

                    if let texto = aviso ?? sesion.error {
                        Text(texto)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.top, 12)
                            .padding(.horizontal, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: entrar) {
                        if sesion.ocupada {
                            ProgressView().tint(Marca.verdeHondo)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(L.t("Entrar", "Sign in")).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(BotonMarca())
                    // **Solo se apaga mientras entra, no por estar los campos
                    // vacíos.** Apagado por omisión medía 2.99:1, y es el
                    // primer botón de la app. Mismo remedio que en la
                    // configuración inicial: no se maquilla el botón apagado,
                    // se quita el motivo de apagarlo. `entrar()` dice qué falta
                    // y lleva el foco al campo.
                    .disabled(sesion.ocupada)
                    .padding(.top, 16)

                    Button(L.t("¿Olvidaste tu contraseña?", "Forgot your password?")) {
                        recuperando = true
                    }
                    .font(.escalada(15, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.78))
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                }
                .frame(maxWidth: 420, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.vertical, 40)
                .frame(minHeight: g.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $recuperando) {
            RecuperarClaveView(sesion: sesion, correo: correo)
        }
    }

    /// **Una sola tarjeta blanca con los dos campos pegados, no dos pastillas
    /// sueltas dentro de un marco de vidrio.**
    ///
    /// La primera versión de esta pantalla puso el vidrio alrededor y dejó los
    /// campos flotando dentro con hueco entre ellos: sobre el verde se leía
    /// como un recuadro verde claro con dos pastillas, no como el campo de
    /// texto de una app de iOS. La maqueta del traspaso lo tiene resuelto de la
    /// otra manera, que es la de siempre en iOS —Ajustes, el acceso de Apple—:
    /// una tarjeta blanca de esquina 22, los dos campos de 56 pegados uno al
    /// otro, y entre ellos un filo negro al 10 % que los separa sin partir la
    /// tarjeta. La sombra es la que la despega del verde.
    private var tarjetaCampos: some View {
        VStack(spacing: 0) {
            TextField("", text: $correo, prompt: prompt(L.t("Correo", "Email")))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($foco, equals: .correo)
                .submitLabel(.next)
                .onChange(of: correo) { if !incompleto { aviso = nil } }
                .onSubmit { foco = .contrasena }

            // El filo entre los dos, del ancho entero de la tarjeta.
            Rectangle()
                .fill(.black.opacity(0.1))
                .frame(height: 1)

            SecureField("", text: $contrasena, prompt: prompt(L.t("Contraseña", "Password")))
                .textContentType(.password)
                .focused($foco, equals: .contrasena)
                .submitLabel(.go)
                // Sin el `if`: con un campo vacío no hacía nada y no decía
                // por qué. Ahora entra en `entrar`, que es quien avisa.
                .onSubmit { entrar() }
        }
        .textFieldStyle(CampoBlanco())
        .background(.white)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 16)
    }

    /// El marcador de posición se escribe a mano porque el campo va sobre
    /// blanco dentro de una pantalla en modo oscuro forzado: el gris que pone
    /// el sistema se calcula para el fondo del sistema, no para este.
    private func prompt(_ texto: String) -> Text {
        Text(texto).foregroundStyle(.black.opacity(0.45))
    }

    private func entrar() {
        // Sin correo o sin contraseña no hay a quién preguntar, pero eso se
        // DICE y se lleva el foco al campo que falta, en vez de dejar un botón
        // gris que no responde y no explica por qué.
        guard !incompleto else {
            aviso = L.t("Escribe tu correo y tu contraseña.",
                        "Enter your email and password.")
            foco = correo.isEmpty ? .correo : .contrasena
            return
        }
        aviso = nil
        Task { await sesion.iniciarSesion(correo: correo, contrasena: contrasena) }
    }
}

/// El campo blanco de la puerta: alto de 54, esquina de 21 y letra negra.
struct CampoBlanco: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.escalada(17, relativeTo: .body))
            .foregroundStyle(.black)
            .tint(Marca.verde)
            .padding(.horizontal, 18)
            .frame(height: 56)
    }
}

// MARK: - Recuperar la contraseña

/// **Los dos pasos de recuperar el acceso, en una hoja.**
///
/// Es el mismo flujo del web (`Login.tsx`) y con sus mismos textos: se pide el
/// correo, Supabase manda un código de seis cifras, y con el código se pone la
/// contraseña nueva. **No es un enlace**: un enlace de recuperación abre el
/// navegador y deja la sesión iniciada fuera de la app.
///
/// Al terminar el segundo paso **ya se está dentro** —`verifyOTP` inicia la
/// sesión—, así que la hoja se cierra sola y la raíz cambia de pantalla. No se
/// vuelve a pedir la contraseña recién escrita.
struct RecuperarClaveView: View {
    let sesion: SesionSupabase
    /// El correo que ya estaba escrito en la puerta, para no teclearlo dos veces.
    let correo: String

    @Environment(\.dismiss) private var cerrar

    @State private var destino = ""
    @State private var codigo = ""
    @State private var nueva = ""
    @State private var paso: Paso = .pedirCorreo
    @State private var trabajando = false
    @State private var error: String?
    @State private var aviso: String?

    private enum Paso { case pedirCorreo, ponerClave }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if paso == .pedirCorreo {
                        TextField(L.t("Correo", "Email"), text: $destino)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        TextField(L.t("Código de verificación", "Verification code"), text: $codigo)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        SecureField(L.t("Nueva contraseña", "New password"), text: $nueva)
                            .textContentType(.newPassword)
                    }
                } header: {
                    Text(paso == .pedirCorreo
                         ? L.t("Te enviaremos un código de verificación a tu correo.",
                               "We'll send a verification code to your email.")
                         : L.t("Escribe el código que te llegó y tu nueva contraseña.",
                               "Enter the code you received and your new password."))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error {
                            Text(error).foregroundStyle(Paleta.negativo)
                        }
                        if let aviso {
                            Text(aviso).foregroundStyle(Paleta.brand)
                        }
                        if paso == .pedirCorreo {
                            Text(L.t("Te enviaremos un código para poner una contraseña nueva. Revisa también la carpeta de spam.",
                                     "We'll send you a code to set a new password. Check your spam folder too."))
                        } else {
                            Text(L.t("La contraseña debe tener al menos 6 caracteres.",
                                     "Password must be at least 6 characters."))
                        }
                    }
                }

                Section {
                    Button(action: avanzar) {
                        if trabajando {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(paso == .pedirCorreo
                                 ? L.t("Enviar código", "Send code")
                                 : L.t("Cambiar contraseña", "Change password"))
                                .frame(maxWidth: .infinity)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .disabled(trabajando || !completo)
                }
            }
            .navigationTitle(paso == .pedirCorreo
                             ? L.t("Recuperar contraseña", "Reset password")
                             : L.t("Nueva contraseña", "New password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Volver", "Back")) { cerrar() }
                }
            }
        }
        .onAppear { destino = correo }
    }

    private var completo: Bool {
        switch paso {
        case .pedirCorreo: !destino.trimmingCharacters(in: .whitespaces).isEmpty
        case .ponerClave:  codigo.trimmingCharacters(in: .whitespaces).count >= 6 && nueva.count >= 6
        }
    }

    private func avanzar() {
        let limpio = destino.trimmingCharacters(in: .whitespaces)
        trabajando = true
        error = nil
        Task {
            switch paso {
            case .pedirCorreo:
                error = await sesion.enviarCodigoDeRecuperacion(correo: limpio)
                if error == nil {
                    aviso = L.t("Te enviamos un código a \(limpio). Revisa tu correo (y la carpeta de spam).",
                                "We sent a code to \(limpio). Check your email (and spam folder).")
                    paso = .ponerClave
                }
            case .ponerClave:
                error = await sesion.cambiarContrasena(
                    correo: limpio,
                    codigo: codigo.trimmingCharacters(in: .whitespaces),
                    nueva: nueva)
                // Con la sesión ya iniciada, cerrar la hoja deja ver la app.
                if error == nil { cerrar() }
            }
            trabajando = false
        }
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
    /// - **El nombre es el que siembra el registro.** `crear_perfil_al_registrarse`
    ///   crea la iglesia con `coalesce(nullif(meta->>'iglesia',''), 'Mi Iglesia')`,
    ///   así que una iglesia recién nacida NO se llama "": se llama
    ///   **"Mi Iglesia"**. El web compara contra ese literal
    ///   (`esPrimerArranque`) y aquí se hacía contra vacío — que no ocurre
    ///   nunca, o sea que esta pantalla no se enseñaba JAMÁS. Se descubrió el
    ///   8-sep-2026 mirando la cuenta de una persona real, no el código.
    ///   El vacío se sigue tratando como sin configurar, por si alguien lo
    ///   borra a mano.
    /// - `ultimaSincronizacion` no nula: la bajada terminó al menos una vez.
    ///   Sin esto, el primer arranque de un aparato ve la base local en blanco
    ///   y le pide al segundo miembro de una iglesia ya montada que la
    ///   configure otra vez — pisándole el nombre.
    /// - `yaConfigurado`: la bandera de este aparato, equivalente al
    ///   `localStorage` del web. Una iglesia puede llamarse "Mi Iglesia" de
    ///   verdad; sin esta bandera se le pediría configurarse en cada arranque.
    static func haceFalta(nombre: String,
                          ultimaSincronizacion: Date?,
                          yaConfigurado: Bool = false,
                          baseCaida: Bool = false) -> Bool {
        // **Con la base caída no se pide configurar nada.** Medido en un iPad
        // el 10-sep: con la base en memoria la configuración está vacía, así
        // que el nombre es el de fábrica y esta hoja se abría encima de la
        // franja que dice «nada de lo que captures aquí se está guardando».
        // Dos elementos contradiciéndose en la misma pantalla — y como la hoja
        // es modal, dejaba el iPad SIN SALIDA a Ajustes (`Show Sidebar` no se
        // podía tocar), que es justo donde se explica la avería.
        guard !baseCaida else { return false }
        guard ultimaSincronizacion != nil, !yaConfigurado else { return false }
        let n = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty || n.compare(Self.nombreSembrado,
                                      options: .caseInsensitive) == .orderedSame
    }

    /// El literal que escribe el disparador de registro en Supabase. Si
    /// cambia allí, cambia aquí: son el mismo dato en dos sitios y no hay
    /// forma de que el compilador lo note.
    static let nombreSembrado = "Mi Iglesia"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.escalada(42, weight: .light, relativeTo: .largeTitle))
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
                        .onChange(of: nombre) { if !nombreVacio { error = nil } }
                        // Sin el `if`: con el nombre vacío, "go" no hacía
                        // nada y no decía por qué. Ahora entra en `comenzar`,
                        // que es quien avisa.
                        .onSubmit { comenzar() }
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
                // **Solo se apaga mientras guarda, no por estar el nombre
                // vacío.** Deshabilitado por defecto, este botón medía 1.42:1
                // de contraste —lo peor de la app— y era lo PRIMERO que veía
                // alguien que estrena Tamio: un formulario y una barra gris sin
                // texto. No se puede arreglar desde la etiqueta: `.disabled`
                // sobre `.borderedProminent` no atenúa el texto, repinta el
                // botón entero, así que ni `apagadoLegible` ni un color
                // explícito ni el `tint` mueven el número (medido: 1.42:1 las
                // tres veces).
                //
                // Así que no se maquilla el botón apagado: se quita el motivo
                // de apagarlo. Ahora dice qué falta y lleva al campo, que es lo
                // que el usuario necesita saber. Mismo razonamiento que ya está
                // escrito en `RevisarView`: una cápsula que parece botón y no
                // responde promete algo que no cumple.
                .disabled(guardando)
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
        // Sin nombre no se puede seguir —una iglesia sin nombre no tiene
        // membrete—, pero eso se DICE, no se deja adivinar por un botón gris.
        guard !nombreVacio else {
            error = L.t("Escribe el nombre de la iglesia para continuar.",
                        "Enter your church's name to continue.")
            enfocado = true
            return
        }
        guardando = true
        error = nil
        cfg.config.nombre = nombre.trimmingCharacters(in: .whitespaces)
        cfg.config.ciudad = ciudad.trimmingCharacters(in: .whitespaces)
        cfg.config.moneda = moneda
        Task {
            await cfg.guardarYa()
            PreferenciasApp.iglesiaConfigurada = true
            // Que suba ahora y no en el próximo arranque: es el primer dato de
            // esta iglesia y el web lo está esperando.
            await MotorSincronizacion.compartido.sincronizar()
            guardando = false
            alTerminar()
        }
    }
}
