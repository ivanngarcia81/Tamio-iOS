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

        // El periodo escala los flujos; el saldo en caja es un saldo, no.
        let factor: Int
        switch periodo {
        case .mes: factor = 1
        case .trimestre: factor = 3
        case .anio: factor = 12
        }

        let ingresos = 48_320_00 * factor
        let gastos = 21_145_50 * factor

        return DashboardData(
            church: Church(
                id: 1,
                nombre: "Iglesia Getsemaní",
                ciudad: "Monterrey, N.L.",
                moneda: "MXN",
                tesoreroNombre: "Iván García"
            ),
            saldoCaja: 126_480_25,
            ingresos: ingresos,
            gastos: gastos,
            deltaSaldo: 0.042,
            deltaGastos: 0.11,
            registrosIngreso: 132 * factor,
            diezmos: 18 * factor,
            pendientes: 7,
            corteDias: 11,
            tramos: Self.seisMeses,
            // Suman 48,320.00 → 52% / 22% / 15% / 11%, y el total de la dona
            // coincide con "Ingresos de agosto" (centro "$48.3k").
            ingresosPorCategoria: [
                CategoriaMonto(nombre: L.t("Diezmos", "Tithes"), monto: 25_120_00 * factor),
                CategoriaMonto(nombre: L.t("Ofrendas", "Offerings"), monto: 10_630_00 * factor),
                CategoriaMonto(nombre: L.t("Misiones", "Missions"), monto: 7_250_00 * factor),
                CategoriaMonto(nombre: L.t("Eventos", "Events"), monto: 5_320_00 * factor),
            ],
            recientes: Self.recientes,
            semana: Self.semana
        )
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
            Tx(id: 1, tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "María Hernández",
               concepto: L.t("Diezmo", "Tithe"), folio: "1042", metodo: L.t("Efectivo", "Cash"), monto: 1_200_00),
            Tx(id: 2, tipo: .gasto, categoria: L.t("Servicios", "Utilities"), persona: "Luz CFE",
               concepto: L.t("Luz CFE", "CFE power"), folio: "0518", metodo: L.t("Transferencia", "Transfer"), monto: 3_410_50),
            Tx(id: 3, tipo: .ingreso, categoria: L.t("Ofrenda", "Offering"), persona: nil,
               concepto: L.t("Ofrenda misionera", "Mission offering"), folio: "1041", metodo: L.t("Culto domingo", "Sunday service"), monto: 6_845_00),
            Tx(id: 4, tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: L.t("Familia Ruvalcaba", "Ruvalcaba family"),
               concepto: L.t("Diezmo", "Tithe"), folio: "1040", metodo: L.t("Cheque 8823", "Check 8823"), monto: 2_500_00),
        ]
    }

    private static var semana: [AgendaItem] {
        [
            AgendaItem(id: 1, dia: L.t("VIE", "FRI"), num: "21",
                       titulo: L.t("Consejo de ancianos", "Elders council"),
                       subtitulo: L.t("19:00 · salón anexo · levantar acta", "7:00 PM · annex hall · minutes"), familia: 0),
            AgendaItem(id: 2, dia: L.t("DOM", "SUN"), num: "23",
                       titulo: L.t("Culto matutino", "Morning service"),
                       subtitulo: L.t("10:00 · roster completo", "10:00 · full roster"), familia: 1),
            AgendaItem(id: 3, dia: L.t("DOM", "SUN"), num: "23",
                       titulo: L.t("Depósito bancario", "Bank deposit"),
                       subtitulo: L.t("Banorte · 14 movimientos sin depositar", "Banorte · 14 undeposited items"), familia: 2),
            AgendaItem(id: 4, dia: L.t("MIÉ", "WED"), num: "26",
                       titulo: L.t("Carta de traslado · J. Medina", "Transfer letter · J. Medina"),
                       subtitulo: L.t("Pendiente de firma del pastor", "Awaiting pastor's signature"), familia: 3),
        ]
    }
}
