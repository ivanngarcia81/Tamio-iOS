import SwiftUI

/// **La tabla de Ingresos y Gastos.**
///
/// Es un `Table` de verdad y no una lista de filas dibujadas a mano: en el Mac
/// se espera poder ordenar por una columna pulsando su cabecera, arrastrar el
/// borde para ensancharla y recorrer la selección con las flechas. Todo eso
/// sale gratis con `Table` y habría que escribirlo entero con una `List`.
struct TablaMovimientos: View {
    let vm: MovimientosViewModel
    @Binding var seleccion: Set<Movimiento.ID>

    /// **Por fecha y de la más reciente hacia abajo**, que es como se mira un
    /// libro: lo último que se capturó es lo que se está comprobando.
    @State private var orden = [KeyPathComparator(\Movimiento.fecha, order: .reverse)]

    private var filas: [Movimiento] { vm.itemsFiltrados.sorted(using: orden) }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Fecha", "Date"), value: \.fecha) { m in
                Text(m.fecha.formatted(.dateTime.day().month(.abbreviated)))
                    .foregroundStyle(.secondary)
            }
            .width(min: 76, ideal: 96, max: 140)

            TableColumn(L.t("Folio", "Folio"), value: \.folio) { m in
                Text(m.folio)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 64, ideal: 84, max: 120)

            TableColumn(L.t("Concepto", "Concept"), value: \.categoria) { m in
                HStack(spacing: 8) {
                    // El punto de color de la categoría, igual que en la app de
                    // iOS: es lo que deja leer la columna de un vistazo sin
                    // llegar a leer la palabra.
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Paleta.categoria(m.claveCategoria, nombre: m.categoria))
                        .frame(width: 8, height: 8)
                    Text(m.categoria).fontWeight(.semibold)
                    if !quien(m).isEmpty {
                        Text("· \(quien(m))")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 180, ideal: 320)

            TableColumn(L.t("Método", "Method"), value: \.metodo) { m in
                Text(m.metodo).foregroundStyle(.secondary)
            }
            .width(min: 88, ideal: 110, max: 160)

            TableColumn(L.t("Estado", "Status"), value: \.ordenDeEstado) { m in
                let e = EstadoFila(m)
                Text(e.texto)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(e.tinta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(e.tinta.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 104, ideal: 128, max: 180)

            TableColumn(L.t("Importe", "Amount"), value: \.monto) { m in
                // A la derecha y con cifras de ancho fijo: una columna de
                // dinero que no alinea las unidades no se puede recorrer con
                // la vista, que es justo para lo que se mira.
                Text(Money.firmado(m.monto, ingreso: m.esIngreso))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(Money.color(ingreso: m.esIngreso))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 100, ideal: 130, max: 180)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    /// Quién está al otro lado: el aportante en un ingreso, el beneficiario en
    /// un gasto. La misma columna no significa lo mismo en las dos pantallas.
    private func quien(_ m: Movimiento) -> String {
        (m.esIngreso ? m.persona : m.pagadoA)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}

// MARK: - El estado de una fila

/// **Las tres situaciones que la maqueta pinta como píldora**, resueltas desde
/// lo que el modelo ya sabe. No hay campo "estado" en `Movimiento`: se deduce
/// de si espera visto bueno y de si algún corte depositado lo reclama.
struct EstadoFila {
    let texto: String
    let tinta: Color

    init(_ m: Movimiento) {
        if m.marcadoPendiente {
            texto = L.t("En revisión", "In review")
            tinta = Paleta.aviso
        } else if m.esIngreso && m.sinDepositar {
            texto = L.t("Sin depositar", "Not deposited")
            tinta = Paleta.aviso
        } else if m.esIngreso {
            texto = L.t("Depositado", "Deposited")
            tinta = Paleta.brand
        } else {
            texto = L.t("Asentado", "Posted")
            tinta = Paleta.brand
        }
    }
}

extension Movimiento {
    /// Para poder ORDENAR por la columna de estado.
    ///
    /// `Table` exige un `KeyPath` a algo comparable, y el estado es una píldora
    /// que se calcula. Vive en una extensión DENTRO del target de Mac a
    /// propósito: es una necesidad de esta tabla y no del modelo, y el iPhone
    /// no tiene por qué cargar con ella.
    ///
    /// El orden es el de urgencia, no el alfabético: primero lo que espera una
    /// decisión, luego lo que espera el banco, al final lo cerrado.
    var ordenDeEstado: Int {
        if marcadoPendiente { return 0 }
        if esIngreso && sinDepositar { return 1 }
        return 2
    }
}
