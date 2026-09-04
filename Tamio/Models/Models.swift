import Foundation

/// El periodo que gobierna el segmentado del Dashboard (Mes · Trimestre · Año).
enum Periodo: String, CaseIterable, Identifiable {
    case mes, trimestre, anio
    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .mes: return L.t("Mes", "Month")
        case .trimestre: return L.t("Trimestre", "Quarter")
        case .anio: return L.t("Año", "Year")
        }
    }
}

enum TipoMovimiento {
    case ingreso, gasto
}

/// La iglesia activa. Espejo reducido de `Church` en `src/db.ts`.
struct Church {
    let id: String
    let nombre: String
    let ciudad: String
    let moneda: String
    let tesoreroNombre: String?
}

/// Un movimiento (ingreso o gasto). El diseño muestra el titular como
/// "categoría · persona" y el subtítulo como "Folio NNNN · método".
struct Tx: Identifiable {
    let id: String
    let tipo: TipoMovimiento
    let categoria: String
    let persona: String?
    let concepto: String
    let folio: String
    let metodo: String
    let monto: Centavos

    /// "Diezmo · María Hernández" — o el concepto si no hay persona.
    var titular: String {
        if let persona, !persona.isEmpty { return "\(categoria) · \(persona)" }
        return concepto
    }
    /// "Folio 1042 · Efectivo"
    var subtitulo: String { "Folio \(folio) · \(metodo)" }
    /// Inicial para el avatar circular.
    var inicial: String { String(categoria.prefix(1)).uppercased() }
}

/// Una ocurrencia de "Esta semana" (agenda). El punto de color lo da la familia.
struct AgendaItem: Identifiable {
    let id: String
    /// "VIE" / "DOM" — día de la semana abreviado.
    let dia: String
    /// "21" — número del día.
    let num: String
    let titulo: String
    let subtitulo: String
    /// Índice en `Paleta.agenda` para el punto de color.
    let familia: Int
}

/// Un tramo de la gráfica de barras (un mes).
struct MesResumen: Identifiable {
    var id: String { clave }
    let clave: String
    /// "Mar" / "Ago" — etiqueta bajo la barra.
    let etiqueta: String
    let ingresos: Centavos
    let gastos: Centavos
}

/// Una porción de la dona de ingresos por categoría.
struct CategoriaMonto: Identifiable {
    var id: String { nombre }
    let nombre: String
    let monto: Centavos
}

/// Todo lo que el Dashboard necesita para un periodo, resuelto de una vez.
/// La vista no sabe de dónde salió (mock hoy, GRDB mañana).
struct DashboardData {
    let church: Church
    /// Saldo en caja HOY. No es del periodo, no se escala.
    let saldoCaja: Centavos
    let ingresos: Centavos
    let gastos: Centavos
    /// Variación vs. periodo anterior, en fracción (0.042 = +4.2%). `nil` si no aplica.
    let deltaSaldo: Double?
    let deltaGastos: Double?
    /// Pie de la tarjeta de ingresos: "132 registros · 18 diezmos".
    let registrosIngreso: Int
    let diezmos: Int
    let pendientes: Int
    /// Días para el corte de mes (para el subtítulo del saludo). **No es un
    /// dato del repositorio: es la fecha de hoy.** Iba escrito a mano como 11,
    /// así que el 3 de septiembre la app anunciaba el cierre para dentro de 11
    /// días cuando faltaban 27. Calculado, no puede volver a quedarse clavado.
    var corteDias: Int { Fechas.diasParaCorteDeMes() }
    /// Barras: seis meses, como en el diseño.
    let tramos: [MesResumen]
    /// Dona: INGRESOS por categoría (no gastos).
    let ingresosPorCategoria: [CategoriaMonto]
    let recientes: [Tx]
    let semana: [AgendaItem]

    var balance: Centavos { ingresos - gastos }
}
