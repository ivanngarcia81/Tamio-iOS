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
            .padding(16)
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

    var body: some View {
        contenido
            // La medida se toma ANTES de escalar y las escalas se aplican
            // después: así ninguna de las dos depende de la otra y el layout
            // converge en vez de ciclar.
            .background(GeometryReader { g in
                Color.clear.preference(key: AltoHojaKey.self, value: g.size.height)
            })
            .scaleEffect(escala, anchor: .top)
            .frame(width: PDFExport.anchoCarta * escala, height: altoHoja * escala)
            .frame(maxWidth: .infinity)
            .background(GeometryReader { g in
                Color.clear.preference(key: AnchoDisponibleKey.self, value: g.size.width)
            })
            .onPreferenceChange(AltoHojaKey.self) { altoHoja = $0 }
            .onPreferenceChange(AnchoDisponibleKey.self) { anchoDisponible = $0 }
    }
}
