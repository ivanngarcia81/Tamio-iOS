import SwiftUI
import Charts

/// Pantalla Reportes: lista de tipos de reporte + vista previa. El "Estado
/// financiero" muestra chips KPI, tarjetas y la tabla mensual. Layout seguro.
struct ReportesView: View {
    @State private var vm = ReportesViewModel()
    @State private var mostrarPDF = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 640 {
                HStack(spacing: 0) {
                    listaColumna.frame(width: 300).background(.regularMaterial)
                    Divider()
                    preview
                }
            } else {
                listaColumna.background(.regularMaterial)
            }
        }
        .encabezadoNav(L.t("Reportes", "Reports"), L.t("Listos para imprimir o compartir", "Ready to print or share"))
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.cargar() }
    }

    // MARK: - Lista de reportes

    @ViewBuilder
    private var listaColumna: some View {
        if sizeClass == .regular {
            listaColumnaCore.listStyle(.plain)
        } else {
            listaColumnaCore.listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var listaColumnaCore: some View {
        let rowBG: Color = sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)
        List {
            Section {
                ForEach(vm.tipos) { t in
                    filaReporte(t)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(rowBG)
                        .contentShape(Rectangle())
                        .onTapGesture { vm.seleccionId = t.id }
                }
            } header: {
                Text(L.t("Tesorería", "Treasury"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }

    private func filaReporte(_ t: ReporteTipo) -> some View {
        let sel = t.id == vm.seleccionId
        let rowBG: Color = sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)
        return VStack(alignment: .leading, spacing: 2) {
            Text(t.titulo).font(.subheadline.weight(.semibold)).foregroundStyle(sel ? Paleta.brand : .primary)
            Text(t.subtitulo).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(sel ? Paleta.brandFill : rowBG)
    }

    // MARK: - Vista previa

    @ViewBuilder
    private var preview: some View {
        if vm.seleccionId == "estado", let e = vm.estado {
            estadoFinanciero(e)
        } else {
            ContentUnavailableView(L.t("Próximamente", "Coming soon"), systemImage: "doc.text.magnifyingglass",
                                   description: Text(L.t("Este reporte llega en un próximo slice.", "This report is coming in a later slice.")))
        }
    }

    private func estadoFinanciero(_ e: EstadoFinanciero) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                barraFiltros(e)
                HStack {
                    TituloSeccion(texto: L.t("RESUMEN EN PANTALLA", "ON-SCREEN SUMMARY"))
                    Spacer()
                    Text(L.t("No se incluye en el PDF", "Not included in the PDF")).font(.caption).foregroundStyle(.tertiary)
                }
                chips(e)
                tarjetas(e)
                tablaMensual(e)
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $mostrarPDF) { ReportePDFSheet(e: e, periodo: vm.periodoSel) }
    }

    private func barraFiltros(_ e: EstadoFinanciero) -> some View {
        HStack(spacing: 10) {
            // Periodo: elige el mes; recarga las cifras de ese mes.
            Menu {
                ForEach(vm.periodos, id: \.self) { p in
                    Button { Task { await vm.seleccionarPeriodo(p) } } label: {
                        if p == vm.periodoSel { Label(p, systemImage: "checkmark") } else { Text(p) }
                    }
                }
            } label: { chipFiltro(vm.periodoSel) }

            // Categoría: acota la dona y el ingreso a una categoría (o todas).
            Menu {
                Button { Task { await vm.seleccionarCategoria(nil) } } label: {
                    if vm.categoriaSel == nil { Label(L.t("Todas las categorías", "All categories"), systemImage: "checkmark") }
                    else { Text(L.t("Todas las categorías", "All categories")) }
                }
                Divider()
                ForEach(vm.categorias, id: \.self) { c in
                    Button { Task { await vm.seleccionarCategoria(c) } } label: {
                        if c == vm.categoriaSel { Label(c, systemImage: "checkmark") } else { Text(c) }
                    }
                }
            } label: { chipFiltro(vm.categoriaEtiqueta) }

            Spacer()
            ShareLink(item: vm.resumenTexto) {
                Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            Button { mostrarPDF = true } label: {
                Label(L.t("Vista previa PDF", "PDF preview"), systemImage: "doc.text").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent).tint(Paleta.brand)
        }
    }

    private func chipFiltro(_ t: String) -> some View {
        HStack(spacing: 4) { Text(t); Image(systemName: "chevron.down").font(.caption2) }
            .font(.subheadline).foregroundStyle(.primary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }

    // MARK: - Chips KPI

    private func chips(_ e: EstadoFinanciero) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { chipsLista(e) }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { chipsLista(e) }
        }
    }

    @ViewBuilder
    private func chipsLista(_ e: EstadoFinanciero) -> some View {
        chipKPI(L.t("Ingresos del mes", "Income this month"), e.ingresosMes, Paleta.brand,
                delta: e.deltaIngresos, invert: false, sub: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Gastos del mes", "Expenses this month"), e.gastosMes, Paleta.negativo,
                delta: e.deltaGastos, invert: true, sub: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Balance neto", "Net balance"), e.balanceNeto, Paleta.brand,
                delta: e.deltaBalance, invert: false, sub: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Mes anterior", "Previous month"), e.mesAnterior, Paleta.morado,
                delta: nil, invert: false, sub: e.mesAnteriorNombre)
    }

    private func chipKPI(_ titulo: String, _ monto: Centavos, _ color: Color, delta: Double?, invert: Bool, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            AmountText(cents: monto, size: 22)
            if let delta { DeltaBadge(pct: delta, sufijo: sub, invert: invert).font(.caption) }
            else { Text(sub).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 3).padding(.horizontal, 12) }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(.separator), lineWidth: 0.75))
    }

    // MARK: - Tarjetas

    private func tarjetas(_ e: EstadoFinanciero) -> some View {
        // Rejilla adaptable: cada tarjeta mínimo 260pt de ancho → 3 en 12.9",
        // 2 o 1 en 11". Evita que la dona y su leyenda queden aplastadas.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
            tarjetaSaldo(e)
            CategoryDonutChart(categorias: e.composicion, mesCorto: e.composicionMesCorto)
            tarjetaPresupuesto(e)
        }
    }

    private func tarjetaSaldo(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 8) {
                TituloSeccion(texto: L.t("SALDO DEL PERIODO", "PERIOD BALANCE"))
                AmountText(cents: e.saldoPeriodo, size: 26)
                Chart(e.saldoSerie) { m in
                    BarMark(x: .value("Mes", m.mes), y: .value("Saldo", m.monto))
                        .foregroundStyle(m.mes == e.saldoSerie.last?.mes ? Paleta.brand : Paleta.brandMuted)
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden).frame(height: 70)
            }
        }
    }

    private func tarjetaPresupuesto(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("GASTO CONTRA PRESUPUESTO", "SPEND VS BUDGET"))
                AmountText(cents: e.gastoTotal, size: 26)
                ForEach(e.presupuesto) { p in
                    HStack {
                        Text(p.categoria).font(.subheadline)
                        Spacer()
                        Text("\(p.pct)%").font(.subheadline.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Tabla mensual

    private func tablaMensual(_ e: EstadoFinanciero) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TituloSeccion(texto: L.t("RESUMEN MENSUAL", "MONTHLY SUMMARY"))
            Tarjeta {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text(L.t("MES", "MONTH")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(L.t("INGRESOS", "INCOME")).frame(width: 92, alignment: .trailing)
                        Text(L.t("GASTOS", "EXPENSES")).frame(width: 92, alignment: .trailing)
                        Text(L.t("BALANCE", "BALANCE")).frame(width: 92, alignment: .trailing)
                        Text("").frame(width: 52, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    Divider()
                    ForEach(e.mensual) { f in
                        let esUltimo = f.id == e.mensual.last?.id
                        HStack(spacing: 6) {
                            Text(f.mes).fontWeight(esUltimo ? .semibold : .regular)
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Money.fmt(f.ingresos)).foregroundStyle(Paleta.brand).frame(width: 92, alignment: .trailing)
                            Text(Money.fmt(f.gastos)).foregroundStyle(Paleta.negativo).frame(width: 92, alignment: .trailing)
                            Text(Money.fmt(f.balance)).fontWeight(.semibold).frame(width: 92, alignment: .trailing)
                            Group { if let d = f.delta { DeltaBadge(pct: d) } else { Text("") } }
                                .frame(width: 52, alignment: .trailing)
                        }
                        .font(.subheadline).monospacedDigit()
                        .padding(.vertical, 9)
                        .background(esUltimo ? Paleta.brandFill : .clear)
                        if !esUltimo { Divider() }
                    }
                }
            }
        }
    }
}
