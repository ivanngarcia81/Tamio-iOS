import SwiftUI

/// **El panel de la derecha.**
///
/// La maqueta tiene una regla sobre él que conviene no perder: *los botones
/// solo salen cuando hay algo sobre lo que actuar*. Un "Aprobar" verde en una
/// pantalla sin nada seleccionado promete una acción que no existe.
struct InspectorTamio: View {
    let seccion: SeccionMac
    let seleccion: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(antetitulo)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.55)
                    .foregroundStyle(.secondary)
                Text(titulo)
                    .font(.system(size: 19, weight: .bold))
                    .padding(.top, 5)
                Text(subtitulo)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .inspectorColumnWidth(min: 260, ideal: 312, max: 420)
    }

    private var antetitulo: String {
        switch seccion {
        case .porRevisar: return L.t("BANDEJA", "TRAY")
        case .reportes:   return L.t("REPORTE", "REPORT")
        case .actas:      return L.t("ACTAS", "MINUTES")
        case .agenda:     return L.t("AGENDA", "CALENDAR")
        case .config:     return L.t("CONFIGURACIÓN", "SETTINGS")
        default:          return seccion.titulo.uppercased()
        }
    }

    private var titulo: String {
        seleccion == nil
            ? L.t("Nada seleccionado", "Nothing selected")
            : L.t("Detalle", "Detail")
    }

    private var subtitulo: String {
        seccion == .config
            ? L.t("La configuración se edita en el panel de la izquierda",
                  "Settings are edited in the panel on the left")
            : L.t("Elige una fila para ver su ficha aquí",
                  "Pick a row to see its details here")
    }
}
