import SwiftUI
import Charts

/// **Informes de membresía, según el handoff definitivo.**
///
/// La primera versión de esta pantalla se hizo SIN diseño —el handoff anterior
/// no la dibujaba—, así que se le aplicó el patrón de Reportes: una hoja de
/// papel a la derecha. El handoff nuevo la especifica y es otra cosa: cuatro
/// pestañas, selector de periodo, barras y tarjetas que filtran.
///
/// Encaja con `InformesMembresiaViewModel` sin forzar nada, porque el
/// ViewModel estaba escrito para exactamente esto: `TarjetaPadron` son las
/// ocho tarjetas, `resumen` trae los repartos y los traslados, y `alertas` ya
/// viene con su tipo.
struct PantallaInformes: View {
    let vm: InformesMembresiaViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cabecera
                switch vm.informeSeleccionado {
                case 1:  pestanaMiembros
                case 2:  pestanaAsistencia
                case 3:  pestanaSeguimiento
                default: pestanaGeneral
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background(Color.suelo)
        .task { await vm.cargarPadron() }
    }

    // MARK: - Pestañas y periodo

    private var cabecera: some View {
        HStack(spacing: 12) {
            Picker("", selection: Binding(
                get: { vm.informeSeleccionado },
                set: { vm.informeSeleccionado = $0 }
            )) {
                Text(L.t("General", "General")).tag(0)
                Text(L.t("Miembros", "Members")).tag(1)
                Text(L.t("Asistencia", "Attendance")).tag(2)
                Text(L.t("Seguimiento", "Follow-up")).tag(3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer(minLength: 0)

            // El periodo: los cinco de `PeriodoInforme`, que ya existían.
            Picker("", selection: Binding(
                get: { vm.periodoTipo },
                set: { vm.periodoTipo = $0 }
            )) {
                ForEach(PeriodoInforme.allCases, id: \.self) { p in
                    Text(p.etiqueta).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    // MARK: - General

    @ViewBuilder
    private var pestanaGeneral: some View {
        let r = vm.resumen
        VStack(alignment: .leading, spacing: 12) {
            // El total, con su nota.
            VStack(alignment: .leading, spacing: 2) {
                Text("\(r.totalMiembros)")
                    .font(.system(size: 32, weight: .bold))
                    .monospacedDigit()
                Text(L.t("personas en el padrón · \(r.periodo)",
                         "people in the registry · \(r.periodo)"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .tarjetaMac(14)

            HStack(alignment: .top, spacing: 12) {
                panel(L.t("POR ESTADO", "BY STATUS")) {
                    if r.porEstado.isEmpty { vacio } else {
                        barras(r.porEstado, total: r.totalMiembros, tinta: nil)
                    }
                }
                panel(L.t("POR MINISTERIO", "BY MINISTRY")) {
                    if r.porMinisterio.isEmpty { vacio } else {
                        barras(r.porMinisterio,
                               total: r.porMinisterio.map(\.1).max() ?? 1, tinta: Paleta.cian)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                panel(L.t("ALTAS POR MES", "NEW PER MONTH")) {
                    let altas = r.altasPorMes
                    if altas.allSatisfy({ $0.altas == 0 }) { vacio } else {
                        Chart(altas) { a in
                            BarMark(x: .value("Mes", a.mes), y: .value("Altas", a.altas))
                                .foregroundStyle(Paleta.brand)
                                .cornerRadius(3)
                        }
                        .frame(height: 130)
                        .padding(.top, 14)
                    }
                }
                panel(L.t("ESTADO DE EXPEDIENTES", "FILE STATUS")) {
                    let completos = r.expedienteCompleto
                    let total = max(1, completos + r.expedienteIncompleto)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(L.t("Completos", "Complete")).font(.system(size: 12))
                            Spacer(minLength: 6)
                            Text("\(completos)")
                                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.quaternary)
                                Capsule().fill(Paleta.brand)
                                    .frame(width: g.size.width * CGFloat(completos) / CGFloat(total))
                            }
                        }
                        .frame(height: 8)
                        HStack {
                            Text(L.t("Incompletos", "Incomplete"))
                                .font(.system(size: 12)).foregroundStyle(Paleta.aviso)
                            Spacer(minLength: 6)
                            Text("\(r.expedienteIncompleto)")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Paleta.aviso)
                        }
                    }
                    .padding(.top, 14)
                }
                .frame(width: 300)
            }

            if !r.traslados.isEmpty {
                panel(L.t("TRASLADOS", "TRANSFERS")) {
                    VStack(spacing: 0) {
                        ForEach(r.traslados) { t in
                            HStack(spacing: 10) {
                                Text(t.folioLegible)
                                    .font(.system(size: 11.5)).monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .leading)
                                // Entrada en verde, salida en ámbar: quien entra
                                // suma y quien sale hay que despedirlo bien.
                                Text(t.tipoTraslado)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(t.sentido == .entrada ? Paleta.brand : Paleta.aviso)
                                    .frame(width: 70, alignment: .leading)
                                Text(t.persona).font(.system(size: 12.5, weight: .medium))
                                Spacer(minLength: 8)
                                Text(t.iglesia)
                                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(t.fecha.isEmpty ? "—" : Fechas.diaLegible(t.fecha))
                                    .font(.system(size: 11.5)).foregroundStyle(.tertiary)
                                    .frame(width: 110, alignment: .trailing)
                            }
                            .padding(.vertical, 7)
                            .overlay(alignment: .bottom) { Divider() }
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Miembros: las ocho tarjetas que filtran

    @ViewBuilder
    private var pestanaMiembros: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4),
                      spacing: 9) {
                ForEach(TarjetaPadron.allCases) { t in
                    let activa = vm.tarjeta == t
                    Button {
                        // Volver a pulsar la activa quita el filtro: es lo que
                        // hace el diseño y evita quedarse encerrado en un
                        // recorte sin saber cómo salir.
                        vm.tarjeta = activa ? .todos : t
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(vm.cuenta(t))")
                                .font(.system(size: 21, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(activa ? Paleta.brand : .primary)
                            Text(t.etiqueta)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(activa ? Paleta.brandFill : Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            // Las dos ramas tienen que ser el MISMO tipo: `.quaternary`
                            // es un `ShapeStyle`, no un `Color`, así que junto a
                            // `Paleta.brandStroke` el ternario no compila.
                            .stroke(activa ? Paleta.brandStroke : Color.secondary.opacity(0.25),
                                    lineWidth: activa ? 1 : 0.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // **La frase del handoff, que además es una regla.** Cada tarjeta
            // cuenta con la MISMA regla con la que filtra la lista —
            // `TarjetaPadron.incluye(_:año:)`—, nunca leyendo un resumen
            // aparte. Es lo que evita que el número de arriba y la lista de
            // abajo se contradigan.
            Text(vm.tarjeta == .todos
                 ? L.t("Cada tarjeta filtra la lista de abajo, y su número se cuenta con la misma regla — nunca se lee de un resumen.",
                       "Every card filters the list below, and its number is counted with the same rule — never read from a summary.")
                 : L.t("Filtrando por «\(vm.tarjeta.etiqueta)».",
                       "Filtering by “\(vm.tarjeta.etiqueta)”."))
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            let lista = vm.miembros.filter { vm.tarjeta.incluye($0, año: vm.añoSeleccionado) }
            if lista.isEmpty {
                Text(L.t("No hay nadie en este recorte.", "Nobody in this slice."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(lista) { m in
                        HStack(spacing: 12) {
                            Text(m.iniciales)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Paleta.brand)
                                .frame(width: 32, height: 32)
                                .background(Paleta.brandFill, in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.nombre).font(.system(size: 13, weight: .semibold))
                                Text(m.cargoLegible)
                                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(m.estado.etiqueta)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(m.estado.color)
                                .padding(.horizontal, 9).padding(.vertical, 2)
                                .background(m.estado.color.opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .tarjetaMac(10)
                    }
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Asistencia

    @ViewBuilder
    private var pestanaAsistencia: some View {
        if let a = vm.asistencia {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    kpi(L.t("Asistencia media", "Average attendance"), "\(a.promedioPct)%", Paleta.brand)
                    kpi(L.t("Servicios", "Services"), "\(a.serviciosPeriodo)", .primary)
                    kpi(L.t("Presentes de media", "Average present"), "\(a.presentesPromedio)", .primary)
                    kpi(L.t("Mejor servicio", "Best service"),
                        a.mejorServicio.isEmpty ? "—" : a.mejorServicio, Paleta.placaMorado)
                }

                // El aviso que evita que el informe parezca roto.
                if vm.sinListasTomadas {
                    Label(L.t("Hubo servicios en el periodo, pero no se tomó lista en ninguno.",
                              "There were services this period, but attendance was never taken."),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Paleta.aviso)
                }

                if !a.meses.isEmpty {
                    panel(L.t("PRESENTES CONTRA PADRÓN", "PRESENT VS ROSTER")) {
                        Chart(a.meses) { m in
                            BarMark(x: .value("Mes", m.mes), y: .value("Presentes", m.presentes))
                                .foregroundStyle(Paleta.brand)
                                .cornerRadius(4)
                        }
                        .frame(height: 150)
                        .padding(.top, 14)
                    }
                }
            }
            .padding(.top, 16)
        } else {
            vacio.padding(.top, 30)
        }
    }

    // MARK: - Seguimiento: alertas AGRUPADAS POR TIPO

    @ViewBuilder
    private var pestanaSeguimiento: some View {
        let porTipo = Dictionary(grouping: vm.alertas, by: \.tipo)
        if porTipo.isEmpty {
            Text(L.t("Nadie necesita seguimiento ahora mismo.",
                     "Nobody needs follow-up right now."))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.top, 30)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // **Agrupadas por tipo, como el handoff.** Cinco personas que
                // llevan tres servicios sin venir son UN problema, no cinco
                // avisos sueltos: agrupadas se ve el patrón.
                ForEach(InformesMembresiaViewModel.TipoAlerta.allCases, id: \.self) { tipo in
                    if let gente = porTipo[tipo], !gente.isEmpty {
                        panel(tipo.etiqueta.uppercased()) {
                            VStack(spacing: 0) {
                                ForEach(gente) { a in
                                    HStack(spacing: 10) {
                                        Text(a.miembro.nombre)
                                            .font(.system(size: 12.5, weight: .medium))
                                        Spacer(minLength: 8)
                                        Text(a.detalle)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 7)
                                    .overlay(alignment: .bottom) { Divider() }
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.top, 16)
        }
    }

    // MARK: - Piezas

    private func barras(_ datos: [(String, Int)], total: Int, tinta: Color?) -> some View {
        VStack(spacing: 9) {
            ForEach(Array(datos.enumerated()), id: \.offset) { _, d in
                VStack(spacing: 4) {
                    HStack {
                        Text(d.0).font(.system(size: 12)).lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(d.1)")
                            .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule().fill(tinta ?? Paleta.brand)
                                .frame(width: g.size.width * CGFloat(d.1) / CGFloat(max(1, total)))
                        }
                    }
                    .frame(height: 7)
                }
            }
        }
        .padding(.top, 14)
    }

    private func kpi(_ k: String, _ v: String, _ tinta: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(k).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Text(v)
                .font(.system(size: 22, weight: .bold)).monospacedDigit()
                .foregroundStyle(tinta).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tarjetaMac(14)
    }

    private func panel<C: View>(_ titulo: String, @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundStyle(.secondary)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tarjetaMac(14)
    }

    private var vacio: some View {
        Text(L.t("Todavía no hay datos para este periodo.",
                 "No data for this period yet."))
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 26)
    }
}
