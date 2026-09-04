import Foundation

/// La frontera entre la UI y los datos. La vista habla SOLO con este protocolo,
/// así que cuando llegue GRDB+SQLCipher se implementa `GRDBDashboardRepository`
/// y la interfaz no se toca ni una línea.
protocol DashboardRepository {
    func cargar(periodo: Periodo) async throws -> DashboardData
}

/// Datos falsos que reproducen EXACTAMENTE las cifras del handoff del iPad
/// (Iglesia Getsemaní, agosto 2026). Los importes están en centavos.
struct MockDashboardRepository: DashboardRepository {
    func cargar(periodo: Periodo) async throws -> DashboardData {
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Las cifras de tesorería salen de los MISMOS movimientos que enseña
        // la pantalla de Ingresos/Gastos. Iban por su cuenta —48.320,00 por un
        // factor según el periodo— y contradecían a la pantalla que las tiene
        // una capa más abajo: Inicio decía "$48,320.00 · 132 registros" de
        // septiembre y la lista de Ingresos, con los mismos movimientos
        // delante, sumaba $23,863.00 en 8.
        let movimientos = MockMovimientosRepository.todos
        let actual = Self.resumen(movimientos, en: Fechas.intervalo(periodo))
        let anterior = Self.resumen(movimientos, en: Fechas.intervalo(periodo, hace: 1))

        let ingresos = actual.ingresos
        let gastos = actual.gastos

        return DashboardData(
            church: Church(id: "1",
                nombre: "Iglesia Getsemaní",
                ciudad: "Monterrey, N.L.",
                moneda: Catalogos.monedaPorDefecto.codigo,
                tesoreroNombre: "Iván García"
            ),
            saldoCaja: 126_480_25,
            ingresos: ingresos,
            gastos: gastos,
            // Sin periodo anterior no hay variación que enseñar. Iban escritas
            // a mano (4,2% y 11,0%) sobre unos datos de ejemplo que solo
            // cubren la última semana: no había con qué compararlos.
            deltaSaldo: nil,
            deltaIngresos: Self.variacion(de: anterior.ingresos, a: actual.ingresos),
            deltaGastos: Self.variacion(de: anterior.gastos, a: actual.gastos),
            registrosIngreso: actual.registrosIngreso,
            registrosGasto: actual.registrosGasto,
            diezmos: actual.diezmos,
            pendientes: MockRevisarRepository.porRevisarCount,
            tramos: Self.seisMeses,
            // La dona reparte EXACTAMENTE los ingresos del periodo, así que
            // su centro y la tarjeta de Ingresos no pueden discrepar.
            ingresosPorCategoria: actual.porCategoria,
            recientes: Self.recientes,
            semana: Self.semana
        )
    }

    /// Lo que hay que saber de un tramo de tiempo, sacado de los movimientos.
    private struct Resumen {
        var ingresos: Centavos = 0
        var gastos: Centavos = 0
        var registrosIngreso = 0
        var registrosGasto = 0
        var diezmos = 0
        var porCategoria: [CategoriaMonto] = []
    }

    private static func resumen(_ movimientos: [Movimiento], en rango: Range<Date>) -> Resumen {
        let delRango = movimientos.filter { rango.contains($0.fecha) }
        let ingresos = delRango.filter(\.esIngreso)
        var r = Resumen()
        r.ingresos = ingresos.reduce(0) { $0 + $1.monto }
        let gastos = delRango.filter { !$0.esIngreso }
        r.gastos = gastos.reduce(0) { $0 + $1.monto }
        r.registrosIngreso = ingresos.count
        r.registrosGasto = gastos.count
        r.diezmos = ingresos.filter { $0.claveCategoria == .diezmo }.count
        r.porCategoria = porCategoria(ingresos)
        return r
    }

