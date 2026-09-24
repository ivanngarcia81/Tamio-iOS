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
                // Bajo el selector, solo con "Rango": con otro periodo las
                // dos fechas no significan nada y ocuparían sitio para nada.
                if vm.periodoTipo == .rango { bandaDeRango }
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
        // Con cada cambio de periodo: la asistencia se cuenta del periodo.
        .task(id: vm.periodo) { await vm.cargarPadron() }
    }

    // MARK: - Pestañas y periodo

    /// **En una fila si cabe, en dos si no.** Las pestañas, el periodo y el
    /// botón en una sola fila pedían 1090 pt de ventana con el inspector
    /// CERRADO —media pantalla de una MacBook de 14" son 900—, y antes de
    /// llegar ahí el botón ya se encogía a "…": cabía rompiéndose. Medido el
    /// 23-sep. En dos filas, el periodo y el CSV bajan debajo de las pestañas
    /// y la pantalla cabe entera.
    private var cabecera: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pestanas
                Spacer(minLength: 0)
                selectorDePeriodo
                botonCSV
            }
            VStack(alignment: .leading, spacing: 10) {
                pestanas
                HStack(spacing: 12) {
                    selectorDePeriodo
                    Spacer(minLength: 0)
                    botonCSV
                }
            }
        }
    }

    /// **Los meses con su inicial cuando no caben enteros.** A media pantalla
    /// el panel de altas deja unos 20 pt por mes y Charts cortaba cada nombre
    /// en "F…", "S…": doce puntos suspensivos no dicen ningún mes. La inicial
    /// sí, porque el orden de enero a diciembre ya se sabe; es lo que hace el
    /// calendario de macOS. 30 pt por mes es lo que pide "May" o "Sep" a 11 pt.
    @AxisContentBuilder
    private func ejeDeMeses(ancho: CGFloat, cuantos: Int) -> some AxisContent {
        let apretado = cuantos > 0 && ancho / CGFloat(cuantos) < 30
        AxisMarks { v in
            AxisGridLine()
            AxisValueLabel {
                if let mes = v.as(String.self) {
                    Text(apretado ? String(mes.prefix(1)) : mes)
                }
            }
        }
    }

    private var pestanas: some View {
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
    }

    // El periodo: los cinco de `PeriodoInforme`, que ya existían.
    private var selectorDePeriodo: some View {
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

    // **El mismo CSV que el iPhone**, `csvExportString` del ViewModel: dos
    // exportadores del mismo informe acabarían diciendo cosas distintas en
    // cuanto uno ganara una sección. Cambia el gesto, no el archivo: aquí se
    // guarda donde uno diga, como en Configuración.
    //
    // `fixedSize` para que nunca se encoja a "…": sin él, `ViewThatFits` daba
    // por buena la fila única con el botón ya roto.
    private var botonCSV: some View {
        Button(L.t("Exportar como CSV…", "Export as CSV…")) { exportarCSV() }
            .fixedSize()
    }

    // MARK: - El rango

    /// **La banda Desde/Hasta del periodo "Rango".** Antes el selector ofrecía
    /// "Rango" y nadie en el Mac escribía `rangoDesde` ni `rangoHasta`, así que
    /// elegirlo dejaba el informe clavado en «del mes pasado a hoy» sin forma de
    /// cambiarlo: una opción que no se podía usar.
    ///
    /// Cada fecha limita a la otra —el `in:` de los dos selectores, igual que
    /// en el iPhone—, y por eso el rango no puede quedar al revés: no hay que
    /// avisar de un error que no se puede cometer.
    private var bandaDeRango: some View {
        HStack(spacing: 10) {
            Text(L.t("RANGO", "RANGE"))
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundStyle(.secondary)
            Text(L.t("Desde", "From")).font(.system(size: 12))
            DatePicker("", selection: Binding(
                get: { vm.rangoDesde },
                set: { vm.rangoDesde = $0 }
            ), in: ...vm.rangoHasta, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .fixedSize()
            Text(L.t("Hasta", "To")).font(.system(size: 12))
            DatePicker("", selection: Binding(
                get: { vm.rangoHasta },
                set: { vm.rangoHasta = $0 }
            ), in: vm.rangoDesde..., displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .fixedSize()
            Spacer(minLength: 8)
            Text(L.t("Cada fecha limita a la otra, así que el rango nunca puede quedar al revés.",
                     "Each date clamps the other, so the range can never run backwards."))
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    // MARK: - Exportar

    /// Se escribe a un temporal y se copia encima del destino elegido, que es
    /// lo que ya hace Configuración con sus CSV. El nombre lleva el periodo
    /// para que dos exportaciones no se pisen en Descargas.
    private func exportarCSV() {
        let periodo = vm.etiquetaPeriodo
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let nombre = L.t("Membresia", "Membership") + "-\(periodo).csv"
        let origen = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        guard (try? vm.csvExportString.write(to: origen, atomically: true, encoding: .utf8)) != nil
        else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = nombre
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destino = panel.url else { return }
        try? FileManager.default.removeItem(at: destino)
        try? FileManager.default.copyItem(at: origen, to: destino)
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

            filaDePaneles {
                panel(L.t("POR ESTADO", "BY STATUS"), estira: true) {
                    if r.porEstado.isEmpty { vacio } else {
                        barras(r.porEstado, total: r.totalMiembros, tinta: nil)
                    }
                }
                panel(L.t("POR MINISTERIO", "BY MINISTRY"), estira: true) {
                    if r.porMinisterio.isEmpty { vacio } else {
                        barras(r.porMinisterio,
                               total: r.porMinisterio.map(\.1).max() ?? 1, tinta: Paleta.cian)
                    }
                }
            }

            filaDePaneles {
                panel(L.t("ALTAS POR MES", "NEW PER MONTH"), estira: true) {
                    let altas = r.altasPorMes
                    if altas.allSatisfy({ $0.altas == 0 }) { vacio } else {
                        GeometryReader { g in
                            Chart(altas) { a in
                                BarMark(x: .value("Mes", a.mes), y: .value("Altas", a.altas))
                                    .foregroundStyle(Paleta.brand)
                                    .cornerRadius(3)
                            }
                            .chartXAxis { ejeDeMeses(ancho: g.size.width, cuantos: altas.count) }
                        }
                        .frame(height: 130)
                        .padding(.top, 14)
                    }
                }
                panel(L.t("ESTADO DE EXPEDIENTES", "FILE STATUS"), estira: true) {
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
                // **Con cabecera y con estado, como el handoff.** Antes se
                // llamaba "Traslados" y pintaba el folio sin decir que era un
                // folio: en un documento que se enseña a la junta, una columna
                // de códigos sin nombre obliga a preguntar qué son.
                panel(L.t("MOVIMIENTOS DE TRASLADO", "TRANSFER MOVEMENTS")) {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Text(L.t("FOLIO", "FOLIO")).frame(width: 90, alignment: .leading)
                            Text(L.t("TIPO", "TYPE")).frame(width: 70, alignment: .leading)
                            Text(L.t("PERSONA", "PERSON"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(L.t("IGLESIA", "CHURCH"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(L.t("FECHA", "DATE")).frame(width: 100, alignment: .leading)
                            Text(L.t("ESTADO", "STATUS")).frame(width: 96, alignment: .leading)
                        }
                        .font(.system(size: 10.5, weight: .semibold)).kerning(0.4)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 6)
                        .overlay(alignment: .bottom) { Divider() }

                        ForEach(r.traslados) { t in
                            HStack(spacing: 10) {
                                Text(t.folioLegible)
                                    .font(.system(size: 11.5)).monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                // Entrada en verde, salida en ámbar: quien entra
                                // suma y quien sale hay que despedirlo bien.
                                Text(t.tipoTraslado)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(t.sentido == .entrada ? Paleta.brand : Paleta.aviso)
                                    .frame(width: 70, alignment: .leading)
                                Text(t.persona).font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(t.iglesia.isEmpty ? "—" : t.iglesia)
                                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(t.fecha.isEmpty ? "—" : Fechas.diaLegible(t.fecha))
                                    .font(.system(size: 11.5)).foregroundStyle(.tertiary)
                                    .frame(width: 100, alignment: .leading)
                                Text(t.estado)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.14),
                                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .frame(width: 96, alignment: .leading)
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
            // `TarjetaPadron.incluye(_:en:)`—, nunca leyendo un resumen
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

            let lista = vm.miembros.filter { vm.tarjeta.incluye($0, en: vm.periodo) }
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
                // **Las cifras de las fichas, como el iPhone**, y no las del
                // resumen del repositorio: el ViewModel ya las cuenta de UNA
                // fuente para que no se contradigan. Y sin listas tomadas son
                // "—", no cero: salía "0 %" en verde y "Mejor servicio: 0",
                // un culto sin nadie coronado como el mejor, justo encima del
                // aviso que dice que falta el dato.
                let sinDato = vm.sinListasTomadas
                HStack(spacing: 12) {
                    kpi(L.t("Asistencia media", "Average attendance"),
                        vm.porcentajeGeneral.map { "\($0)%" } ?? "—",
                        vm.porcentajeGeneral == nil ? .secondary : Paleta.brand)
                    kpi(L.t("Servicios", "Services"), "\(vm.serviciosDelPeriodo)", .primary)
                    kpi(L.t("Presentes de media", "Average present"),
                        sinDato ? "—" : "\(vm.promedioPorServicio)", sinDato ? .secondary : .primary)
                    kpi(L.t("Mejor servicio", "Best service"),
                        sinDato || a.mejorServicio.isEmpty ? "—" : a.mejorServicio,
                        sinDato ? .secondary : Paleta.placaMorado)
                }

                // El aviso que evita que el informe parezca roto.
                if vm.sinListasTomadas {
                    Label(L.t("Hubo servicios en el periodo, pero no se tomó lista en ninguno.",
                              "There were services this period, but attendance was never taken."),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Paleta.aviso)
                }

                // Sin listas, el gráfico era un marco en blanco debajo del
                // aviso que ya explica por qué: no añadía nada.
                if !a.meses.isEmpty && !sinDato {
                    panel(L.t("PRESENTES CONTRA PADRÓN", "PRESENT VS ROSTER")) {
                        GeometryReader { g in
                            Chart(a.meses) { m in
                                BarMark(x: .value("Mes", m.mes), y: .value("Presentes", m.presentes))
                                    .foregroundStyle(Paleta.brand)
                                    .cornerRadius(4)
                            }
                            .chartXAxis { ejeDeMeses(ancho: g.size.width, cuantos: a.meses.count) }
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
                // Alto fijo: cuando el texto se reduce para caber, la tarjeta
                // encogía con él y quedaba más baja que sus vecinas.
                .frame(height: 28, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tarjetaMac(14)
    }

    /// **`estira` iguala la altura de las tarjetas que van en la misma fila.**
    ///
    /// Sin él cada tarjeta mide lo que mide su contenido, y en una fila de dos
    /// eso se ve torcido en cuanto una tiene más que la otra: "Por estado" con
    /// una barra al lado de "Por ministerio" con tres, o el gráfico de altas al
    /// lado de dos cifras. Iván lo vio en su pantalla.
    ///
    /// **El estiramiento va ANTES de `tarjetaMac`, y ese es el detalle.** Puesto
    /// después, el `frame` envuelve a la tarjeta ya pintada: el fondo conserva
    /// su tamaño y lo único que pasa es que queda CENTRADO en el hueco, que es
    /// peor que el problema. Antes del fondo, el que crece es el contenido y el
    /// fondo lo sigue.
    ///
    /// Y `alignment: .topLeading` para que lo de dentro siga arriba en vez de
    /// irse al centro de la tarjeta ya crecida.
    private func panel<C: View>(_ titulo: String, estira: Bool = false,
                                @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundStyle(.secondary)
            c()
        }
        .frame(maxWidth: .infinity,
               maxHeight: estira ? .infinity : nil,
               alignment: .topLeading)
        .padding(16)
        .tarjetaMac(14)
    }

    /// Una fila de tarjetas de la misma altura.
    ///
    /// El `fixedSize` vertical es la otra mitad de `estira`: sus tarjetas piden
    /// alto infinito, y sin esto la fila se lo tomaría —dentro de un `ScrollView`
    /// hay todo el alto del mundo—. Con él la fila mide su alto IDEAL, que es el
    /// de la tarjeta más alta, y las demás se estiran hasta ahí.
    private func filaDePaneles<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack(alignment: .top, spacing: 12) { c() }
            .fixedSize(horizontal: false, vertical: true)
    }

    private var vacio: some View {
        Text(L.t("Todavía no hay datos para este periodo.",
                 "No data for this period yet."))
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 26)
    }
}
