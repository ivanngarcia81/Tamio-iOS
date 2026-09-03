import Charts
import SwiftUI

/// El Dashboard, fiel al handoff del iPad y adaptativo. En regular (iPad):
/// saludo grande + segmentado, fila de cuatro KPI, gráficas a dos columnas y
/// las listas "Últimos movimientos" / "Esta semana". En compacto (iPhone) una
/// sola columna ajustada al handoff del teléfono.
struct DashboardView: View {
    @State private var vm = DashboardViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var esIPad: Bool { sizeClass == .regular }

    /// El "+ Nuevo" del Inicio crea un movimiento igual que en Ingresos, vía el
    /// mismo repositorio (mock hoy, GRDB mañana), así aparece también allí.
    private let movimientosRepo: MovimientosRepository = MockMovimientosRepository()
    @State private var mostrarNuevo = false
    @State private var folioNuevo = ""

    var body: some View {
        scrollContent
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { folioNuevo = await movimientosRepo.siguienteFolio(); mostrarNuevo = true }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                            Text(L.t("Nuevo", "New"))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                    }
                }
            }
            .sheet(isPresented: $mostrarNuevo) {
                NuevoMovimientoView(tipo: .ingreso, folio: folioNuevo, existente: nil) { m in
                    Task { try? await movimientosRepo.crear(m) }
                }
            }
            .task { await vm.cargar() }
    }

    // MARK: - Nav + scroll

    /// iPad usa encabezadoNav (subtítulo + fondo verde). iPhone solo navigationTitle.
    @ViewBuilder
    private var scrollContent: some View {
        if esIPad {
            ScrollView { innerContent }
                .background(Color(.systemGroupedBackground))
                .encabezadoNav(L.t("Inicio", "Home"), vm.periodoLegible)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            ScrollView { innerContent }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(L.t("Inicio", "Home"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var innerContent: some View {
        if let data = vm.data {
            VStack(alignment: .leading, spacing: 20) {
                encabezado(data)
                if esIPad { contenidoIPad(data) } else { contenidoIPhone(data) }
            }
            .padding(esIPad ? 24 : 16)
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 400)
        }
    }

    // MARK: - Encabezado (saludo + segmentado)

    @ViewBuilder
    private func encabezado(_ data: DashboardData) -> some View {
        let saludoView = VStack(alignment: .leading, spacing: 4) {
            Text(saludo(data))
                .font(esIPad ? .largeTitle.weight(.bold) : .title.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(fechaCorte(data.corteDias))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        if esIPad {
            HStack(alignment: .top) {
                saludoView
                Spacer(minLength: 16)
                segmentado.frame(width: 240).padding(.top, 6)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                saludoView
                segmentado
            }
        }
    }

    private var segmentado: some View {
        Picker(L.t("Periodo", "Period"), selection: $vm.periodo) {
            ForEach(Periodo.allCases) { Text($0.etiqueta).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - iPad

    @ViewBuilder
    private func contenidoIPad(_ data: DashboardData) -> some View {
        HStack(alignment: .top, spacing: 16) {
            kpiSaldo(data); kpiIngresos(data); kpiGastos(data); kpiPorRevisar(data)
        }

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                MonthlyBarChart(tramos: data.tramos)
                CategoryDonutChart(categorias: data.ingresosPorCategoria, mesCorto: mesCorto)
            }
            VStack(spacing: 16) {
                MonthlyBarChart(tramos: data.tramos)
                CategoryDonutChart(categorias: data.ingresosPorCategoria, mesCorto: mesCorto)
            }
        }

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                listaMovimientos(data)
                listaSemana(data)
            }
            VStack(spacing: 16) {
                listaMovimientos(data)
                listaSemana(data)
            }
        }
    }

    // MARK: - iPhone

    @ViewBuilder
    private func contenidoIPhone(_ data: DashboardData) -> some View {
        VStack(spacing: 16) {
            kpiSaldoConBarras(data)
            HStack(spacing: 12) {
                kpiIngresosCompacto(data)
                kpiGastosCompacto(data)
            }
            porRevisarBanner(data)
            categoriasBarras(data)
            listaMovimientosIPhone(data)
            listaSemanaIPhone(data)
        }
    }

    // MARK: - Tarjetas KPI (iPad)

    private func kpiSaldo(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Saldo en caja", "Cash on hand")) {
            AmountText(cents: d.saldoCaja, size: 24)
        } pie: {
            DeltaBadge(pct: d.deltaSaldo, sufijo: vm.periodoAnteriorLegible)
        }
    }

    private func kpiIngresos(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Ingresos del periodo", "Period income")) {
            AmountText(cents: d.ingresos, size: 24)
        } pie: {
            Text(L.t("\(d.registrosIngreso) registros · \(d.diezmos) diezmos",
                     "\(d.registrosIngreso) records · \(d.diezmos) tithes"))
                .foregroundStyle(.secondary)
        }
    }

    private func kpiGastos(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Gastos del periodo", "Period expenses")) {
            AmountText(cents: d.gastos, size: 24)
        } pie: {
            DeltaBadge(pct: d.deltaGastos, sufijo: vm.periodoAnteriorLegible, invert: true)
        }
    }

    private func kpiPorRevisar(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Por revisar", "To review")) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(d.pendientes)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(L.t("movimientos", "items")).font(.subheadline).foregroundStyle(.secondary)
            }
        } pie: {
            Text(L.t("Abrir bandeja →", "Open tray →")).foregroundStyle(Paleta.enlace)
        }
    }

    // MARK: - iPhone KPI

    /// Tarjeta de saldo con mini gráfica de barras incrustada (handoff iPhone).
    private func kpiSaldoConBarras(_ d: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("SALDO EN CAJA", "CASH ON HAND"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            AmountText(cents: d.saldoCaja, size: 28)
            DeltaBadge(pct: d.deltaSaldo, sufijo: vm.periodoAnteriorLegible)
            TramosInlineChart(tramos: d.tramos)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color(.separator), lineWidth: 0.75))
    }

    private func kpiIngresosCompacto(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Ingresos", "Income")) {
            AmountText(cents: d.ingresos, size: 22)
        } pie: {
            Text("\(d.registrosIngreso) " + L.t("registros", "records"))
                .foregroundStyle(.secondary)
        }
    }

    private func kpiGastosCompacto(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Gastos", "Expenses")) {
            AmountText(cents: d.gastos, size: 22)
        } pie: {
            DeltaBadge(pct: d.deltaGastos, sufijo: vm.periodoAnteriorLegible, invert: true)
        }
    }

    /// Fila naranja de advertencia que navega a la bandeja "Por revisar".
    private func porRevisarBanner(_ d: DashboardData) -> some View {
        NavigationLink { RevisarView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Paleta.aviso)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Por revisar", "To review"))
                        .font(.subheadline.weight(.semibold))
                    Text(L.t("\(d.pendientes) movimientos pendientes",
                             "\(d.pendientes) items pending"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Paleta.avisoStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private let catColores: [Color] = [
        Paleta.brand,
        Paleta.morado,
        Paleta.cian,
        Paleta.aviso,
    ]

    /// Barras horizontales de colores por categoría (reemplaza la dona en iPhone).
    private func categoriasBarras(_ d: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L.t("Ingresos por categoría", "Income by category"))
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(montoCompacto(d.ingresos))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(d.ingresosPorCategoria.enumerated()), id: \.element.id) { i, cat in
                    CategoriaBarRow(cat: cat, total: d.ingresos,
                                    color: catColores[i % catColores.count])
                    if i < d.ingresosPorCategoria.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75))
        }
    }

    // MARK: - iPhone lists (títulos en .headline, no ALL CAPS)

    private func listaMovimientosIPhone(_ d: DashboardData) -> some View {
        tarjetaListaIPhone(
            titulo: L.t("Últimos movimientos", "Recent activity"),
            accion: L.t("Ver todos", "See all")
        ) {
            ForEach(Array(d.recientes.enumerated()), id: \.element.id) { i, tx in
                TransactionRow(tx: tx)
                if i < d.recientes.count - 1 { Divider() }
            }
        }
    }

    private func listaSemanaIPhone(_ d: DashboardData) -> some View {
        tarjetaListaIPhone(
            titulo: L.t("Esta semana", "This week"),
            accion: L.t("Agenda", "Calendar")
        ) {
            ForEach(Array(d.semana.enumerated()), id: \.element.id) { i, item in
                AgendaRow(item: item)
                if i < d.semana.count - 1 { Divider() }
            }
        }
    }

    private func tarjetaListaIPhone<C: View>(
        titulo: String, accion: String, @ViewBuilder contenido: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(accion).font(.subheadline).foregroundStyle(Paleta.enlace)
            }
            VStack(spacing: 0) { contenido() }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.75))
        }
    }

    // MARK: - iPad lists (mantienen ALL CAPS según handoff iPad)

    private func listaMovimientos(_ d: DashboardData) -> some View {
        tarjetaLista(
            titulo: L.t("ÚLTIMOS MOVIMIENTOS", "RECENT ACTIVITY"),
            accion: L.t("Ver todos", "See all")
        ) {
            ForEach(Array(d.recientes.enumerated()), id: \.element.id) { i, tx in
                TransactionRow(tx: tx)
                if i < d.recientes.count - 1 { Divider() }
            }
        }
    }

    private func listaSemana(_ d: DashboardData) -> some View {
        tarjetaLista(
            titulo: L.t("ESTA SEMANA", "THIS WEEK"),
            accion: L.t("Agenda", "Calendar")
        ) {
            ForEach(Array(d.semana.enumerated()), id: \.element.id) { i, item in
                AgendaRow(item: item)
                if i < d.semana.count - 1 { Divider() }
            }
        }
    }

    private func tarjetaLista<Contenido: View>(
        titulo: String, accion: String, @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(titulo)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(accion).font(.subheadline).foregroundStyle(Paleta.enlace)
            }
            VStack(spacing: 0) { contenido() }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.75))
        }
    }

    // MARK: - Textos

    private func montoCompacto(_ cents: Centavos) -> String {
        let valor = Double(Int(cents)) / 100.0
        if valor >= 1_000_000 { return String(format: "$%.1fM", valor / 1_000_000) }
        if valor >= 1_000 { return String(format: "$%.1fk", valor / 1_000) }
        return String(format: "$%.0f", valor)
    }

    private func saludo(_ d: DashboardData) -> String {
        let h = Calendar.current.component(.hour, from: Date())
        let base: String
        if h < 12 { base = L.t("Buenos días", "Good morning") }
        else if h < 19 { base = L.t("Buenas tardes", "Good afternoon") }
        else { base = L.t("Buenas noches", "Good evening") }
        if let nombre = d.church.tesoreroNombre?.split(separator: " ").first {
            return "\(base), \(nombre)"
        }
        return base
    }

    private func fechaCorte(_ dias: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = L.esEspanol ? "EEEE d 'de' MMMM" : "EEEE, MMMM d"
        let s = f.string(from: Date())
        let fecha = s.prefix(1).uppercased() + s.dropFirst()
        let corte = dias == 0
            ? L.t("el corte de mes es hoy", "month closes today")
            : L.t("el corte de mes cierra en \(dias) días", "month closes in \(dias) days")
        return "\(fecha) · \(corte)"
    }

    private var mesCorto: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMMM"
        return f.string(from: Date())
    }
}