    /// Los ingresos agrupados por categoría, de mayor a menor. Se agrupa por
    /// CLAVE y no por la etiqueta escrita: "Ofrenda misionera" y "Ofrenda del
    /// miércoles" son las dos ofrendas y la dona no tiene por qué partirlas en
    /// dos porciones. La que la iglesia se inventó y no se parece a nada del
    /// catálogo conserva su nombre tal cual.
    ///
    /// La dona tiene cuatro colores: a partir del cuarto se acumulan en
    /// "Otras", que además mantiene su suma igual al total del periodo.
    private static func porCategoria(_ ingresos: [Movimiento]) -> [CategoriaMonto] {
        let porNombre = Dictionary(grouping: ingresos) { m in
            m.claveCategoria.map(Catalogos.etiqueta(de:)) ?? m.categoria
        }
            .map { CategoriaMonto(nombre: $0.key, monto: $0.value.reduce(0) { $0 + $1.monto }) }
            .sorted { $0.monto > $1.monto }
        guard porNombre.count > Paleta.donut.count else { return porNombre }
        let visibles = porNombre.prefix(Paleta.donut.count - 1)
        let resto = porNombre.dropFirst(Paleta.donut.count - 1).reduce(0) { $0 + $1.monto }
        return visibles + [CategoriaMonto(nombre: L.t("Otras", "Other"), monto: resto)]
    }

    /// Variación de un periodo al siguiente. `nil` si el anterior fue cero: no
    /// es un +100%, es que no hay con qué comparar.
    private static func variacion(de anterior: Centavos, a actual: Centavos) -> Double? {
        guard anterior > 0 else { return nil }
        return Double(actual - anterior) / Double(anterior)
    }

    private static var seisMeses: [MesResumen] {
        let et = L.esEspanol
            ? ["Mar", "Abr", "May", "Jun", "Jul", "Ago"]
            : ["Mar", "Apr", "May", "Jun", "Jul", "Aug"]
        let ing = [41_000_00, 46_200_00, 39_800_00, 52_400_00, 45_100_00, 48_320_00]
        let gas = [28_000_00, 33_100_00, 29_500_00, 36_200_00, 30_400_00, 21_145_50]
        return (0..<6).map { i in
            MesResumen(clave: "m\(i)", etiqueta: et[i], ingresos: ing[i], gastos: gas[i])
        }
    }

    private static var recientes: [Tx] {
        [
            Tx(id: "1", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "María Hernández",
               concepto: L.t("Diezmo", "Tithe"), folio: "1042", metodo: L.t("Efectivo", "Cash"), monto: 1_200_00),
            Tx(id: "2", tipo: .gasto, categoria: L.t("Servicios", "Utilities"), persona: "Luz CFE",
               concepto: L.t("Luz CFE", "CFE power"), folio: "0518", metodo: L.t("Transferencia", "Transfer"), monto: 3_410_50),
            Tx(id: "3", tipo: .ingreso, categoria: L.t("Ofrenda", "Offering"), persona: nil,
               concepto: L.t("Ofrenda misionera", "Mission offering"), folio: "1041", metodo: L.t("Culto domingo", "Sunday service"), monto: 6_845_00),
            Tx(id: "4", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: L.t("Familia Ruvalcaba", "Ruvalcaba family"),
               concepto: L.t("Diezmo", "Tithe"), folio: "1040", metodo: L.t("Cheque 8823", "Check 8823"), monto: 2_500_00),
        ]
    }

    private static var semana: [AgendaItem] {
        [
            AgendaItem(id: "1", dia: L.t("VIE", "FRI"), num: "21",
                       titulo: L.t("Consejo de ancianos", "Elders council"),
                       subtitulo: L.t("19:00 · salón anexo · levantar acta", "7:00 PM · annex hall · minutes"), familia: 0),
            AgendaItem(id: "2", dia: L.t("DOM", "SUN"), num: "23",
                       titulo: L.t("Culto matutino", "Morning service"),
                       subtitulo: L.t("10:00 · roster completo", "10:00 · full roster"), familia: 1),
            AgendaItem(id: "3", dia: L.t("DOM", "SUN"), num: "23",
                       titulo: L.t("Depósito bancario", "Bank deposit"),
                       subtitulo: L.t("Banorte · 14 movimientos sin depositar", "Banorte · 14 undeposited items"), familia: 2),
            AgendaItem(id: "4", dia: L.t("MIÉ", "WED"), num: "26",
                       titulo: L.t("Carta de traslado · J. Medina", "Transfer letter · J. Medina"),
                       subtitulo: L.t("Pendiente de firma del pastor", "Awaiting pastor's signature"), familia: 3),
        ]
    }
}
