import Charts
import SwiftUI

/// El Dashboard, fiel al handoff del iPad y adaptativo. En regular (iPad):
/// saludo grande + segmentado, fila de cuatro KPI, gráficas a dos columnas y
/// las listas "Últimos movimientos" / "Esta semana". En compacto (iPhone) una
/// sola columna ajustada al handoff del teléfono.
struct DashboardView: View {
    @State private var vm = DashboardViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// En iPad los enlaces de las tarjetas mueven la selección de la sidebar;
    /// en iPhone empujan la vista en el stack de la pestaña. Opcional para que
    /// la preview de una tarjeta suelta no necesite el entorno completo.
    @Environment(Navegacion.self) private var nav: Navegacion?
    private var esIPad: Bool { sizeClass == .regular }

    /// El "+ Nuevo" del Inicio crea un movimiento igual que en Ingresos, vía el
    /// mismo repositorio, así aparece también allí. Antes era el mock: lo que
    /// se capturaba desde Inicio no llegaba a Supabase ni salía en Ingresos, y
    /// el `try?` del guardado se comía el error, así que parecía guardado.
    private let movimientosRepo: MovimientosRepository = repositorioMovimientos()
    @State private var mostrarNuevo = false
    @State private var folioNuevo = ""
    @State private var errorGuardado: String?

    var body: some View {
        scrollContent
            .toolbar { barra }
            // El `+` baja a la barra inferior del teléfono, como en los dos
            // pilotos: arriba se queda el segmentado, que es lo que dice qué se
            // está viendo. En iPad no aplica.
            .safeAreaInset(edge: .bottom) { barraInferior }
            .sheet(isPresented: $mostrarNuevo) {
                NuevoMovimientoView(tipo: .ingreso, folio: folioNuevo, existente: nil) { m in
                    Task { await guardar(m) }
                }
            }
            .alert(L.t("No se pudo guardar", "Couldn't save"),
                   isPresented: Binding(get: { errorGuardado != nil },
                                        set: { if !$0 { errorGuardado = nil } })) {
                Button(L.t("Entendido", "OK"), role: .cancel) { errorGuardado = nil }
            } message: {
                Text(errorGuardado ?? "")
            }
            .task { await vm.cargar() }
    }

