import SwiftUI

/// **Una fila de formulario que sigue diciendo qué es cuando tiene dato.**
///
/// El primer argumento de `TextField` es el MARCADOR DE POSICIÓN, y un marcador
/// solo se ve con el campo vacío. Usarlo de rótulo —que es como estaban
/// escritos casi todos los formularios de la app— funciona hasta que hay algo
/// escrito: a partir de ahí la fila enseña un valor suelto y no dice de qué es.
/// Al EDITAR un aportante la hoja entera era una columna de "2018",
/// "TOBA880101AB1", "Married", "2016".
///
/// Y no es solo de mirar: medido con XCUITest, esos campos daban la etiqueta de
/// accesibilidad **vacía**, así que VoiceOver leía el valor sin decir de qué
/// campo era. `LabeledContent` arregla las dos cosas a la vez.
///
/// **No vale para todo, y por eso no está aplicada en todas partes.** Se queda
/// el marcador donde el texto no es un rótulo sino una instrucción —"+ Agregar
/// acuerdo", "Buscar por nombre", "Salutation · e.g. To whom it may concern"—,
/// en los editores de varias líneas, cuyo nombre lo dice la cabecera de su
/// sección, y donde el rótulo es tan largo que no cabe a la izquierda de su
/// propio valor en 390 pt.
struct FilaCampo: View {
    let rotulo: String
    @Binding var texto: String

    init(_ rotulo: String, _ texto: Binding<String>) {
        self.rotulo = rotulo
        self._texto = texto
    }

    var body: some View {
        LabeledContent(rotulo) {
            // El marcador va VACÍO: con el rótulo ya a la izquierda, repetirlo
            // aquí lo escribe dos veces en la misma fila mientras el campo esté
            // sin llenar. Se vio en la primera captura, no leyendo el código.
            TextField("", text: $texto)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
}

/// Etiqueta redonda con tinte de color ("Diezmo", "Folio 1042", "Sin
/// depositar"). El color solo aparece aquí porque es dato, no decoración.
struct Pill: View {
    let texto: String
    var color: Color = .gray

    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, Esp.chip)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// Fila de "campo: valor" del detalle, con un enlace opcional ("Ver ficha").
/// Antes aceptaba un `link:` que pintaba texto con `Paleta.enlace` y NADA
/// más: parecía tocable y no lo era. Se quitó en vez de darle acción para que
/// no vuelva a colarse un falso enlace por copiar esta pieza.
struct FieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value).font(.subheadline)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 10)
    }
}

/// Envoltura de tarjeta blanca con borde, para no repetir el fondo redondeado.
struct Tarjeta<Contenido: View>: View {
    @ViewBuilder let contenido: Contenido
    var body: some View {
        contenido
            .padding(Esp.tarjeta)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75))
    }
}

/// Título de sección en versalitas grises ("RASTRO DE AUDITORÍA").
struct TituloSeccion: View {
    let texto: String
    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// Fila de hub de iPhone: círculo de color con símbolo, título + subtítulo,
/// badge rojo opcional. Diseño fiel al handoff de Tamio iPhone.
struct HubRow: View {
    /// SF Symbol. Antes eran iniciales en castellano ("Mo", "Ap", "Ag") que
    /// quedaban junto a títulos en inglés; un símbolo no tiene idioma.
    let icono: String
    let color: Color
    let titulo: String
    let subtitulo: String
    var badge: Int? = nil

    /// **El símbolo no es blanco: es el que se lea sobre SU placa.**
    ///
    /// Blanco fijo era 2.43:1 sobre el cian de Cartas y 2.54:1 sobre el verde
    /// de Movimientos, contra un mínimo de 4.5:1. Con las placas de `Paleta`
    /// —que ahora cambian con el tema— `sobre(_:_:)` devuelve blanco en claro y
    /// el casi negro en oscuro, igual para las nueve filas, así que la columna
    /// de símbolos sigue siendo de un solo color dentro de cada apariencia.
    ///
    /// Hace falta el `colorScheme` del entorno: resolver por
    /// `UITraitCollection.current` dentro de un `body` devuelve a veces el tema
    /// contrario.
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icono)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paleta.sobre(color, esquema))
                .frame(width: 36, height: 36)
                .background(color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.weight(.semibold))
                Text(subtitulo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let badge {
                // El rojo de badge es #FF6B6B en oscuro, donde el blanco
                // encima daba 2.30:1. `sobreRelleno` es el color que la paleta
                // ya tiene medido para sus propios rellenos: 6.48:1 y 6.14:1.
                Text("\(badge)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Paleta.sobreRelleno)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Paleta.badge, in: Circle())
            }
        }
        .padding(.vertical, 4)
    }
}

