import Foundation

/// Un tipo de reporte de la lista.
struct ReporteTipo: Identifiable, Hashable {
    let id: String
    let titulo: String
    let subtitulo: String
}

/// Una fila del resumen mensual (tabla).
struct FilaMensual: Identifiable {
    var id: String { mes }
    let mes: String
    let ingresos: Centavos
    let gastos: Centavos
    let balance: Centavos
    let delta: Double?   // variación del balance vs. mes anterior
}

/// Una categoría contra su porcentaje (gasto vs. presupuesto).
struct GastoPresupuesto: Identifiable {
    var id: String { categoria }
    let categoria: String
    let pct: Int
}

/// Los datos del reporte "Estado financiero".
struct EstadoFinanciero {
    let periodo: String            // "Agosto 2026"
    let ingresosMes: Centavos
    let gastosMes: Centavos
    let balanceNeto: Centavos
    let mesAnterior: Centavos
    let mesAnteriorNombre: String  // "Julio 2026"
    let deltaIngresos: Double?
    let deltaGastos: Double?
    let deltaBalance: Double?

    let saldoPeriodo: Centavos
    let saldoSerie: [MesAporte]        // mini gráfica

    let composicion: [CategoriaMonto]  // dona de ingresos
    let composicionMesCorto: String

    let gastoTotal: Centavos
    let presupuesto: [GastoPresupuesto]

    let mensual: [FilaMensual]
}
