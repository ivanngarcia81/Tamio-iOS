import SwiftUI

/// Fila de "Últimos movimientos": inicial de la categoría en un círculo con
/// tinte, titular ("Diezmo · María Hernández"), subtítulo ("Folio 1042 ·
/// Efectivo"), y el monto con signo y color. El monto es una de las cifras que
/// la ley de color permite colorear.
struct TransactionRow: View {
    let tx: Tx
    private var esIngreso: Bool { tx.tipo == .ingreso }
    private var color: Color { esIngreso ? Paleta.brand : Paleta.negativo }

    var body: some View {
        HStack(spacing: 12) {
            Text(tx.inicial)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.titular).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(tx.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 8)

            Text((esIngreso ? "+" : "−") + Money.fmt(tx.monto))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.vertical, 8)
    }
}

/// Fila de "Esta semana": bloque de fecha (día de semana + número), título,
/// subtítulo, y un punto de color por familia de actividad.
struct AgendaRow: View {
    let item: AgendaItem

    /// **El bloque de fecha crece con la letra.** Eran 36 pt fijos, y en AX1
    /// no cabía ni el día ni el número: "SUN" salía "SU / N" y un 21 se partía
    /// en "2 / 1". Una fecha en dos renglones no es una fila apretada, es una
    /// fecha que se lee mal. `ScaledMetric` da el mismo ancho en tamaño normal
    /// —el diseño no se mueve— y a partir de ahí lo escala como al texto.
    /// Relativo a `.caption2`, que es el rótulo más ancho de los dos y el que
    /// más crece: los estilos pequeños escalan más que los grandes.
    @ScaledMetric(relativeTo: .caption2) private var anchoFecha: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(item.dia)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.num)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(width: anchoFecha)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.titulo).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(item.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 8)

            Circle()
                .fill(Paleta.agenda[min(item.familia, Paleta.agenda.count - 1)])
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 8)
    }
}
