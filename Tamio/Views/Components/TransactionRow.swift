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

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(item.dia)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.num)
                    .font(.headline)
                    .monospacedDigit()
            }
            .frame(width: 36)

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