/// **Las iniciales de una persona en un disco de color.**
///
/// Nueve copias de las mismas cuatro líneas había repartidas por la app, todas
/// con la inicial BLANCA sobre el color pleno del estado: sobre el verde de
/// marca eso da ~2:1, y parecido sobre el naranja y el azul. Aquí el disco va
/// tintado y la inicial en el color pleno —el mismo trato que ya reciben los
/// íconos de categoría de la lista de movimientos—, que sube a ~4:1 y aguanta
/// las dos apariencias con los colores que ya hay.
///
/// El tamaño de letra sale del diámetro: los avatares miden entre 30 y 60 pt
/// según dónde estén y cada copia elegía su fuente a mano.
struct Avatar: View {
    let iniciales: String
    let color: Color
    var lado: CGFloat = 38

    var body: some View {
        Text(iniciales)
            .font(.system(size: lado * 0.36, weight: .bold))
            .foregroundStyle(color)
            .frame(width: lado, height: lado)
            .background(color.opacity(0.25), in: Circle())
    }
}

// MARK: - Previa de documento

private struct AltoHojaKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct AnchoDisponibleKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// **Una hoja de ancho carta enseñada dentro del ancho que haya.**
///
/// Las hojas de los documentos llevan `.frame(width: PDFExport.anchoCarta)`,
/// 612 pt, porque es el papel que van a ocupar. Metidas tal cual en la previa,
/// en un iPhone de ~393 pt se salían por los dos lados: se leía "sia Nueva
/// Vida", "ing report" y "ucía Torres Beltrán". Y como la hoja estiraba a 612
/// la columna entera, el segmentado de periodo que tenía encima quedaba
/// cortado por los dos lados también.
///
/// Se ESCALA en vez de reflowear a propósito: la previa tiene que enseñar el
/// papel que va a salir de la impresora, no una versión adaptada de él. La
/// generación del PDF sigue a 612 pt sin tocar; aquí solo se mira.
///
/// En iPad, donde los 612 pt caben, la escala queda en 1 y no cambia nada.
struct HojaCartaEscalada<Contenido: View>: View {
    @ViewBuilder let contenido: Contenido

    /// Alto natural de la hoja a tamaño real. Hace falta medirlo porque
    /// `scaleEffect` no cambia el espacio que el contenido reserva: sin este
    /// alto la previa dejaría debajo un hueco del tamaño de la hoja sin
    /// escalar.
    @State private var altoHoja: CGFloat = 0
    /// Se arranca en ancho carta para que la primera pasada no dé escala cero
    /// y la hoja parpadee en blanco.
    @State private var anchoDisponible: CGFloat = PDFExport.anchoCarta

    private var escala: CGFloat { min(1, anchoDisponible / PDFExport.anchoCarta) }

