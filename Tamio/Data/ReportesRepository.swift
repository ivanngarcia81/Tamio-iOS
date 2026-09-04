import Foundation

protocol ReportesRepository {
    func tipos() -> [ReporteTipo]
    /// Periodos con movimientos, del más reciente al más antiguo.
    func periodos() async -> [PeriodoContable]
    /// Categorías de ingreso presentes en los datos, para filtrar.
    func categorias() async -> [String]
    /// Estado financiero de un periodo, opcionalmente acotado a una categoría
    /// de ingreso. `categoria == nil` significa "todas". `nil` si no hay nada
    /// que reportar todavía.
    func estadoFinanciero(periodo: String, categoria: String?) async -> EstadoFinanciero?
}

/// **El reporte no es un dato: es una consulta.**
///
/// Lee los mismos movimientos que enseña Ingresos/Gastos, los mismos depósitos
/// que enseña Depósitos y el saldo de apertura que se teclea en Ajustes.
/// Sustituye a `MockReportesRepository`, que llevaba el estado financiero
/// entero escrito a mano —48.320,00 de ingresos, 21.145,50 de gastos, seis
/// meses de tabla y cuatro porcentajes de presupuesto— y era la única pantalla
/// de Tesorería que no tocaba un movimiento real. La cifra que se imprime,
/// se firma y se manda al pastor era la única que nadie había calculado.
struct ReportesCalculados: ReportesRepository {
    private let movimientos = repositorioMovimientos()
    private let depositos = repositorioDepositos()

    func tipos() -> [ReporteTipo] {
        [
            ReporteTipo(id: "estado", titulo: L.t("Estado financiero", "Financial statement"),
                        subtitulo: L.t("Ingresos, gastos y saldo", "Income, expenses & balance")),
            ReporteTipo(id: "anual", titulo: L.t("Reporte anual", "Annual report"),
                        subtitulo: L.t("Los doce meses en una hoja", "All twelve months on one page")),
        ]
    }

    func periodos() async -> [PeriodoContable] {
        let claves = Set(await aprobados().map { Fechas.clavePeriodo($0.fecha) })
        return claves.sorted(by: >).map(PeriodoContable.init)
    }

    func categorias() async -> [String] {
        let ingresos = await aprobados().filter(\.esIngreso)
        return CalculadoraReportes.porCategoria(ingresos, agrupar: false).map(\.nombre)
    }

    func estadoFinanciero(periodo: String, categoria: String?) async -> EstadoFinanciero? {
        async let movs = aprobados()
        async let pend = pendientes()
        async let deps = depositosBancarios()
        return CalculadoraReportes.estado(
            periodo: periodo,
            categoria: categoria,
            movimientos: await movs,
            pendientes: await pend,
            depositos: await deps,
            saldoApertura: ConfiguracionIglesiaViewModel.compartido.config.saldoInicial
        )
    }

    // MARK: - Origen

    /// **Solo lo aprobado cuenta.** Es la regla de la app web, que filtra por
    /// `estado = 'aprobado'` en todas sus agregaciones, y la que ya declara el
    /// propio modelo: un movimiento que espera visto bueno todavía no es un
    /// hecho contable. Los devueltos no llegan siquiera: la lista los excluye.
    private func aprobados() async -> [Movimiento] {
        await todos().filter { $0.estadoRevision == .aprobado }
    }

    private func pendientes() async -> [Movimiento] {
        await todos().filter(\.marcadoPendiente)
    }

    private func todos() async -> [Movimiento] {
        async let ingresos = try? movimientos.lista(tipo: .ingreso)
        async let gastos = try? movimientos.lista(tipo: .gasto)
        return ((await ingresos) ?? []) + ((await gastos) ?? [])
    }

