import SwiftUI

/// **El panel de la derecha.**
///
/// La maqueta tiene una regla sobre él que conviene no perder: *los campos y
/// el historial solo salen cuando hay algo que enseñar*. Una ficha con los
/// rótulos puestos y los valores en blanco parece que no cargó.
struct InspectorTamio: View {
    let seccion: SeccionMac
    let movimiento: Movimiento?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let m = movimiento {
                    ficha(m)
                } else {
                    vacio
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .inspectorColumnWidth(min: 260, ideal: 312, max: 420)
    }

    // MARK: - Con algo seleccionado

    @ViewBuilder
    private func ficha(_ m: Movimiento) -> some View {
        Text(m.esIngreso ? L.t("INGRESO", "INCOME") : L.t("GASTO", "EXPENSE"))
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)

        Text(Money.firmado(m.monto, ingreso: m.esIngreso))
            .font(.system(size: 22, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Money.color(ingreso: m.esIngreso))
            .padding(.top, 4)

        Text("\(m.categoria) · \(L.t("folio", "folio")) \(m.folio)")
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)

        // Los campos, en el mismo orden que la maqueta.
        VStack(spacing: 0) {
            campo(L.t("Fecha", "Date"),
                  m.fecha.formatted(.dateTime.day().month(.abbreviated).year()))
            campo(L.t("Hora", "Time"), m.hora)
            campo(L.t("Método", "Method"), m.metodo)
            campo(m.esIngreso ? L.t("Aportante", "Contributor")
                              : L.t("Beneficiario", "Payee"),
                  (m.esIngreso ? m.persona : m.pagadoA) ?? "—")
            campo(L.t("Estado", "Status"), EstadoFila(m).texto, tinta: EstadoFila(m).tinta)
            campo(L.t("Registrado por", "Recorded by"), m.registradoPor, ultimo: true)
        }
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 14)

        if let nota = m.nota, !nota.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(L.t("NOTA", "NOTE"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
            Text(nota)
                .font(.system(size: 12.5))
                .padding(.top, 6)
        }

        // **El rastro de auditoría, tal cual lo trae el movimiento.** Es lo que
        // permite decir quién tocó qué; no se resume ni se recorta.
        if !m.auditoria.isEmpty {
            Text(L.t("HISTORIAL", "HISTORY"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.55)
                .foregroundStyle(.secondary)
                .padding(.top, 18)

            ForEach(m.auditoria) { e in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Paleta.brand)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.titulo).font(.system(size: 12, weight: .medium))
                        Text(e.detalle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
            }
        }

        // **Sin botones todavía, y a propósito.** La maqueta pone aquí
        // "Aprobar" y "Exportar recibo (PDF)". Aprobar mueve el estado de
        // revisión de un movimiento y exportar necesita `ReportePDF`, que vive
        // en `Views` y no entra en este target. Un botón verde que no hace
        // nada, en la ficha de un apunte de dinero, promete una acción que no
        // existe.
    }

    private func campo(_ rotulo: String, _ valor: String,
                       tinta: Color? = nil, ultimo: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(rotulo)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 104, alignment: .leading)
                Text(valor)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tinta ?? .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            if !ultimo { Divider().padding(.leading, 13) }
        }
    }

    // MARK: - Sin nada seleccionado

    @ViewBuilder
    private var vacio: some View {
        Text(antetitulo)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.55)
            .foregroundStyle(.secondary)
        Text(L.t("Nada seleccionado", "Nothing selected"))
            .font(.system(size: 19, weight: .bold))
            .padding(.top, 5)
        Text(subtituloVacio)
            .font(.system(size: 12.5))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    private var antetitulo: String {
        switch seccion {
        case .porRevisar: return L.t("BANDEJA", "TRAY")
        case .reportes:   return L.t("REPORTE", "REPORT")
        case .config:     return L.t("CONFIGURACIÓN", "SETTINGS")
        default:          return seccion.titulo.uppercased()
        }
    }

    private var subtituloVacio: String {
        switch seccion {
        case .config:
            return L.t("La configuración se edita en el panel de la izquierda",
                       "Settings are edited in the panel on the left")
        case .ingresos, .gastos:
            return L.t("Elige una fila para ver su ficha aquí",
                       "Pick a row to see its details here")
        default:
            return L.t("Esta pantalla todavía no alimenta el inspector",
                       "This screen does not feed the inspector yet")
        }
    }
}