    /// **El ancho se mide en una capa que la hoja no toca.**
    ///
    /// Antes el medidor colgaba del mismo `frame` que ya contenía la hoja, y
    /// una hoja de 612 pt no deja a su contenedor medir menos de 612:
    /// `maxWidth: .infinity` da el máximo entre lo propuesto y lo que pide el
    /// hijo. Así que en un iPhone de 393 pt se medían 612, la escala salía 1 y
    /// el bucle se quedaba quieto ahí — el componente existía para arreglar
    /// este fallo exacto y no lo arreglaba.
    ///
    /// Ahora el que mide es un `Color.clear` sin hijos, que sí se conforma con
    /// lo que le proponga el padre, y la hoja va encima en un `overlay`, que no
    /// participa en el layout y por eso no puede volver a empujar la medida.
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: altoHoja * escala)
            .background(GeometryReader { g in
                Color.clear.preference(key: AnchoDisponibleKey.self, value: g.size.width)
            })
            .overlay(alignment: .top) {
                contenido
                    // **La hoja se dibuja a su alto natural, pase lo que pase.**
                    //
                    // `altoHoja` arranca en 0, así que en la primera pasada el
                    // contenido se mide dentro de una caja de alto cero: un
                    // párrafo que necesita dos renglones se conforma con uno y
                    // se recorta con puntos suspensivos, y el alto que se
                    // publica es el del párrafo YA recortado. El bucle converge
                    // ahí y la hoja se queda así.
                    //
                    // Se veía en la constancia anual: "This certifies that the
                    // person named above made the following voluntary co…" en
                    // el documento que se le entrega a quien aporta. Con
                    // `fixedSize` vertical el texto pide su alto de verdad y la
                    // medida sale de una hoja entera.
                    .fixedSize(horizontal: false, vertical: true)
                    // La medida del alto se toma ANTES de escalar y las escalas
                    // se aplican después: así ninguna de las dos depende de la
                    // otra y el layout converge en vez de ciclar.
                    .background(GeometryReader { g in
                        Color.clear.preference(key: AltoHojaKey.self, value: g.size.height)
                    })
                    .scaleEffect(escala, anchor: .top)
                    // `alignment: .top`, y no es un detalle: `scaleEffect` no
                    // cambia el tamaño que el contenido ocupa en el layout, así
                    // que este frame recorta una caja más baja alrededor de un
                    // bloque que sigue midiendo el alto sin escalar. Centrado
                    // —lo que hace por omisión— el dibujo se sube media hoja y
                    // la previa arranca por la mitad del documento. Con escala
                    // 1 no se nota, que es por lo que en iPad nunca se vio.
                    .frame(width: PDFExport.anchoCarta * escala,
                           height: altoHoja * escala, alignment: .top)
            }
            .onPreferenceChange(AltoHojaKey.self) { altoHoja = $0 }
            .onPreferenceChange(AnchoDisponibleKey.self) { anchoDisponible = $0 }
    }
}

/// **La barra inferior del teléfono**: una acción a la izquierda, un resumen en
/// cápsula de glass a la derecha.
///
/// **Por qué es un componente.** Estaba escrita dos veces, en `MovimientosView`
/// y en `MiembrosView`, con el mismo `HStack`, los mismos `Esp.hueco` /
/// `Esp.chip` / `Esp.pantalla` y el mismo `glassEffect`. Dos copias todavía se
/// sostienen; con Depósitos serían tres, y a partir de ahí las barras empiezan
/// a separarse una de otra sin que nadie lo decida — que es exactamente cómo
/// aparecieron los quince espaciados y los siete anchos de columna que ya
/// hicieron falta unificar.
///
/// **Va con `safeAreaInset` y no con `ToolbarItem(placement: .bottomBar)`**,
/// que sería lo natural, por una razón medida en pantalla: dentro del `TabView`
/// de iPhone la barra inferior del sistema queda DEBAJO de la barra de pestañas
/// flotante de iOS 26 y no se ve ninguna de las dos. Con `safeAreaInset` se
/// apila por encima. Esa llamada la hace cada pantalla; aquí vive la forma.
///
/// **A la izquierda va la acción, no la lupa.** La lupa la genera `.searchable`
/// y la coloca el sistema arriba; una pantalla sin buscador —Depósitos— no
/// tiene nada que poner ahí salvo su propia acción.
struct BarraInferior<Lider: View, Resumen: View>: View {
    private let lider: Lider
    private let resumen: Resumen
    /// Un resumen vacío no debe dejar una cápsula de glass flotando sola.
    private let conResumen: Bool

    init(@ViewBuilder lider: () -> Lider,
         @ViewBuilder resumen: () -> Resumen) {
        self.lider = lider()
        self.resumen = resumen()
        self.conResumen = true
    }