// MARK: - Subvistas privadas iPhone

/// Mini gráfica de barras agrupadas (ingresos verde / gastos gris) para
/// incrustar dentro de la tarjeta de saldo del iPhone.
private struct TramosInlineChart: View {
    let tramos: [MesResumen]

    private struct Bar: Identifiable {
        let id: String
        let mes: String
        let tipo: String
        let monto: Int
    }

    private var bars: [Bar] {
        tramos.flatMap { t in
            [Bar(id: t.etiqueta + "I", mes: t.etiqueta, tipo: "I", monto: Int(t.ingresos)),
             Bar(id: t.etiqueta + "G", mes: t.etiqueta, tipo: "G", monto: Int(t.gastos))]
        }
    }

    var body: some View {
        Chart(bars) { b in
            BarMark(x: .value("", b.mes), y: .value("", b.monto))
                .position(by: .value("", b.tipo))
                .foregroundStyle(b.tipo == "I" ? Paleta.brand : Color(.systemGray5))
                .cornerRadius(2)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { v in
                AxisValueLabel {
                    if let s = v.as(String.self) {
                        Text(s).font(.system(size: 9))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 65)
    }
}

/// Fila de una categoría con barra horizontal proporcional y porcentaje.
private struct CategoriaBarRow: View {
    let cat: CategoriaMonto
    let total: Centavos
    let color: Color

    private var pct: Double {
        let t = Int(total)
        let m = Int(cat.monto)
        return t > 0 ? Double(m) / Double(t) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(cat.nombre)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int((pct * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(.systemFill))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color)
                        .frame(width: max(8, geo.size.width * pct), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 9)
    }
}

#Preview { RootView() }
