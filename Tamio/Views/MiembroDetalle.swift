import SwiftUI
import Charts

/// Ficha de un miembro: los 8 indicadores del padrón, cabecera con avatar y
/// acciones, asistencia del periodo (gráfica), datos, expediente e historial.
struct MiembroDetalle: View {
    let miembro: Miembro
    let resumen: MembresiaResumen?
    let onEditar: () -> Void
    let onSeguimiento: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let r = resumen { indicadores(r) }
                cabecera
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { columnaIzquierda; columnaDerecha.frame(width: 320) }
                    VStack(spacing: 16) { columnaIzquierda; columnaDerecha }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 8 indicadores del padrón

    private func indicadores(_ r: MembresiaResumen) -> some View {
        let kpis: [(String, Int, Color)] = [
            (L.t("Total", "Total"), r.total, Paleta.brand),
            (L.t("Activos", "Active"), r.activos, Paleta.brand),
            (L.t("Inactivos", "Inactive"), r.inactivos, Paleta.aviso),
            (L.t("Nuevos", "New"), r.nuevos, Color(hex: 0x7C3AED)),
            (L.t("Recibidos", "Received"), r.recibidos, Color(hex: 0x06B6D4)),
            (L.t("Trasladados", "Transferred"), r.trasladados, Paleta.aviso),
            (L.t("Ausencias", "Absences"), r.ausencias, Paleta.negativo),
            (L.t("Incompletos", "Incomplete"), r.incompletos, Color(hex: 0x7C3AED)),
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
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 3).padding(.horizontal, 10)
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
            Button { onSeguimiento() } label: { Text(L.t("Seguimiento", "Follow-up")) }.buttonStyle(.bordered)
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
                            .foregroundStyle(m.mes == miembro.asistencia.last?.mes ? Paleta.brand : Paleta.brand.opacity(0.25))
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
