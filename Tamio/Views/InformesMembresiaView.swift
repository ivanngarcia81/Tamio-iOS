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

    var body: some View {
        contenidoInforme
        .encabezadoNav(L.t("Informes de membresía", "Membership reports"),
                       L.t("Panorama, seguimiento e informes del padrón", "Overview, follow-up & roster reports"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $mostrarRango) {
            RangoSheet(desde: $vm.rangoDesde, hasta: $vm.rangoHasta)
        }
        .sheet(isPresented: $mostrarShareCSV) {
            if let url = urlCSV { ShareSheet(items: [url]) }
        }
    }

    // MARK: - Lista de informes (iPad)

    private var listaColumna: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloSeccion(texto: L.t("INFORMES", "REPORTS"))
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            ForEach(Array(informes.enumerated()), id: \.offset) { idx, informe in
                let sel = idx == vm.informeSeleccionado
                Button { vm.informeSeleccionado = idx } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(informe.0)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(sel ? Paleta.brand : .primary)
                            Text(informe.1)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        if idx == 3 && alertasSeguimiento > 0 {
                            Text("\(alertasSeguimiento)")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Paleta.badge, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(sel ? Paleta.brandFill : Color.clear)
                    .overlay(alignment: .leading) {
                        if sel { Rectangle().fill(Paleta.brand).frame(width: 3) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Panel derecho (iPad)

    @ViewBuilder
    private var panelDerecho: some View {
        switch vm.informeSeleccionado {
        case 0:
            contenidoInforme
        default:
            ContentUnavailableView(L.t("Próximamente", "Coming soon"),
                                   systemImage: "doc.text.magnifyingglass",
                                   description: Text(L.t("Este informe llegará pronto.", "This report is coming soon.")))
                .background(Color(.systemGroupedBackground))
        }
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

    private var selectorInforme: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(informes.enumerated()), id: \.offset) { idx, informe in
                    let sel = idx == vm.informeSeleccionado
                    Button { vm.informeSeleccionado = idx } label: {
                        HStack(spacing: 5) {
                            Text(informe.0)
                                .font(.subheadline.weight(sel ? .semibold : .medium))
                                .foregroundStyle(sel ? .white : .secondary)
                            if idx == 3 && alertasSeguimiento > 0 {
                                Text("\(alertasSeguimiento)")
                                    .font(.caption2.weight(.bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Paleta.badge, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(sel ? Paleta.brand : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.top, 4)
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
                    .foregroundStyle(Paleta.brand)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Paleta.brandFill, in: Capsule())
                }

                if vm.periodoTipo == .mes || vm.periodoTipo == .trimestre || vm.periodoTipo == .anio {
                    añoChips
                } else if vm.periodoTipo == .rango {
                    Button { mostrarRango = true } label: {
                        HStack(spacing: 4) {
                            Text(vm.etiquetaPeriodo)
                            Image(systemName: "calendar").font(.caption2)
                        }
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
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

    private var añoChips: some View {
        HStack(spacing: 6) {
            ForEach([2024, 2025, 2026], id: \.self) { año in
                let sel = año == vm.añoSeleccionado
                Button { withAnimation(.spring(duration: 0.2)) { vm.añoSeleccionado = año } } label: {
                    Text(String(año))
                        .font(.caption.weight(sel ? .semibold : .medium))
                        .foregroundStyle(sel ? Paleta.brand : .secondary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            sel ? Paleta.brandFill : Color(.tertiarySystemFill),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    let sel = m == vm.mesSeleccionado
                    Button { withAnimation(.spring(duration: 0.2)) { vm.mesSeleccionado = m } } label: {
                        Text(InformesMembresiaViewModel.nombreMes(m))
                            .font(.caption.weight(sel ? .semibold : .medium))
                            .foregroundStyle(sel ? .white : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(sel ? Paleta.brand : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trimestreChips: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { q in
                let sel = q == vm.trimestreSeleccionado
                Button { withAnimation(.spring(duration: 0.2)) { vm.trimestreSeleccionado = q } } label: {
                    Text("Q\(q)")
                        .font(.caption.weight(sel ? .semibold : .medium))
                        .foregroundStyle(sel ? .white : .secondary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(sel ? Paleta.brand : Color(.tertiarySystemFill), in: Capsule())
                }
                .buttonStyle(.plain)
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
                if sizeClass == .regular { selectorInforme }
                if sizeClass == .regular && vm.informeSeleccionado != 0 {
                    ContentUnavailableView(L.t("Próximamente", "Coming soon"),
                                           systemImage: "doc.text.magnifyingglass",
                                           description: Text(L.t("Este informe llegará pronto.", "This report is coming soon.")))
                } else {
                selectorPeriodo
                // Encabezado
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("Panorama general", "General overview"))
                            .font(.title3.weight(.semibold))
                        Text("\(r.totalMiembros) \(L.t("miembros · \(r.periodo)", "members · \(r.periodo)"))")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    HStack(spacing: 8) {
                        Button { imprimirInforme() } label: {
                            Label(L.t("Imprimir / PDF", "Print / PDF"), systemImage: "printer")
                                .font(.subheadline.weight(.medium)).foregroundStyle(Paleta.brand)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Paleta.brandFill, in: Capsule())
                        }
                        Button { prepararCSV() } label: {
                            Label(L.t("Exportar (CSV)", "Export (CSV)"), systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.medium)).foregroundStyle(Paleta.brand)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Paleta.brandFill, in: Capsule())
                        }
                        Spacer()
                    }
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
                            Button {
                            } label: {
                                Text(L.t("Ir a Cartas y traslados", "Go to Letters & transfers"))
                                    .font(.caption).foregroundStyle(Paleta.enlace)
                            }
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
            .padding(20)
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
        .presentationDetents([.large])
    }
}
