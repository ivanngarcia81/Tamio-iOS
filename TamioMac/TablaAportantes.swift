import SwiftUI

/// **Aportantes.** Las cinco columnas de la maqueta: Nombre, Miembro desde,
/// Frecuencia, Último aporte y Acumulado del año.
struct TablaAportantes: View {
    let vm: MiembrosViewModel
    @Binding var seleccion: Set<Aportante.ID>
    @State private var orden = [KeyPathComparator(\Aportante.nombre, order: .forward)]

    private var filas: [Aportante] { vm.itemsFiltrados.sorted(using: orden) }
    private var anio: Int { vm.anio }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Nombre", "Name"), value: \.nombre) { a in
                HStack(spacing: 8) {
                    Text(a.nombre).fontWeight(.semibold).lineLimit(1)
                    // **Quién lleva tiempo sin aportar, marcado en la fila.**
                    // Es la pregunta que trae a alguien a esta pantalla, y
                    // enterrarla en una columna aparte la esconde.
                    if a.atrasadoEnAportes {
                        Text(L.t("Atrasado", "Behind"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Paleta.aviso)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Paleta.aviso.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
            .width(min: 160, ideal: 260)

            TableColumn(L.t("Miembro desde", "Member since"), value: \.congregaDesde) { a in
                Text(a.congregaDesde.isEmpty ? "—" : a.congregaDesde)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 120, max: 170)

            TableColumn(L.t("Frecuencia", "Frequency"), value: \.frecuencia.rawValue) { a in
                Text(a.frecuencia.etiqueta).foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 124, max: 170)

            TableColumn(L.t("Último aporte", "Last gift"), value: \.ordenUltimoAporte) { a in
                Text(a.ultimoAporte.map {
                    $0.formatted(.dateTime.day().month(.abbreviated))
                } ?? "—")
                .foregroundStyle(a.ultimoAporte == nil ? .tertiary : .secondary)
            }
            .width(min: 100, ideal: 120, max: 170)

            TableColumn(L.t("Acumulado", "Year to date"), value: \.nombre) { a in
                let t = a.total(anio: anio)
                Text(t == 0 ? "—" : Money.fmt(t))
                    .monospacedDigit()
                    .fontWeight(t == 0 ? .regular : .semibold)
                    .foregroundStyle(t == 0 ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 110, ideal: 140, max: 190)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

extension Aportante {
    /// Para ordenar por "último aporte" sin perder a quien no tiene ninguno.
    /// **Los que nunca aportaron van al final**, no al principio: `Date?` nulo
    /// ordenado como fecha cero los pondría arriba, que es justo al revés de
    /// lo que se busca al ordenar por esta columna.
    var ordenUltimoAporte: Date { ultimoAporte ?? .distantPast }
}
