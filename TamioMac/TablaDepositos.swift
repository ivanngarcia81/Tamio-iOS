import SwiftUI

/// **Depósitos.** Las seis columnas de la maqueta: Fecha, Cuenta, Folios,
/// Movimientos, Estado e Importe.
///
/// Lo que la maqueta llama "deposits" son los CORTES: el acto de juntar los
/// movimientos de un periodo, sacarlos de la caja y llevarlos al banco.
struct TablaDepositos: View {
    let vm: DepositosViewModel
    @Binding var seleccion: Set<Corte.ID>
    @State private var orden = [KeyPathComparator(\Corte.registro.fecha, order: .reverse)]

    private var filas: [Corte] { vm.items.sorted(using: orden) }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Fecha", "Date"), value: \.registro.fecha) { c in
                Text(c.registro.fecha.isEmpty ? "—" : Fechas.diaLegible(c.registro.fecha))
                    .foregroundStyle(.secondary)
            }
            .width(min: 110, ideal: 140, max: 190)

            TableColumn(L.t("Cuenta", "Bank account"), value: \.registro.cuenta) { c in
                Text(c.registro.cuenta.isEmpty ? "—" : c.registro.cuenta)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .width(min: 130, ideal: 220)

            TableColumn(L.t("Folios", "Folios"), value: \.rangoDeFolios) { c in
                Text(c.rangoDeFolios)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 110, ideal: 140, max: 200)

            TableColumn(L.t("Movimientos", "Items"), value: \.cuantosMovimientos) { c in
                Text("\(c.cuantosMovimientos)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 108, max: 150)

            TableColumn(L.t("Estado", "Status"), value: \.ordenDeEstado) { c in
                let (texto, tinta) = c.pastilla
                Text(texto)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tinta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tinta.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 110, ideal: 136, max: 190)

            TableColumn(L.t("Importe", "Amount"), value: \.suma) { c in
                Text(Money.fmt(c.suma))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 110, ideal: 140, max: 190)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

extension Corte {
    var cuantosMovimientos: Int { movimientos.count }
    var suma: Centavos { movimientos.reduce(0) { $0 + $1.monto } }

    /// "1042–1051". **Del primero al último de verdad**, no del orden en que
    /// vengan: un corte se cuadra contra el talonario, y para eso hacen falta
    /// los dos extremos.
    var rangoDeFolios: String {
        let folios = movimientos.map(\.folio).filter { !$0.isEmpty }.sorted()
        guard let primero = folios.first, let ultimo = folios.last else { return "—" }
        return primero == ultimo ? primero : "\(primero)–\(ultimo)"
    }

    /// Primero lo que sigue en la caja: es lo que hay que llevar al banco.
    var ordenDeEstado: Int { estado == .pendiente ? 0 : 1 }

    var pastilla: (String, Color) {
        // **"Por revisar" gana a "Depositado".** Un corte con movimientos
        // señalados no está cerrado aunque el dinero ya esté en el banco, y
        // enseñarlo en verde diría que no queda nada que hacer.
        if porRevisar > 0 {
            return (L.t("\(porRevisar) por revisar", "\(porRevisar) to review"), Paleta.aviso)
        }
        return estado == .pendiente
            ? (L.t("En caja", "In the cash box"), Paleta.aviso)
            : (L.t("Depositado", "Deposited"), Paleta.brand)
    }
}
