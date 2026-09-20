import SwiftUI

/// **Membresía.** Las cinco columnas de la maqueta: Nombre, Estado,
/// Ministerio, Asistencia e Ingreso.
struct TablaMembresia: View {
    let vm: MembresiaViewModel
    @Binding var seleccion: Set<Miembro.ID>
    @State private var orden = [KeyPathComparator(\Miembro.nombre, order: .forward)]

    private var filas: [Miembro] { vm.itemsFiltrados.sorted(using: orden) }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Nombre", "Name"), value: \.nombre) { m in
                Text(m.nombre).fontWeight(.semibold).lineLimit(1)
            }
            .width(min: 160, ideal: 250)

            TableColumn(L.t("Estado", "Status"), value: \.estado.etiqueta) { m in
                Text(m.estado.etiqueta)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(m.estado.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(m.estado.color.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 110, ideal: 140, max: 200)

            TableColumn(L.t("Ministerio", "Ministry"), value: \.ministerioLegible) { m in
                Text(m.ministerioLegible)
                    .foregroundStyle(m.ministerios.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 190)

            TableColumn(L.t("Asistencia", "Attendance"), value: \.asistenciaPct) { m in
                // **Sin datos no es 0 %.** Quien no tiene listas tomadas no ha
                // faltado: es que nadie apuntó. Pintarlo en rojo al 0 % le
                // colgaría un juicio a partir de un dato que no existe.
                if m.asistenciaResumen == nil {
                    Text("—")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("\(m.asistenciaPct)%")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                        .foregroundStyle(m.tintaDeAsistencia)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .width(min: 100, ideal: 120, max: 160)

            TableColumn(L.t("Ingreso", "Joined"), value: \.fechaIngreso) { m in
                Text(m.fechaIngreso.isEmpty ? "—" : Fechas.diaLegible(m.fechaIngreso))
                    .foregroundStyle(.secondary)
            }
            .width(min: 110, ideal: 140, max: 190)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

extension Miembro {
    /// Los ministerios en palabras. Una persona puede servir en varios.
    var ministerioLegible: String {
        ministerios.isEmpty ? "—" : Padron.etiquetas(ministerios)
    }

    /// Los mismos tres tramos que la maqueta: verde desde 85, ámbar desde 65,
    /// rojo por debajo.
    var tintaDeAsistencia: Color {
        if asistenciaPct >= 85 { return Paleta.brand }
        if asistenciaPct >= 65 { return Paleta.aviso }
        return Paleta.negativo
    }
}
