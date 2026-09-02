import Foundation

protocol ReportesRepository {
    func tipos() -> [ReporteTipo]
    /// Periodos disponibles, del más reciente al más antiguo ("Agosto 2026" …).
    func periodos() -> [String]
    /// Categorías de ingreso para filtrar (sin incluir "Todas").
    func categorias() -> [String]
    /// Estado financiero de un periodo, opcionalmente acotado a una categoría.
    /// `categoria == nil` significa "Todas las categorías".
    func estadoFinanciero(periodo: String, categoria: String?) async -> EstadoFinanciero
}

/// Datos falsos que reproducen el reporte "Estado financiero" del handoff.
/// Los filtros derivan las cifras del mes elegido y acotan la dona por categoría,
/// para que los botones hagan algo real hoy; mañana el motor rellena lo mismo.
struct MockReportesRepository: ReportesRepository {
    func tipos() -> [ReporteTipo] {
        [
            ReporteTipo(id: "estado", titulo: L.t("Estado financiero", "Financial statement"),
                        subtitulo: L.t("Ingresos, gastos y saldo", "Income, expenses & balance")),
            ReporteTipo(id: "categoria", titulo: L.t("Ingresos por categoría", "Income by category"),
                        subtitulo: L.t("Desglose con gráfica", "Breakdown with chart")),
            ReporteTipo(id: "aportantes", titulo: L.t("Aportantes", "Givers"),
                        subtitulo: L.t("Por miembro, con totales", "Per member, with totals")),
            ReporteTipo(id: "depositos", titulo: L.t("Depósitos del periodo", "Period deposits"),
                        subtitulo: L.t("Conciliación bancaria", "Bank reconciliation")),
            ReporteTipo(id: "anual", titulo: L.t("Reporte anual", "Annual report"),
                        subtitulo: L.t("Los doce meses en una hoja", "All twelve months on one page")),
        ]
    }

    func periodos() -> [String] { base.mensual.map(\.mes).reversed() }

    func categorias() -> [String] { base.composicion.map(\.nombre) }

    func estadoFinanciero(periodo: String, categoria: String?) async -> EstadoFinanciero {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return derivar(periodo: periodo, categoria: categoria)
    }

    // MARK: - Derivación

    /// Reconstruye el estado para el mes pedido a partir de la tabla mensual
    /// (cifras reales por mes) y, si hay categoría, acota la dona e ingresos.
    private func derivar(periodo: String, categoria: String?) -> EstadoFinanciero {
        guard let i = base.mensual.firstIndex(where: { $0.mes == periodo }) else { return base }
        let fila = base.mensual[i]
        let previa = i > 0 ? base.mensual[i - 1] : nil

        func delta(_ actual: Centavos, _ anterior: Centavos?) -> Double? {
            guard let anterior, anterior != 0 else { return nil }
            return Double(actual - anterior) / Double(anterior)
        }

        // Composición del mes: escala la base al ingreso del mes elegido.
        let baseIngresos = base.mensual.last?.ingresos ?? fila.ingresos
        let factor = baseIngresos > 0 ? Double(fila.ingresos) / Double(baseIngresos) : 1
        var composicion = base.composicion.map {
            CategoriaMonto(nombre: $0.nombre, monto: Centavos((Double($0.monto) * factor).rounded()))
        }

        var ingresosMes = fila.ingresos
        // Filtro por categoría: la dona y el ingreso se acotan a esa categoría.
        if let categoria { composicion = composicion.filter { $0.nombre == categoria } }
        if categoria != nil { ingresosMes = composicion.reduce(0) { $0 + $1.monto } }
        let balanceNeto = ingresosMes - fila.gastos

        return EstadoFinanciero(
            periodo: periodo,
            ingresosMes: ingresosMes,
            gastosMes: fila.gastos,
            balanceNeto: balanceNeto,
            mesAnterior: previa?.balance ?? 0,
            mesAnteriorNombre: previa?.mes ?? "—",
            deltaIngresos: delta(ingresosMes, previa?.ingresos),
            deltaGastos: delta(fila.gastos, previa?.gastos),
            deltaBalance: delta(balanceNeto, previa?.balance),
            saldoPeriodo: balanceNeto,
            saldoSerie: base.saldoSerie,
            composicion: composicion,
            composicionMesCorto: String(periodo.split(separator: " ").first ?? "").lowercased(),
            gastoTotal: fila.gastos,
            presupuesto: base.presupuesto,
            mensual: base.mensual
        )
    }

    /// Dataset completo (agosto 2026), del que se derivan los demás periodos.
    private var base: EstadoFinanciero {
        EstadoFinanciero(
            periodo: L.t("Agosto 2026", "August 2026"),
            ingresosMes: 48_320_00, gastosMes: 21_145_50, balanceNeto: 27_174_50,
            mesAnterior: 26_690_00, mesAnteriorNombre: L.t("Julio 2026", "July 2026"),
            deltaIngresos: 0.042, deltaGastos: 0.11, deltaBalance: 0.018,
            saldoPeriodo: 27_174_50,
            saldoSerie: [
                MesAporte(mes: "Mar", monto: 23_540_00), MesAporte(mes: "Abr", monto: 24_205_00),
                MesAporte(mes: "May", monto: 17_780_00), MesAporte(mes: "Jun", monto: 29_820_00),
                MesAporte(mes: "Jul", monto: 26_690_00), MesAporte(mes: "Ago", monto: 27_174_50),
            ],
            composicion: [
                CategoriaMonto(nombre: L.t("Diezmos", "Tithes"), monto: 25_120_00),
                CategoriaMonto(nombre: L.t("Ofrendas", "Offerings"), monto: 10_630_00),
                CategoriaMonto(nombre: L.t("Misiones", "Missions"), monto: 7_250_00),
                CategoriaMonto(nombre: L.t("Eventos", "Events"), monto: 5_320_00),
            ],
            composicionMesCorto: L.t("agosto", "August"),
            gastoTotal: 21_145_50,
            presupuesto: [
                GastoPresupuesto(categoria: L.t("Servicios", "Utilities"), pct: 30),
                GastoPresupuesto(categoria: L.t("Mantenimiento", "Maintenance"), pct: 24),
                GastoPresupuesto(categoria: L.t("Misiones", "Missions"), pct: 18),
                GastoPresupuesto(categoria: L.t("Materiales", "Supplies"), pct: 15),
            ],
            mensual: [
                FilaMensual(mes: L.t("Marzo 2026", "March 2026"), ingresos: 39_780_00, gastos: 16_240_00, balance: 23_540_00, delta: nil),
                FilaMensual(mes: L.t("Abril 2026", "April 2026"), ingresos: 43_110_00, gastos: 18_905_00, balance: 24_205_00, delta: 0.028),
                FilaMensual(mes: L.t("Mayo 2026", "May 2026"), ingresos: 40_260_00, gastos: 22_480_00, balance: 17_780_00, delta: -0.265),
                FilaMensual(mes: L.t("Junio 2026", "June 2026"), ingresos: 46_940_00, gastos: 17_120_00, balance: 29_820_00, delta: 0.677),
                FilaMensual(mes: L.t("Julio 2026", "July 2026"), ingresos: 45_730_00, gastos: 19_040_00, balance: 26_690_00, delta: -0.105),
                FilaMensual(mes: L.t("Agosto 2026", "August 2026"), ingresos: 48_320_00, gastos: 21_145_50, balance: 27_174_50, delta: 0.018),
            ]
        )
    }
}