    /// Los depósitos ya registrados. Solo un corte depositado tiene fila en
    /// `depositos_bancarios`: mientras el dinero no ha ido al banco no hay
    /// depósito que reportar, únicamente un corte armado.
    private func depositosBancarios() async -> [DepositoBancario] {
        let cortes = (try? await depositos.cortes(estado: .depositado)) ?? []
        return cortes.compactMap(\.deposito)
    }
}

/// La aritmética del estado financiero, aparte del repositorio para que se
/// pueda leer entera de una vez. Igual que `CalculadoraRevisiones`: entra lo
/// que ya existe, sale lo que la pantalla enseña, y nada se guarda.
enum CalculadoraReportes {

    /// Cuántos meses enseña la mini gráfica y la tabla mensual.
    static let mesesDeHistoria = 6

    static func estado(periodo: String,
                       categoria: String?,
                       movimientos: [Movimiento],
                       pendientes: [Movimiento],
                       depositos: [DepositoBancario],
                       saldoApertura: Centavos) -> EstadoFinanciero? {
        let porMes = Dictionary(grouping: movimientos) { Fechas.clavePeriodo($0.fecha) }
        guard !porMes.isEmpty else { return nil }
        // Un periodo que no existe en los datos cae al más reciente: es lo que
        // pasa al arrancar con un filtro guardado de un mes que se quedó vacío.
        let clave = porMes[periodo] != nil ? periodo : (porMes.keys.max() ?? periodo)
        let delMes = porMes[clave] ?? []

        // La tabla mensual y la serie salen de TODOS los meses, no solo del
        // elegido: son el contexto contra el que se lee el mes.
        let filas = mensual(porMes)
        guard let i = filas.firstIndex(where: { $0.clave == clave }) else { return nil }
        let fila = filas[i]
        let previa = i > 0 ? filas[i - 1] : nil

        // El filtro de categoría acota los INGRESOS. Los gastos no se tocan:
        // las categorías del menú son de ingreso, y recortar el gasto por una
        // de ellas daría un balance que no significa nada.
        var ingresos = delMes.filter(\.esIngreso)
        if let categoria {
            ingresos = ingresos.filter { nombreCategoria($0) == categoria }
        }
        let ingresosMes = suma(ingresos)
        let gastosMes = fila.gastos
        let balance = ingresosMes - gastosMes

        return EstadoFinanciero(
            periodo: PeriodoContable(clave: clave),
            ingresosMes: ingresosMes,
            gastosMes: gastosMes,
            deltaIngresos: variacion(de: previa?.ingresos, a: ingresosMes),
            deltaGastos: variacion(de: previa?.gastos, a: gastosMes),
            deltaBalance: variacion(de: previa?.balance, a: balance),
            mesAnterior: previa?.balance,
            mesAnteriorNombre: previa?.mes,
            saldoAnterior: saldoAnterior(hasta: clave, movimientos: movimientos,
                                         apertura: saldoApertura),
            saldoSerie: serie(filas, hasta: i),
            composicion: porCategoria(ingresos),
            gastosPorCategoria: porCategoria(delMes.filter { !$0.esIngreso }),
            depositos: depositos.filter { $0.periodo == clave }
                .sorted { $0.fecha < $1.fecha },
            pendientes: pendientes.filter { Fechas.clavePeriodo($0.fecha) == clave }.count,
            mensual: Array(filas.suffix(mesesDeHistoria))
        )
    }

    /// **El saldo de tesorería al cierre del mes anterior**: lo que la iglesia
    /// ya tenía antes del primer movimiento registrado (Ajustes → Iglesia) más
    /// todo lo aprobado con fecha anterior a este periodo. Cubre los dos casos,
    /// la iglesia que arrancó en Tamio desde cero y la que llegó con dinero ya
    /// en caja. Es la misma definición que `saldoAnteriorDe` en la app web.
    static func saldoAnterior(hasta clave: String,
                              movimientos: [Movimiento],
                              apertura: Centavos) -> Centavos {
        let anteriores = movimientos.filter { Fechas.clavePeriodo($0.fecha) < clave }
        let ingresos = suma(anteriores.filter(\.esIngreso))
        let gastos = suma(anteriores.filter { !$0.esIngreso })
        return apertura + ingresos - gastos
    }

