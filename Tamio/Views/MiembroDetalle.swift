import SwiftUI
import Charts

/// Ficha de un miembro: los 8 indicadores del padrón, cabecera con avatar y
/// acciones, asistencia del periodo (gráfica), datos, expediente e historial.
struct MiembroDetalle: View {
    let miembro: Miembro
    let resumen: MembresiaResumen?
    let onEditar: () -> Void
    let onSeguimiento: () -> Void
    /// Filtra la lista de miembros por el indicador tocado. Solo se cablea en
    /// compacto; en iPad la rejilla sigue siendo texto, como hasta ahora.
    var onFiltrarAccion: ((FiltroAccion) -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let r = resumen {
                    // En iPhone las cuatro columnas fijas daban celdas de unos
                    // 80 pt: ocho tarjetas en dos filas de mosaico, casi un
                    // tercio de la pantalla antes de ver un dato del miembro.
                    if sizeClass == .compact { resumenCompacto(r) } else { indicadores(r) }
                }
                cabecera
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { columnaIzquierda; columnaDerecha.frame(width: 320) }
                    VStack(spacing: 16) { columnaIzquierda; columnaDerecha }
                }
            }
            .padding(24)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Resumen del padrón en compacto

    /// Los mismos ocho números en una tarjeta de tres filas, agrupados por lo
    /// que significan: estado del padrón, movimiento del periodo y lo que
    /// requiere acción. En la rejilla los ocho pesaban igual, cuando Total es
    /// el dato de cabecera e Incompletos una tarea pendiente.
    ///
    /// Los acentos de color de `miniKPI` se pierden aquí a propósito: ocho
    /// colores sin leyenda no comunicaban nada, y en la versión agrupada la
    /// jerarquía la da la posición.
    private func resumenCompacto(_ r: MembresiaResumen) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: Esp.hueco) {
                Text("\(r.total)")
                    .font(.largeTitle.weight(.bold)).monospacedDigit()
                Text(L.t("en el padrón", "on the roster"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(L.t("\(r.activos) activos · \(r.inactivos) inactivos",
                         "\(r.activos) active · \(r.inactivos) inactive"))
                    .font(.footnote).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }

            Divider()

            HStack(spacing: 0) {
                dato(L.t("Nuevos", "New"), r.nuevos)
                dato(L.t("Recibidos", "Received"), r.recibidos)
                dato(L.t("Trasladados", "Transferred"), r.trasladados)
            }

            Divider()

            HStack(spacing: 10) {
                accion(L.t("Ausencias", "Absences"), r.ausencias, .ausencias)
                accion(L.t("Incompletos", "Incomplete"), r.incompletos, .incompletos)
            }
        }
        .padding(Esp.tarjeta)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dato(_ titulo: String, _ valor: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.85)
            Text("\(valor)").font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Fila 3: los dos que requieren acción. Con `onFiltrarAccion` a nil se
    /// dibujan sin chevron y sin tap, que es mejor que un botón que no lleva a
    /// ningún lado.
    @ViewBuilder
    private func accion(_ titulo: String, _ valor: Int, _ filtro: FiltroAccion) -> some View {
        if let onFiltrarAccion {
            // `.buttonStyle(.plain)` es obligatorio: sin él el tint verde del
            // TabView pisa el `foregroundStyle` del label.
            Button { onFiltrarAccion(filtro) } label: {
                etiquetaAccion(titulo, valor, conChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            etiquetaAccion(titulo, valor, conChevron: false)
        }
    }

    private func etiquetaAccion(_ titulo: String, _ valor: Int, conChevron: Bool) -> some View {
        HStack(spacing: 6) {
            Text(titulo).font(.subheadline).lineLimit(1).minimumScaleFactor(0.85)
            Text("\(valor)").font(.subheadline.weight(.bold)).monospacedDigit()
            Spacer(minLength: 2)
            if conChevron {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, Esp.chip).padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Paleta.avisoFill, in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
    }

    // MARK: - 8 indicadores del padrón (iPad)

    private func indicadores(_ r: MembresiaResumen) -> some View {
        let kpis: [(String, Int, Color)] = [
            (L.t("Total", "Total"), r.total, Paleta.brand),
            (L.t("Activos", "Active"), r.activos, Paleta.brand),
            (L.t("Inactivos", "Inactive"), r.inactivos, Paleta.aviso),
            (L.t("Nuevos", "New"), r.nuevos, Paleta.morado),
            (L.t("Recibidos", "Received"), r.recibidos, Paleta.cian),
            (L.t("Trasladados", "Transferred"), r.trasladados, Paleta.aviso),
            (L.t("Ausencias", "Absences"), r.ausencias, Paleta.negativo),
            (L.t("Incompletos", "Incomplete"), r.incompletos, Paleta.morado),
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(kpis, id: \.0) { k in miniKPI(k.0, k.1, k.2) }
        }
    }

    private func miniKPI(_ titulo: String, _ valor: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text("\(valor)").font(.title2.weight(.bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.chip)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 3).padding(.horizontal, Esp.hueco)
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.separator.opacity(0.6), lineWidth: 0.5))
    }

    // MARK: - Cabecera de la ficha

    private var cabecera: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarMiembro
            VStack(alignment: .leading, spacing: 8) {
                Text(miembro.nombre)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    Pill(texto: L.t("Miembro activo", "Active member"), color: miembro.estado.color)
                    Text(miembro.miembroDesde).font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(miembro.area).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                botonesMiembro
            }
        }
    }

    private var avatarMiembro: some View {
        Text(miembro.iniciales)
            .font(.title3.weight(.bold)).foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(miembro.estado.color, in: Circle())
    }

    private var botonesMiembro: some View {
        HStack(spacing: 10) {
            Button { onSeguimiento() } label: { Text(L.t("Seguimiento", "Follow-up")) }.buttonStyle(.bordered).tint(Color.secondary)
            Button { onEditar() } label: { Label(L.t("Editar", "Edit"), systemImage: "pencil").fontWeight(.semibold) }
                .buttonStyle(.borderedProminent).tint(Paleta.brand)
        }
    }

    // MARK: - Columna izquierda (asistencia + datos)

    private var columnaIzquierda: some View {
        VStack(alignment: .leading, spacing: 16) {
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TituloSeccion(texto: L.t("ASISTENCIA DEL PERIODO", "ATTENDANCE"))
                        Spacer()
                        Text("\(miembro.asistenciaPct)%").font(.title3.weight(.bold)).monospacedDigit()
                    }
                    Chart(miembro.asistencia) { m in
                        BarMark(x: .value("Mes", m.mes), y: .value("Asistencia", m.valor))
                            .foregroundStyle(m.mes == miembro.asistencia.last?.mes ? Paleta.brand : Paleta.brandMuted)
                            .cornerRadius(3)
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 90)
                    HStack(spacing: 20) {
                        stat(L.t("En roster", "In roster"), miembro.enRoster)
                        stat(L.t("Racha sin asistir", "Missed streak"), miembro.rachaSinAsistir)
                        stat(L.t("Última visita", "Last visit"), miembro.ultimaVisita)
                    }
                }
            }
            Tarjeta {
                VStack(spacing: 0) {
                    ForEach(Array(miembro.datos.enumerated()), id: \.element.id) { i, d in
                        HStack {
                            Text(d.etiqueta).font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(d.valor).font(.subheadline.weight(.medium))
                        }
                        .padding(.vertical, 10)
                        if i < miembro.datos.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func stat(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption2).foregroundStyle(.secondary)
            Text(valor).font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Columna derecha (expediente + historial)

    private var columnaDerecha: some View {
        VStack(alignment: .leading, spacing: 16) {
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TituloSeccion(texto: L.t("EXPEDIENTE", "RECORD"))
                        Spacer()
                        Text(L.t("Completo", "Complete")).font(.caption.weight(.semibold)).foregroundStyle(Paleta.brand)
                    }
                    ForEach(miembro.expediente) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.completo ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.completo ? Paleta.brand : .secondary)
                            Text(item.campo).font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    TituloSeccion(texto: L.t("MOVIMIENTOS DE MEMBRESÍA", "MEMBERSHIP HISTORY"))
                    ForEach(Array(miembro.movimientos.enumerated()), id: \.element.id) { i, m in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(i == 0 ? Paleta.brand : Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.titulo).font(.subheadline.weight(.medium))
                                Text(m.fecha).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
