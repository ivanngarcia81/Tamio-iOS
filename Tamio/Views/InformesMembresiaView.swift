import SwiftUI
import UIKit

struct InformesMembresiaView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var vm = InformesMembresiaViewModel()
    @State private var mostrarRango = false
    @State private var mostrarShareCSV = false
    @State private var urlCSV: URL? = nil

    private let informes = [
        (L.t("General", "General"), L.t("Distribuciones, altas por mes y movimientos", "Distributions, monthly additions & transfers")),
        (L.t("Miembros", "Members"), L.t("Padrón del periodo con ocho recortes", "Roster for the period with eight slices")),
        (L.t("Asistencia", "Attendance"), L.t("27 servicios · 78% de asistencia general", "27 services · 78% general attendance")),
        (L.t("Seguimiento", "Follow-up"), L.t("Alertas pastorales sin revisar", "Unreviewed pastoral alerts")),
    ]
    private let alertasSeguimiento = 3

    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        encabezado(cuerpo)
            .toolbar { barra }
            .sheet(isPresented: $mostrarRango) {
                RangoSheet(desde: $vm.rangoDesde, hasta: $vm.rangoHasta)
            }
            .sheet(isPresented: $mostrarShareCSV) {
                if let url = urlCSV { ShareSheet(items: [url]) }
            }
    }

    private var cuerpo: some View {
        contenidoInforme
            // **Capas, no hermanos**, como en Ingresos y en Aportantes: los
            // selectores iban dentro del `ScrollView`, así que se iban con él
            // y las tarjetas no pasaban por detrás de nada. Aquí el contenido
            // corre bajo la cabecera, que es lo único que le da al material
            // algo que difuminar — y sin eso el glass de los chips se resuelve
            // como una cápsula gris sobre un fondo plano.
            .safeAreaInset(edge: .top, spacing: 0) { cabeceraInformes }
            .colchonInferior()
    }

    /// Teléfono: título en línea, como Ingresos, Aportantes y Depósitos. Con
    /// `.large` el sistema reservaba la banda del título grande encima de la
    /// tira de selectores y la dejaba en blanco —dos alturas de cabecera para
    /// una pantalla que ya dice en el chip lo que se está viendo—. En iPad se
    /// queda el titular con su subtítulo, que es donde hay sitio.
    @ViewBuilder
    private func encabezado<C: View>(_ contenido: C) -> some View {
        if compacto {
            contenido
                .navigationTitle(L.t("Informes de membresía", "Membership reports"))
                .navigationBarTitleDisplayMode(.inline)
        } else {
            contenido
                .encabezadoNav(L.t("Informes de membresía", "Membership reports"),
                               L.t("Panorama, seguimiento e informes del padrón",
                                   "Overview, follow-up & roster reports"))
                .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Barra

    /// **Imprimir y exportar suben a la barra.** Eran dos cápsulas dibujadas a
    /// mano con `brandFill` en medio del contenido, justo debajo del titular
    /// del informe: se leían como parte del dato y no como acciones, y se iban
    /// con el scroll. Van juntas en un menú porque son la misma pregunta
    /// —sacar esto de la pantalla—, como el "Archivo" de Aportantes.
    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) { menuArchivo }
    }

    private var menuArchivo: some View {
        Menu {
            Button { imprimirInforme() } label: {
                Label(L.t("Imprimir / PDF", "Print / PDF"), systemImage: "printer")
            }
            Button { prepararCSV() } label: {
                Label(L.t("Exportar (CSV)", "Export (CSV)"), systemImage: "square.and.arrow.up")
            }
        } label: {
            Label(L.t("Archivo", "File"), systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.glass)
        .labelStyle(.iconOnly)
        .tint(Paleta.brand)
        // El menú solo saca el informe que se está viendo, y de los cuatro
        // solo uno existe todavía.
        .disabled(vm.informeSeleccionado != 0)
    }

    /// La tira de controles: qué informe y de qué periodo. El periodo solo se
    /// dibuja con el informe que existe — un selector de fechas encima de un
    /// "Próximamente" no cambia nada de lo que se ve.
    private var cabeceraInformes: some View {
        VStack(alignment: .leading, spacing: 10) {
            // El margen lateral va DENTRO del scroll horizontal, no fuera: por
            // fuera recortaba el chip que se sale por el borde justo donde el
            // dedo tiene que empezar a arrastrar para alcanzarlo.
            selectorInforme
            if vm.informeSeleccionado == 0 {
                selectorPeriodo.padding(.horizontal, Esp.pantalla)
            }
        }
        .padding(.vertical, Esp.chip)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    // MARK: - Helpers de exportación

    private func imprimirInforme() {
        let pc = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = L.t("Informe de Membresía", "Membership Report") + " \(vm.etiquetaPeriodo)"
        info.outputType = .general
        pc.printInfo = info
        pc.printFormatter = UISimpleTextPrintFormatter(text: vm.textoInforme)
        pc.present(animated: true)
    }

    private func prepararCSV() {
        let nombre = vm.etiquetaPeriodo
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Membresia-\(nombre).csv")
        try? vm.csvExportString.write(to: url, atomically: true, encoding: .utf8)
        urlCSV = url
        mostrarShareCSV = true
    }

    // MARK: - Selector de periodo

    // MARK: - Selector de tipo de informe (solo iPad)

    /// **Los cuatro informes, también en el teléfono.** Esta tira estaba
    /// detrás de `sizeClass == .regular`, así que en el iPhone no existía: la
    /// pantalla se llamaba "Informes de membresía", prometía "panorama,
    /// seguimiento e informes del padrón" y solo enseñaba el primero, sin
    /// forma de llegar a los otros tres ni de saber que estaban.
    ///
    /// Los tres que faltan por construir dicen "Próximamente" al abrirse. Es
    /// menos de lo que promete el hub, pero es lo que hay, y decirlo es mejor
    /// que esconderlos.
    private var selectorInforme: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: Esp.hueco) {
                HStack(spacing: Esp.hueco) {
                    ForEach(Array(informes.enumerated()), id: \.offset) { idx, informe in
                        chipInforme(idx, informe.0)
                    }
                }
                .padding(.horizontal, Esp.pantalla)
                .padding(.vertical, 2)
            }
        }
        // El recorte del scroll horizontal se come el halo de la cápsula si no
        // se le deja aire.
        .scrollClipDisabled()
    }

    /// El elegido va en `.glassProminent` y los demás en `.glass`. Las dos
    /// ramas se escriben enteras porque `buttonStyle` no admite un ternario:
    /// son tipos distintos, no dos valores del mismo.
    @ViewBuilder
    private func chipInforme(_ idx: Int, _ titulo: String) -> some View {
        if idx == vm.informeSeleccionado {
            Button { vm.informeSeleccionado = idx } label: { etiquetaChip(idx, titulo, sel: true) }
                .buttonStyle(.glassProminent)
                .tint(Paleta.brand)
        } else {
            Button { vm.informeSeleccionado = idx } label: { etiquetaChip(idx, titulo, sel: false) }
                .buttonStyle(.glass)
        }
    }

    private func etiquetaChip(_ idx: Int, _ titulo: String, sel: Bool) -> some View {
        HStack(spacing: 5) {
            Text(titulo).font(.subheadline.weight(sel ? .semibold : .medium))
            // El badge de alertas se queda incluso en el chip elegido: dice
            // cuántas hay sin revisar, no si está seleccionado.
            if idx == 3 && alertasSeguimiento > 0 {
                Text("\(alertasSeguimiento)")
                    .font(.caption2.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, Esp.hueco).padding(.vertical, 1)
                    .background(Paleta.badge, in: Capsule())
            }
        }
    }

    private var selectorPeriodo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fila 1: Menu tipo + chips de año (o botón de rango)
            HStack(spacing: 8) {
                Menu {
                    ForEach(PeriodoInforme.allCases, id: \.self) { p in
                        Button {
                            withAnimation(.spring(duration: 0.25)) { vm.periodoTipo = p }
                        } label: {
                            if p == vm.periodoTipo { Label(p.etiqueta, systemImage: "checkmark") }
                            else { Text(p.etiqueta) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.periodoTipo.etiqueta)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)

                if vm.periodoTipo == .mes || vm.periodoTipo == .trimestre || vm.periodoTipo == .anio {
                    añoChips
                } else if vm.periodoTipo == .rango {
                    Button { mostrarRango = true } label: {
                        HStack(spacing: 4) {
                            Text(vm.etiquetaPeriodo)
                            Image(systemName: "calendar").font(.caption2)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.glass)
                }
                Spacer()
            }

            // Fila 2: chips de mes o trimestre (solo cuando aplica)
            subSelectorPeriodo
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .animation(.spring(duration: 0.25), value: vm.periodoTipo)
    }

    @ViewBuilder
    private var subSelectorPeriodo: some View {
        switch vm.periodoTipo {
        case .mes:       mesChips
        case .trimestre: trimestreChips
        default:         EmptyView()
        }
    }

    // MARK: - Sub-selectores

    /// Los tres sub-selectores comparten constructor: eran tres cápsulas
    /// dibujadas a mano con tres combinaciones distintas de relleno y color de
    /// texto —`brandFill` con texto verde en el año, verde macizo con texto
    /// blanco en el mes—, así que un año elegido y un mes elegido no se
    /// parecían aunque significaran lo mismo.
    @ViewBuilder
    private func chipPeriodo(_ texto: String, sel: Bool, _ accion: @escaping () -> Void) -> some View {
        if sel {
            Button { withAnimation(.spring(duration: 0.2)) { accion() } } label: {
                Text(texto).font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(Paleta.brand)
        } else {
            Button { withAnimation(.spring(duration: 0.2)) { accion() } } label: {
                Text(texto).font(.subheadline.weight(.medium))
            }
            .buttonStyle(.glass)
        }
    }

    private var añoChips: some View {
        GlassEffectContainer(spacing: Esp.hueco) {
            HStack(spacing: Esp.hueco) {
                ForEach([2024, 2025, 2026], id: \.self) { año in
                    chipPeriodo(String(año), sel: año == vm.añoSeleccionado) {
                        vm.añoSeleccionado = año
                    }
                }
            }
        }
    }

    private var mesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: Esp.hueco) {
                HStack(spacing: Esp.hueco) {
                    ForEach(1...12, id: \.self) { m in
                        chipPeriodo(InformesMembresiaViewModel.nombreMes(m),
                                    sel: m == vm.mesSeleccionado) {
                            vm.mesSeleccionado = m
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
    }

    private var trimestreChips: some View {
        GlassEffectContainer(spacing: Esp.hueco) {
            HStack(spacing: Esp.hueco) {
                ForEach(1...4, id: \.self) { q in
                    chipPeriodo("Q\(q)", sel: q == vm.trimestreSeleccionado) {
                        vm.trimestreSeleccionado = q
                    }
                }
            }
        }
    }

    // MARK: - Contenido del informe

    private var contenidoInforme: some View {
        let r = vm.resumen
        let maxEstado = r.porEstado.map { $0.1 }.max() ?? 1
        let maxMinisterio = r.porMinisterio.map { $0.1 }.max() ?? 1
        let maxAltas = r.altasPorMes.map { $0.altas }.max() ?? 1
        let totalAltas = r.altasPorMes.map(\.altas).reduce(0, +)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if vm.informeSeleccionado != 0 {
                    ContentUnavailableView(L.t("Próximamente", "Coming soon"),
                                           systemImage: "doc.text.magnifyingglass",
                                           description: Text(L.t("Este informe llegará pronto.", "This report is coming soon.")))
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                // Encabezado
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Panorama general", "General overview"))
                        .font(.title3.weight(.semibold))
                    Text("\(r.totalMiembros) \(L.t("miembros · \(r.periodo)", "members · \(r.periodo)"))")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                // Dos columnas de KPIs — siempre 2 en iPad, 1 en iPhone
                let colsKPI: [GridItem] = sizeClass == .regular
                    ? [GridItem(.flexible()), GridItem(.flexible())]
                    : [GridItem(.flexible())]
                LazyVGrid(columns: colsKPI, spacing: 16) {
                    // Por estado
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            TituloSeccion(texto: L.t("MIEMBROS POR ESTADO", "MEMBERS BY STATUS"))
                            ForEach(r.porEstado, id: \.0) { nombre, valor in
                                HStack(spacing: 8) {
                                    Text(nombre).font(.subheadline).frame(minWidth: 80, alignment: .leading)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brandMuted)
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brand)
                                            .scaleEffect(x: max(0.001, Double(valor) / Double(maxEstado)), y: 1, anchor: .leading)
                                    }
                                    .frame(height: 8)
                                    Text("\(valor)")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Paleta.brand)
                                        .frame(width: 32, alignment: .trailing)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxHeight: .infinity)

                    // Por ministerio
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            TituloSeccion(texto: L.t("MIEMBROS POR MINISTERIO", "MEMBERS BY MINISTRY"))
                            ForEach(r.porMinisterio, id: \.0) { nombre, valor in
                                HStack(spacing: 8) {
                                    Text(nombre).font(.subheadline).frame(minWidth: 80, alignment: .leading)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brandMuted)
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brand)
                                            .scaleEffect(x: max(0.001, Double(valor) / Double(maxMinisterio)), y: 1, anchor: .leading)
                                    }
                                    .frame(height: 8)
                                    Text("\(valor)")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Paleta.brand)
                                        .frame(width: 32, alignment: .trailing)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxHeight: .infinity)
                }

                // Expediente + Nuevos por mes — siempre 2 en iPad, 1 en iPhone
                LazyVGrid(columns: colsKPI, spacing: 16) {
                    // Expediente
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            TituloSeccion(texto: L.t("ESTADO DEL EXPEDIENTE", "FILE STATUS"))
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(r.expedienteCompleto)")
                                        .font(.title2.weight(.bold)).monospacedDigit()
                                        .foregroundStyle(Paleta.brand)
                                        .contentTransition(.numericText())
                                    Text(L.t("Completo", "Complete"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                VStack(spacing: 4) {
                                    Text("\(r.expedienteIncompleto)")
                                        .font(.title2.weight(.bold)).monospacedDigit()
                                        .foregroundStyle(Paleta.aviso)
                                        .contentTransition(.numericText())
                                    Text(L.t("Incompleto", "Incomplete"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Nuevos por mes
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            TituloSeccion(texto: L.t("NUEVOS POR MES", "NEW PER MONTH"))
                            Text(L.t("\(totalAltas) altas en el periodo · por fecha de ingreso",
                                     "\(totalAltas) additions in period · by join date"))
                                .font(.caption).foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(r.altasPorMes) { m in
                                    VStack(spacing: 4) {
                                        Text("\(m.altas)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Paleta.brand)
                                            .contentTransition(.numericText())
                                        VStack(spacing: 0) {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Paleta.brand)
                                                .frame(height: 36 * CGFloat(m.altas) / CGFloat(maxAltas))
                                        }
                                        .frame(height: 36)
                                        Text(m.mes).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Movimientos de membresía
                Tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TituloSeccion(texto: L.t("MOVIMIENTOS DE MEMBRESÍA", "MEMBERSHIP MOVEMENTS"))
                            Spacer()
                            // Estaba escrito con la acción vacía: la tabla de
                            // abajo enumera traslados y el enlace prometía
                            // llevar a donde se resuelven, sin llevar a
                            // ninguna parte. Es un `NavigationLink` y no un
                            // botón para que traiga su chevron de vuelta: se
                            // llega desde aquí, no desde el hub, así que a
                            // esta sí le toca el botón de volver.
                            NavigationLink {
                                CartasView()
                            } label: {
                                Text(L.t("Ir a Cartas y traslados", "Go to Letters & transfers"))
                                    .font(.caption).foregroundStyle(Paleta.enlace)
                            }
                            .buttonStyle(.plain)
                        }

                        // Tabla con scroll horizontal — las columnas fijas suman más que un iPhone angosto
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Cabecera
                                HStack(spacing: 0) {
                                    Text(L.t("FOLIO", "FOLIO")).frame(width: 110, alignment: .leading)
                                    Text(L.t("MOVIMIENTO", "MOVEMENT")).frame(width: 90, alignment: .leading)
                                    Text(L.t("PERSONA / IGLESIA", "PERSON / CHURCH")).frame(width: 180, alignment: .leading)
                                    Text(L.t("FECHA", "DATE")).frame(width: 80, alignment: .trailing)
                                    Text(L.t("ESTADO", "STATUS")).frame(width: 120, alignment: .trailing)
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)
                                Divider()

                                ForEach(r.traslados) { t in
                                    HStack(spacing: 0) {
                                        Text(t.folio).font(.caption).monospacedDigit().frame(width: 110, alignment: .leading)
                                        Pill(texto: t.tipoTraslado, color: t.tipoTraslado == L.t("Enviado", "Sent") ? Paleta.aviso : Paleta.brand)
                                            .frame(width: 90, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(t.persona).font(.subheadline.weight(.medium)).lineLimit(1)
                                            Text(t.iglesia).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        .frame(width: 180, alignment: .leading)
                                        Text(t.fecha).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                                        Text(t.estado).font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    if t.id != r.traslados.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
            }
                } // end else (general content)
            .padding(Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
        .animation(.spring(duration: 0.3), value: vm.periodoTipo)
        .animation(.spring(duration: 0.3), value: vm.mesSeleccionado)
        .animation(.spring(duration: 0.3), value: vm.trimestreSeleccionado)
        .animation(.spring(duration: 0.3), value: vm.añoSeleccionado)
    }
}

// MARK: - Share sheet (UIKit bridge)

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Sheet de rango de fechas

private struct RangoSheet: View {
    @Binding var desde: Date
    @Binding var hasta: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("Fecha inicial", "Start date")) {
                    DatePicker("", selection: $desde, in: ...hasta, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Paleta.brand)
                        .labelsHidden()
                }
                Section(L.t("Fecha final", "End date")) {
                    DatePicker("", selection: $hasta, in: desde..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Paleta.brand)
                        .labelsHidden()
                }
            }
            .navigationTitle(L.t("Seleccionar rango", "Select range"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Listo", "Done")) { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Paleta.brand)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
            }
        }
        .hojaEleccion(grande: true)
    }
}