    /// Un resumen por mes, del más antiguo al más reciente. Solo meses con
    /// movimientos: un mes vacío en medio de la tabla no informa de nada y en
    /// una iglesia que empezó en marzo llenaría el reporte de ceros.
    static func mensual(_ porMes: [String: [Movimiento]]) -> [FilaMensual] {
        var previo: Centavos?
        return porMes.keys.sorted().map { clave in
            let movs = porMes[clave] ?? []
            let ingresos = suma(movs.filter(\.esIngreso))
            let gastos = suma(movs.filter { !$0.esIngreso })
            let balance = ingresos - gastos
            let fila = FilaMensual(clave: clave, ingresos: ingresos, gastos: gastos,
                                   delta: variacion(de: previo, a: balance))
            previo = balance
            return fila
        }
    }

    /// La serie de la mini gráfica: los meses que preceden al elegido, sin
    /// pasarse de él. Antes se copiaba siempre la misma lista de la semilla,
    /// así que cambiar de mes movía los KPI y dejaba la gráfica en agosto.
    private static func serie(_ filas: [FilaMensual], hasta i: Int) -> [MesAporte] {
        filas[...i].suffix(mesesDeHistoria).map { f in
            let fecha = Fechas.fechaDePeriodo(f.clave)
            return MesAporte(mes: fecha.map(L.mesCorto) ?? f.clave, monto: f.balance)
        }
    }

    /// Agrupa por CLAVE de categoría y no por la etiqueta escrita: "Ofrenda
    /// misionera" y "Ofrenda del miércoles" son las dos ofrendas, y la dona no
    /// tiene por qué partirlas. La que la iglesia se inventó conserva su
    /// nombre. Con `agrupar`, a partir del cuarto se acumulan en "Otras" para
    /// que la suma de la dona siga siendo el total del periodo.
    static func porCategoria(_ movs: [Movimiento], agrupar: Bool = true) -> [CategoriaMonto] {
        let ordenadas = Dictionary(grouping: movs, by: nombreCategoria)
            .map { CategoriaMonto(nombre: $0.key, monto: suma($0.value)) }
            .sorted { $0.monto > $1.monto }
        guard agrupar, ordenadas.count > Paleta.donut.count else { return ordenadas }
        let visibles = ordenadas.prefix(Paleta.donut.count - 1)
        let resto = ordenadas.dropFirst(Paleta.donut.count - 1).reduce(0) { $0 + $1.monto }
        return visibles + [CategoriaMonto(nombre: L.t("Otras", "Other"), monto: resto)]
    }

    /// El nombre con el que se agrupa: la etiqueta de su clave, o lo escrito
    /// si no se parece a nada del catálogo.
    static func nombreCategoria(_ m: Movimiento) -> String {
        m.claveCategoria.map(Catalogos.etiqueta(de:)) ?? m.categoria
    }

    private static func suma(_ movs: [Movimiento]) -> Centavos {
        movs.reduce(0) { $0 + $1.monto }
    }

    /// `nil` si no hay periodo anterior o fue cero: eso no es un +100%, es que
    /// no hay con qué comparar.
    private static func variacion(de anterior: Centavos?, a actual: Centavos) -> Double? {
        guard let anterior, anterior > 0 else { return nil }
        return Double(actual - anterior) / Double(anterior)
    }
}

/// El repositorio que usa la pantalla. **También en modo revisión se calcula**:
/// los datos de ejemplo son movimientos y cortes de verdad, así que el reporte
/// sale de ellos igual que en producción. Es lo mismo que ya se hizo con la
/// bandeja "Por revisar".
func repositorioReportes() -> ReportesRepository { ReportesCalculados() }
