import SwiftUI

/// **El Registro de servicios, rediseñado para el Mac.**
///
/// En el iPad es una lista de tarjetas con la pastilla del día a la izquierda.
/// Aquí es una tabla, por lo mismo que el Registro: un año de cultos son
/// cincuenta y pico filas con las mismas casillas, y lo que se quiere saber
/// —quién predicó más, qué domingos bajó la asistencia, qué servicios se
/// quedaron sin equipo— son preguntas de columna, no de tarjeta.
struct TablaServicios: View {
    let vm: ServiciosViewModel
    @Binding var seleccion: Set<Servicio.ID>

    /// El culto más reciente arriba. **La fecha es "AAAA-MM-DD"**, así que
    /// ordenarla como texto la ordena bien de verdad: es el único formato de
    /// fecha en texto donde el orden alfabético y el cronológico coinciden.
    @State private var orden = [KeyPathComparator(\Servicio.fecha, order: .reverse)]

    private var filas: [Servicio] { vm.lista.sorted(using: orden) }

    var body: some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Fecha", "Date"), value: \.fecha) { s in
                HStack(spacing: 8) {
                    Text(s.diaSemana)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(s.fechaLegible)
                }
            }
            .width(min: 130, ideal: 165, max: 230)

            TableColumn(L.t("Culto", "Service"), value: \.titulo) { s in
                Text(s.titulo).fontWeight(.semibold).lineLimit(1)
            }
            .width(min: 110, ideal: 150, max: 220)

            TableColumn(L.t("Predica", "Preacher"), value: \.predica) { s in
                Text(s.predica.isEmpty ? "—" : s.predica)
                    .foregroundStyle(s.predica.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
            }
            .width(min: 110, ideal: 160, max: 240)

            TableColumn(L.t("Mensaje", "Message"), value: \.tituloMensaje) { s in
                Text(s.tituloMensaje.isEmpty ? "—" : s.tituloMensaje)
                    .foregroundStyle(s.tituloMensaje.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
            }
            .width(min: 140, ideal: 300)

            TableColumn(L.t("Asistencia", "Attendance"), value: \.totalAsistencia) { s in
                // **Un cero no es lo mismo que "no se contó".** Un culto al que
                // no vino nadie no existe; lo que existe es un culto cuya
                // asistencia nadie apuntó, y escribir "0" ahí sería inventarse
                // un dato en la pantalla que sirve para llevar la cuenta.
                Text(s.totalAsistencia == 0 ? "—" : "\(s.totalAsistencia)")
                    .monospacedDigit()
                    .fontWeight(s.totalAsistencia == 0 ? .regular : .semibold)
                    .foregroundStyle(s.totalAsistencia == 0 ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 110, max: 150)

            TableColumn(L.t("Equipo", "Team"), value: \.ordenDeRoster) { s in
                let e = s.estadoRoster
                Text(e.etiqueta)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(e.estadoVisual.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(e.estadoVisual.color.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 116, ideal: 140, max: 190)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

extension Servicio {
    /// Lo que se contó en total. Se suma al leer: el modelo guarda los tres
    /// grupos por separado porque es como se cuenta en la puerta.
    var totalAsistencia: Int { ninos + jovenes + adultos }

    /// Para ordenar por la columna de equipo, y **por urgencia**: primero los
    /// que no tienen a nadie asignado, que son los que hay que resolver antes
    /// del domingo. Alfabéticamente saldría "Roster completo" el primero, que
    /// es justo lo que no hace falta mirar.
    var ordenDeRoster: Int {
        switch estadoRoster {
        case .sinAsignar: return 0
        case .parcial:    return 1
        case .completo:   return 2
        }
    }
}
