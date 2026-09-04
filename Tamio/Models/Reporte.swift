import Foundation

/// Un tipo de reporte de la lista.
struct ReporteTipo: Identifiable, Hashable {
    let id: String
    let titulo: String
    let subtitulo: String
}

/// Un periodo contable elegible en el filtro. **La clave manda y la etiqueta
/// solo se lee**: comparar por el texto escrito rompía en inglés, y además el
/// menú y las filas de la tabla tenían que coincidir carácter a carácter.
struct PeriodoContable: Identifiable, Hashable {
    /// `"2026-08"`, la misma clave que `depositos_bancarios.periodo`.
    let clave: String
    var id: String { clave }
    var etiqueta: String { Fechas.periodoLegible(clave) }
}

/// Una fila del resumen mensual (tabla).
struct FilaMensual: Identifiable {
    /// `"2026-08"`. El id es la clave, no el mes escrito.
    let clave: String
    var id: String { clave }
    var mes: String { Fechas.periodoLegible(clave) }
    let ingresos: Centavos
    let gastos: Centavos
    var balance: Centavos { ingresos - gastos }
    /// Variación del balance contra el mes anterior. `nil` cuando no hay mes
    /// anterior con el que comparar, que no es lo mismo que un 0%.
    let delta: Double?
}

/// Los datos del reporte "Estado financiero" de un periodo.
///
/// **Todo lo que es una suma es una propiedad calculada.** Los totales venían
/// escritos en el repositorio —48.320,00, 21.145,50 y seis meses literales—
/// mientras Ingresos, Depósitos e Inicio contaban los mismos movimientos por
/// su cuenta: la misma pregunta tenía dos respuestas y la que se imprime y se
/// firma era la inventada.
struct EstadoFinanciero {
    let periodo: PeriodoContable

    let ingresosMes: Centavos
    let gastosMes: Centavos
    var balanceNeto: Centavos { ingresosMes - gastosMes }

    let deltaIngresos: Double?
    let deltaGastos: Double?
    let deltaBalance: Double?
    /// Balance del mes anterior y cómo se llama. `nil` si no hay mes anterior.
    let mesAnterior: Centavos?
    let mesAnteriorNombre: String?

    /// **Saldo de tesorería al cierre del periodo anterior**: el saldo de
    /// apertura de Ajustes más todo lo aprobado antes de este mes. Es lo que
    /// convierte el reporte en una ecuación contable en vez de en el resultado
    /// suelto de un mes, y es el único sitio donde el saldo de apertura entra
    /// en una cifra. Misma definición que `saldoAnteriorDe` en la app web.
    let saldoAnterior: Centavos
    var saldoFinal: Centavos { saldoAnterior + ingresosMes - gastosMes }

    /// Los últimos meses del balance, para la mini gráfica.
    let saldoSerie: [MesAporte]

    /// Ingresos por categoría (la dona).
    let composicion: [CategoriaMonto]
    /// Gastos por categoría. **Sustituye a "gasto contra presupuesto"**, que
    /// enseñaba cuatro porcentajes fijos bajo un rótulo que en Tamio no existe:
    /// no hay tabla, ni columna, ni pantalla donde se capture un presupuesto,
    /// ni en iOS ni en la app web.
    let gastosPorCategoria: [CategoriaMonto]
    var gastoTotal: Centavos { gastosMes }

    /// Los depósitos bancarios del periodo. **No entran en el saldo**: son
    /// traspasos de caja a banco, no ingresos, y pueden superar lo ingresado
    /// en el mes porque arrastran efectivo de meses anteriores.
    let depositos: [DepositoBancario]
    var depositosTotal: Centavos { depositos.reduce(0) { $0 + $1.monto } }

    /// Cuántos movimientos del periodo esperan visto bueno y por eso **no**
    /// están en estas cifras. Un reporte que se firma tiene que decir qué dejó
    /// fuera; si no, la diferencia con la pantalla de Ingresos parece un error.
    let pendientes: Int

    let mensual: [FilaMensual]

    /// Etiqueta corta del centro de la dona ("agosto" · "august").
    var composicionMesCorto: String {
        guard let d = Fechas.fechaDePeriodo(periodo.clave) else { return periodo.etiqueta }
        return L.formateador("LLLL").string(from: d).lowercased()
    }
}
