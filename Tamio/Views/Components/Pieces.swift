import SwiftUI

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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icono)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
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
                Text("\(badge)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
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
