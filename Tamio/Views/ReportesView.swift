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
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna.frame(width: Esp.columnaMaestra).background(.regularMaterial)
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
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaColumnaCore
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var listaColumnaCore: some View {
        List {
            Section {
                ForEach(vm.tipos) { t in
                    filaReporte(t)
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
        return VStack(alignment: .leading, spacing: 2) {
            Text(t.titulo).font(.subheadline.weight(.semibold)).foregroundStyle(sel ? Paleta.brand : .primary)
            Text(t.subtitulo).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .filaDeLista(seleccionada: sel, tarjeta: sizeClass != .regular)
    }

    // MARK: - Vista previa

    @ViewBuilder
    private var preview: some View {
        if vm.sinDatos {
            // No es que el reporte esté vacío: es que no hay movimientos
            // aprobados con los que hacerlo.
            ContentUnavailableView(
                L.t("Todavía no hay nada que reportar", "Nothing to report yet"),
                systemImage: "chart.bar.doc.horizontal",
                description: Text(L.t("Los reportes salen de los movimientos aprobados. Captura ingresos y gastos, o dales el visto bueno en Por revisar.",
                                      "Reports are built from approved transactions. Record income and expenses, or approve them in To review.")))
        } else if vm.seleccionId == "estado", let e = vm.estado {
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
                if e.pendientes > 0 { avisoPendientes(e) }
                tarjetas(e)
                tablaMensual(e)
            }
            .padding(Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $mostrarPDF) { ReportePDFSheet(e: e) }
    }

    /// **Lo que el reporte deja fuera, dicho en el reporte.** Solo cuentan los
    /// movimientos aprobados; sin este aviso, la diferencia contra la pantalla
    /// de Ingresos —que sí enseña los pendientes— parece un error de la app.
    private func avisoPendientes(_ e: EstadoFinanciero) -> some View {
        HStack(spacing: Esp.hueco) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Paleta.Estado.pendiente.color)
            Text(e.pendientes == 1
                 ? L.t("1 movimiento de este mes espera visto bueno y no está en estas cifras.",
                       "1 transaction this month is awaiting approval and isn't in these figures.")
                 : L.t("\(e.pendientes) movimientos de este mes esperan visto bueno y no están en estas cifras.",
                       "\(e.pendientes) transactions this month are awaiting approval and aren't in these figures."))
                .font(.footnote)
            Spacer()
        }
        .padding(Esp.chip)
        .background(Paleta.avisoFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func barraFiltros(_ e: EstadoFinanciero) -> some View {
        HStack(spacing: 10) {
            // Periodo: elige el mes; recarga las cifras de ese mes.
            Menu {
                ForEach(vm.periodos) { p in
                    Button { Task { await vm.seleccionarPeriodo(p.clave) } } label: {
                        if p.clave == vm.periodoSel { Label(p.etiqueta, systemImage: "checkmark") }
                        else { Text(p.etiqueta) }
                    }
                }
            } label: { chipFiltro(vm.periodoEtiqueta) }

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
            .tint(Color.secondary)
            Button { mostrarPDF = true } label: {
                Label(L.t("Vista previa PDF", "PDF preview"), systemImage: "doc.text").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent).tint(Paleta.brand)
        }
    }

    private func chipFiltro(_ t: String) -> some View {
        HStack(spacing: 4) { Text(t); Image(systemName: "chevron.down").font(.caption2) }
            .font(.subheadline).foregroundStyle(.primary)
            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }

    // MARK: - Chips KPI

    private func chips(_ e: EstadoFinanciero) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { chipsLista(e) }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { chipsLista(e) }
        }
    }

    /// **El cuarto chip es el saldo final, no el balance del mes pasado.** Era
    /// "Mes anterior", que repetía una cifra que la tabla ya da y dejaba fuera
    /// la única que responde "¿cuánto tiene la iglesia?".
    @ViewBuilder
    private func chipsLista(_ e: EstadoFinanciero) -> some View {
        chipKPI(L.t("Ingresos del mes", "Income this month"), e.ingresosMes, Paleta.brand,
                delta: e.deltaIngresos, invert: false, sub: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Gastos del mes", "Expenses this month"), e.gastosMes, Paleta.negativo,
                delta: e.deltaGastos, invert: true, sub: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Balance neto", "Net balance"), e.balanceNeto, Paleta.brand,
                delta: e.deltaBalance, invert: false, sub: L.t("vs mes anterior", "vs last month"))
        chipKPI(L.t("Saldo final", "Ending balance"), e.saldoFinal, Paleta.morado,
                delta: nil, invert: false,
                sub: L.t("con el saldo anterior", "including previous balance"))
    }

    private func chipKPI(_ titulo: String, _ monto: Centavos, _ color: Color, delta: Double?, invert: Bool, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            AmountText(cents: monto, size: 22)
            if let delta { DeltaBadge(pct: delta, sufijo: sub, invert: invert).font(.caption) }
            else { Text(sub).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.tarjeta)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 3).padding(.horizontal, Esp.chip) }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(.separator), lineWidth: 0.75))
    }

    // MARK: - Tarjetas

    private func tarjetas(_ e: EstadoFinanciero) -> some View {
        // Rejilla adaptable: cada tarjeta mínimo 260pt de ancho → 3 en 12.9",
        // 2 o 1 en 11". Evita que la dona y su leyenda queden aplastadas.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
            tarjetaSaldo(e)
            CategoryDonutChart(categorias: e.composicion, mesCorto: e.composicionMesCorto)
            tarjetaGastos(e)
            if !e.depositos.isEmpty { tarjetaDepositos(e) }
        }
    }

    private func tarjetaSaldo(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 8) {
                TituloSeccion(texto: L.t("SALDO DEL PERIODO", "PERIOD BALANCE"))
                AmountText(cents: e.balanceNeto, size: 26)
                Chart(e.saldoSerie) { m in
                    BarMark(x: .value("Mes", m.mes), y: .value("Saldo", m.monto))
                        .foregroundStyle(m.mes == e.saldoSerie.last?.mes ? Paleta.brand : Paleta.brandMuted)
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden).frame(height: 70)
            }
        }
    }

    /// **Gastos por categoría, con el porcentaje medido contra el INGRESO.**
    /// Sustituye a "gasto contra presupuesto", que enseñaba cuatro porcentajes
    /// fijos de un presupuesto que en Tamio no existe. El % contra el ingreso
    /// es el de la app web, y es el que informa: "mantenimiento fue el 12% de
    /// lo que entró" dice algo; "% de lo que gastamos" no dice nada nuevo.
    private func tarjetaGastos(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("GASTOS POR CATEGORÍA", "EXPENSES BY CATEGORY"))
                AmountText(cents: e.gastoTotal, size: 26)
                if e.gastosPorCategoria.isEmpty {
                    Text(L.t("Sin gastos en el periodo", "No expenses this period"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(e.gastosPorCategoria) { g in
                    HStack {
                        Text(g.nombre).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(Money.fmt(g.monto)).font(.subheadline).monospacedDigit()
                        Text(porcentaje(g.monto, de: e.ingresosMes))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// Los depósitos del periodo. Van con su aclaración: son traspasos de caja
    /// a banco, no ingresos, así que su total puede superar lo ingresado en el
    /// mes sin que eso sea un descuadre.
    private func tarjetaDepositos(_ e: EstadoFinanciero) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                TituloSeccion(texto: L.t("DEPÓSITOS DEL PERIODO", "PERIOD DEPOSITS"))
                AmountText(cents: e.depositosTotal, size: 26)
                ForEach(e.depositos) { d in
                    HStack {
                        Text(d.cuenta).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(Money.fmt(d.monto)).font(.subheadline).monospacedDigit()
                    }
                }
                Text(L.t("No suman al saldo: mueven efectivo de la caja al banco.",
                         "Not added to the balance: they move cash from the box to the bank."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func porcentaje(_ parte: Centavos, de total: Centavos) -> String {
        guard total > 0 else { return "—" }
        return "\(Int((Double(parte) / Double(total) * 100).rounded()))%"
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
                        // El mes destacado es el que se está viendo, no el
                        // último de la tabla: con el filtro puesto en junio, la
                        // fila resaltada tiene que ser junio.
                        let esActual = f.clave == e.periodo.clave
                        HStack(spacing: 6) {
                            Text(f.mes).fontWeight(esActual ? .semibold : .regular)
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
                        .background(esActual ? Paleta.brandFill : .clear)
                        if f.id != e.mensual.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