    var body: some View {
        HStack(spacing: Esp.hueco) {
            lider
            Spacer(minLength: Esp.hueco)
            if conResumen {
                // Cápsula de material, pero SIN estilo de botón: el resumen
                // informa y no se toca, y darle apariencia de control mentiría
                // sobre eso. El material está para que las filas se difuminen
                // por debajo al desplazarse.
                resumen
                    .padding(.horizontal, Esp.chip)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .padding(.horizontal, Esp.pantalla)
        .padding(.bottom, Esp.hueco)
    }
}

extension BarraInferior where Resumen == EmptyView {
    /// Barra con acción y sin resumen.
    init(@ViewBuilder lider: () -> Lider) {
        self.init(lider: lider, resumen: { EmptyView() }, conResumen: false)
    }
}

extension BarraInferior {
    fileprivate init(@ViewBuilder lider: () -> Lider,
                     @ViewBuilder resumen: () -> Resumen,
                     conResumen: Bool) {
        self.lider = lider()
        self.resumen = resumen()
        self.conResumen = conResumen
    }
}

extension View {
    /// El fondo de una tarjeta de plantilla (Cartas) o de reporte: el color
    /// propio de la tarjeta entrando por la esquina de arriba y disolviéndose
    /// hacia la de abajo.
    ///
    /// **El 8 % no es un número suelto: va por debajo del 15 % de la placa del
    /// icono**, y esa diferencia es la que mantiene al icono como lo más
    /// marcado de la tarjeta. Subirlo iguala los dos y el icono deja de
    /// destacar sobre su propio fondo; bajarlo de ahí desaparece en oscuro,
    /// donde cualquier tinte por debajo del 10 % se traga. Elegido por Iván
    /// sobre una escala de cinco, en claro y en oscuro.
    ///
    /// El degradado es el tono que la tarjeta YA tiene, no una decoración
    /// aparte: refuerza lo que el icono dice en vez de añadir un color nuevo
    /// que no signifique nada.
    func fondoDeTarjeta(_ tono: Color, radio: CGFloat = 28) -> some View {
        background {
            let forma = RoundedRectangle(cornerRadius: radio, style: .continuous)
            forma
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    LinearGradient(colors: [tono.opacity(0.08), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .clipShape(forma)
        }
    }
}

/// **El hundido de una tarjeta que se toca, en un estilo y no en cada vista.**
///
/// Las tarjetas grandes —las plantillas de Cartas, y las de Reportes— se hunden
/// un poco mientras las tienes apretadas. Sin eso la tarjeta no contesta al
/// dedo hasta que aparece la pantalla siguiente, y medio segundo de nada se lee
/// como que el toque no ha entrado.
///
/// Estaba resuelto a mano en la vista: un `@State` con el id de la pulsada, un
/// `onPressingChanged` para moverlo y un `.scaleEffect` leyéndolo. Tres piezas
/// para algo que un `ButtonStyle` ya sabe: `configuration.isPressed`. Al
/// pasarlo aquí, la vista deja de llevar estado que no es suyo y el hundido
/// sale igual en todas las tarjetas.
/// **`hunde: false` para quien ya tiene su propia animación.** Las tarjetas de
/// Reportes llevan `contextMenu`, que trae su vibración y su forma de levantar
/// la tarjeta; añadirles el hundido sería una segunda animación peleando con la
/// del sistema. Necesitan el `Button` —por el toque y por VoiceOver— pero no el
/// efecto, y un `.plain` no vale porque pinta su propio apagado al apretar.
struct TarjetaPulsable: ButtonStyle {
    var hunde = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(hunde && configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TarjetaPulsable {
    static var tarjeta: TarjetaPulsable { TarjetaPulsable() }
    static func tarjeta(hunde: Bool) -> TarjetaPulsable { TarjetaPulsable(hunde: hunde) }
}

/// **El aviso de lo que falta para poder guardar.**
///
/// Nace de algo que dijo Iván usando la app: *"a veces uno le quiere dar save y
/// no salva porque quedan cosas incompletas… uno tiene que estar adivinando qué
/// hace falta"*. De veinte formularios con el botón de guardar apagado, solo uno
/// decía por qué.
///
/// La forma la decidió antes esta misma app, en la configuración inicial: **no
/// se maquilla el botón apagado, se quita el motivo de apagarlo**. El botón
/// responde siempre; si falta algo, lo DICE en rojo y lleva el foco al campo.
/// Una cápsula que parece botón y no responde promete algo que no cumple.
///
/// Se pasa la lista de lo que falta, ya nombrado como el usuario lo ve en la
/// pantalla —"Importe", "Categoría"—, no el nombre de la variable.
struct AvisoFaltan: View {
    let faltan: [String]

    var body: some View {
        if !faltan.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                Text(texto)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // `Paleta.negativo`, que desde el 17-sep pasa el 4.5:1 en claro.
            .foregroundStyle(Paleta.negativo)
            .accessibilityElement(children: .combine)
        }
    }

    /// "Falta el Importe" · "Faltan Importe y Categoría" · "Faltan A, B y C".
    private var texto: String {
        if faltan.count == 1 {
            return L.t("Falta \(faltan[0])", "\(faltan[0]) is missing")
        }
        let todos = faltan.dropLast().joined(separator: ", ")
        let ultimo = faltan[faltan.count - 1]
        return L.t("Faltan \(todos) y \(ultimo)", "\(todos) and \(ultimo) are missing")
    }
}

extension View {
    /// **El aviso de lo que falta, en una línea por formulario.**
    ///
    /// Va colgado de una `safeAreaBar` para que salga siempre en el mismo sitio
    /// —pegado abajo, sobre el teclado si lo hay— independientemente de si el
    /// formulario es un `Form`, una `List` o un `ScrollView`. Con veinte
    /// pantallas que arreglar, lo que no puede pasar es que el aviso aparezca en
    /// un sitio distinto en cada una.
    ///
    /// Lleva su propio `.glassEffect`: una `safeAreaBar` no pinta nada, y esto
    /// es texto desnudo (ver la nota de los pies de columna del 16-sep). Y se
    /// colapsa a cero cuando no hay nada que decir.
    func avisoDeFaltantes(_ faltan: [String], visible: Bool) -> some View {
        safeAreaBar(edge: .bottom, spacing: 0) {
            if visible && !faltan.isEmpty {
                AvisoFaltan(faltan: faltan)
                    .padding(.horizontal, Esp.pantalla)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, Esp.chip)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

/// **Los puntos de página de un carrusel, con el `UIPageControl` de UIKit.**
///
/// SwiftUI no tiene un control de página suelto: `TabView(.page)` trae el suyo,
/// pero exige que el carrusel SEA un `TabView`, y el de Cartas es un
/// `ScrollView` horizontal con `scrollTargetBehavior`, que es lo que le da el
/// encaje y el asomo de la vecina.
///
/// A mano tampoco sale: dieciséis círculos de 7 pt con su área tocable de 28 no
/// caben en un teléfono, y esa es la razón por la que Cartas enseñaba un
/// "1 / 16" en su lugar. `UIPageControl` resuelve las dos cosas de fábrica:
///
/// - **Con muchas páginas encoge los puntos de los extremos** en vez de
///   desbordarse, que es exactamente lo que hace la galería de widgets de iOS.
/// - **Es `adjustable` para VoiceOver** —dice "página 1 de 16" y se cambia
///   deslizando arriba y abajo—, que es el atajo que se perdió al quitar las
///   flechas del carrusel.
///
/// `hidesForSinglePage` va encendido: con una sola plantilla el control no dice
/// nada que la pantalla no diga ya.
struct PuntosDePagina: UIViewRepresentable {
    let total: Int
    @Binding var actual: Int
    var tinte: Color = Paleta.brand

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.hidesForSinglePage = true
        control.addTarget(context.coordinator,
                          action: #selector(Coordinador.cambio(_:)),
                          for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.alCambiar = { actual = $0 }
        control.numberOfPages = total
        // Solo si cambió: escribirlo en cada pasada corta la animación del
        // propio control mientras el dedo arrastra.
        if control.currentPage != actual { control.currentPage = actual }
        control.currentPageIndicatorTintColor = UIColor(tinte)
        control.pageIndicatorTintColor = UIColor(Color(.tertiaryLabel))
    }

    func makeCoordinator() -> Coordinador { Coordinador() }

    final class Coordinador {
        var alCambiar: (Int) -> Void = { _ in }
        @objc func cambio(_ control: UIPageControl) { alCambiar(control.currentPage) }
    }
}