    /// **El segmentado ocupa el lugar del título.** "Inicio" es lo mismo que ya
    /// dice la pestaña en la que estás, y el saludo hace de H1; el periodo, en
    /// cambio, gobierna todas las cifras de la pantalla y no se veía en la
    /// barra. En iPad el segmentado se queda en la columna, donde cabe al lado
    /// del saludo y donde la barra es de la pantalla entera.
    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        if esIPad {
            ToolbarItem(placement: .topBarTrailing) { botonNuevo }
        } else {
            ToolbarItem(placement: .title) {
                segmentado.frame(maxWidth: 240)
            }
        }
    }

    @ViewBuilder
    private var barraInferior: some View {
        if !esIPad, let d = vm.data {
            BarraInferior { botonNuevo } resumen: {
                // El saldo en caja encabeza la pantalla, pero se pierde al
                // primer desplazamiento: es el dato que el tesorero compara, y
                // en la cápsula sigue a la vista todo el rato.
                HStack(spacing: 6) {
                    Text(L.t("Caja", "Cash")).foregroundStyle(.secondary)
                    Text(Money.fmt(d.saldoCaja)).fontWeight(.semibold)
                }
                .font(.footnote).monospacedDigit()
            }
        }
    }

    private var botonNuevo: some View {
        Button {
            Task {
                folioNuevo = await movimientosRepo.siguienteFolio(tipo: .ingreso)
                mostrarNuevo = true
            }
        } label: {
            Label(L.t("Nuevo", "New"), systemImage: "plus")
        }
        .buttonStyle(.glass)
        .tint(Paleta.brand)
    }

    /// Guarda y recarga los indicadores. Un fallo se avisa: dar por guardado
    /// un movimiento que no se guardó es el peor final posible para esta hoja.
    @MainActor
    private func guardar(_ m: Movimiento) async {
        do {
            try await movimientosRepo.crear(m)
            await vm.cargar()
        } catch {
            errorGuardado = error.localizedDescription
        }
    }

    // MARK: - Nav + scroll

    /// iPad usa encabezadoNav (subtítulo + fondo verde). iPhone solo navigationTitle.
    @ViewBuilder
    private var scrollContent: some View {
        if esIPad {
            ScrollView { innerContent }
            .colchonInferior()
                .background(Color(.systemGroupedBackground))
                .encabezadoNav(L.t("Inicio", "Home"), vm.periodoLegible)
                .navigationBarTitleDisplayMode(.inline)
                .scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            ScrollView { innerContent }
                .background(Color(.systemGroupedBackground))
                // El título se lo queda el segmentado; borrarlo con
                // `toolbar(removing:)` se llevaría también el item puesto ahí.
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .scrollEdgeEffectStyle(.soft, for: .all)
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
            // La tira de controles entre el saludo y las tarjetas desaparece:
            // el segmentado subió a la barra.
            saludoView
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
            // El MISMO pie que Gastos. Leídas una al lado de la otra, una con
            // conteo y otra con variación contaban cosas distintas, y la de
            // Ingresos sin variación se entendía como que no se había movido.
            pieMovimientos(d.registrosIngreso, d.deltaIngresos)
        }
    }

    private func kpiGastos(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Gastos del periodo", "Period expenses")) {
            AmountText(cents: d.gastos, size: 24)
        } pie: {
            pieMovimientos(d.registrosGasto, d.deltaGastos, invert: true)
        }
    }

    /// Cuántos movimientos y cómo varía, en una línea. La variación desaparece
    /// sola cuando no hay periodo anterior con el que comparar.
    private func pieMovimientos(_ registros: Int, _ delta: Double?,
                                invert: Bool = false) -> some View {
        // Sin el sufijo "vs agosto": en el iPhone la tarjeta mide media
        // pantalla y con el conteo delante la línea se truncaba a "▲106.4% vs
        // A…". El periodo con el que se compara ya lo dice el segmentado
        // Mes|Trimestre|Año que hay justo encima.
        HStack(spacing: 6) {
            Text(L.t("\(registros) registros", "\(registros) records"))
                .foregroundStyle(.secondary)
            DeltaBadge(pct: delta, invert: invert)
        }
    }

    /// La tarjeta entera es el botón: el pie decía "Abrir bandeja →" en color de
    /// enlace pero era texto plano, así que prometía algo que no ocurría.
    private func kpiPorRevisar(_ d: DashboardData) -> some View {
        Button {
            nav?.seccion = "porRevisar"
        } label: {
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
        .buttonStyle(.plain)
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
        .padding(Esp.tarjeta)
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
            pieMovimientos(d.registrosIngreso, d.deltaIngresos)
        }
    }

    private func kpiGastosCompacto(_ d: DashboardData) -> some View {
        KPICard(titulo: L.t("Gastos", "Expenses")) {
            AmountText(cents: d.gastos, size: 22)
        } pie: {
            pieMovimientos(d.registrosGasto, d.deltaGastos, invert: true)
        }
    }

    /// Fila naranja de advertencia que navega a la bandeja "Por revisar".
    private func porRevisarBanner(_ d: DashboardData) -> some View {
        NavigationLink { RevisarView().sinBotonVolver() } label: {
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
            .padding(Esp.tarjeta)
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
            .padding(.horizontal, Esp.tarjeta)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75))
        }
    }

    /// Aspecto del enlace de cabecera de las tarjetas de lista. El estilo es
    /// común; lo que cambia es el control que lo envuelve en cada plataforma.
    ///
    /// El relleno y el `contentShape` no son decorativos: una línea de texto
    /// mide unos 20pt de alto, la mitad del objetivo de toque de 44pt que pide
    /// Apple. Sin esto hay que acertarle justo a la palabra, y con el dedo
    /// parece que el enlace no responde.
    private func textoEnlace(_ titulo: String) -> some View {
        Text(titulo)
            .font(.subheadline)
            .foregroundStyle(Paleta.enlace)
            .padding(.vertical, 12)
            .padding(.leading, 16)
            .contentShape(Rectangle())
    }

    // MARK: - iPhone lists (títulos en .headline, no ALL CAPS)

    private func listaMovimientosIPhone(_ d: DashboardData) -> some View {
        tarjetaListaIPhone(titulo: L.t("Últimos movimientos", "Recent activity")) {
            NavigationLink { MovimientosView(tipo: .ingreso).sinBotonVolver() } label: {
                textoEnlace(L.t("Ver todos", "See all"))
            }
            .buttonStyle(.plain)
        } contenido: {
            ForEach(Array(d.recientes.enumerated()), id: \.element.id) { i, tx in
                TransactionRow(tx: tx)
                if i < d.recientes.count - 1 { Divider() }
            }
        }
    }

    private func listaSemanaIPhone(_ d: DashboardData) -> some View {
        tarjetaListaIPhone(titulo: L.t("Esta semana", "This week")) {
            NavigationLink { AgendaView().sinBotonVolver() } label: {
                textoEnlace(L.t("Agenda", "Calendar"))
            }
            .buttonStyle(.plain)
        } contenido: {
            ForEach(Array(d.semana.enumerated()), id: \.element.id) { i, item in
                AgendaRow(item: item)
                if i < d.semana.count - 1 { Divider() }
            }
        }
    }

    private func tarjetaListaIPhone<E: View, C: View>(
        titulo: String,
        @ViewBuilder enlace: () -> E,
        @ViewBuilder contenido: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo)
                    .font(.headline.weight(.semibold))
                Spacer()
                enlace()
            }
            .padding(.vertical, -6)
            VStack(spacing: 0) { contenido() }
                .padding(.horizontal, Esp.tarjeta)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.75))
        }
    }

    // MARK: - iPad lists (mantienen ALL CAPS según handoff iPad)

    private func listaMovimientos(_ d: DashboardData) -> some View {
        tarjetaLista(titulo: L.t("ÚLTIMOS MOVIMIENTOS", "RECENT ACTIVITY")) {
            Button { nav?.seccion = "ingresos" } label: {
                textoEnlace(L.t("Ver todos", "See all"))
            }
            .buttonStyle(.plain)
        } contenido: {
            ForEach(Array(d.recientes.enumerated()), id: \.element.id) { i, tx in
                TransactionRow(tx: tx)
                if i < d.recientes.count - 1 { Divider() }
            }
        }
    }

    private func listaSemana(_ d: DashboardData) -> some View {
        tarjetaLista(titulo: L.t("ESTA SEMANA", "THIS WEEK")) {
            Button { nav?.seccion = "agenda" } label: {
                textoEnlace(L.t("Agenda", "Calendar"))
            }
            .buttonStyle(.plain)
        } contenido: {
            ForEach(Array(d.semana.enumerated()), id: \.element.id) { i, item in
                AgendaRow(item: item)
                if i < d.semana.count - 1 { Divider() }
            }
        }
    }

    private func tarjetaLista<E: View, Contenido: View>(
        titulo: String,
        @ViewBuilder enlace: () -> E,
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(titulo)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                enlace()
            }
            VStack(spacing: 0) { contenido() }
                .padding(.horizontal, Esp.tarjeta)
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
        f.locale = L.locale
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
        f.locale = L.locale
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
