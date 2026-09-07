import Foundation

/// La frontera entre la UI y los datos. La vista habla SOLO con este protocolo,
/// así que cuando llegue GRDB+SQLCipher se implementa `GRDBDashboardRepository`
/// y la interfaz no se toca ni una línea.
protocol DashboardRepository {
    func cargar(periodo: Periodo) async throws -> DashboardData
}

/// **La aritmética de Inicio, aparte del repositorio.** La comparten la maqueta
/// y las cuentas de verdad: si cada una sumara a su manera, recorrer la app sin
/// sesión dejaría de valer para ver lo que hace con sesión. Igual que
/// `CalculadoraReportes` y `CalculadoraRevisiones`: entra lo que ya existe,
/// sale lo que la pantalla enseña, y nada se guarda.
enum CalculadoraInicio {

    /// Lo que hay que saber de un tramo de tiempo, sacado de los movimientos.
    struct Resumen {
        var ingresos: Centavos = 0
        var gastos: Centavos = 0
        var registrosIngreso = 0
        var registrosGasto = 0
        var diezmos = 0
        var porCategoria: [CategoriaMonto] = []
    }

    static func resumen(_ movimientos: [Movimiento], en rango: Range<Date>) -> Resumen {
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
    static func porCategoria(_ ingresos: [Movimiento]) -> [CategoriaMonto] {
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
    static func variacion(de anterior: Centavos, a actual: Centavos) -> Double? {
        guard anterior > 0 else { return nil }
        return Double(actual - anterior) / Double(anterior)
    }
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
        let actual = CalculadoraInicio.resumen(movimientos, en: Fechas.intervalo(periodo))
        let anterior = CalculadoraInicio.resumen(movimientos, en: Fechas.intervalo(periodo, hace: 1))

        let ingresos = actual.ingresos
        let gastos = actual.gastos

        return DashboardData(
            church: Church(id: "1",
                nombre: "Iglesia Getsemaní",
                ciudad: "Monterrey, N.L.",
                moneda: Catalogos.monedaPorDefecto.codigo,
                tesoreroNombre: "Iván García"
            ),
            // **Calculado, no inventado.** Era 126_480_25 escrito aquí, mientras
            // Depósitos contaba su propio efectivo por otro lado: dos pantallas
            // podían decir cifras distintas del mismo dinero. Como lo contado
            // se deposita íntegro, el saldo en caja es exactamente lo recibido
            // en efectivo que ningún corte depositado reclama.
            saldoCaja: PuenteCortes.efectivoEnCaja(MockMovimientosRepository.todos),
            movimientosTotal: MockMovimientosRepository.todos.count,
            sinDepositarCount: MockMovimientosRepository.todos.filter(\.sinDepositar).count,
            ingresos: ingresos,
            gastos: gastos,
            // Sin periodo anterior no hay variación que enseñar. Iban escritas
            // a mano (4,2% y 11,0%) sobre unos datos de ejemplo que solo
            // cubren la última semana: no había con qué compararlos.
            deltaSaldo: nil,
            deltaIngresos: CalculadoraInicio.variacion(de: anterior.ingresos, a: actual.ingresos),
            deltaGastos: CalculadoraInicio.variacion(de: anterior.gastos, a: actual.gastos),
            registrosIngreso: actual.registrosIngreso,
            registrosGasto: actual.registrosGasto,
            diezmos: actual.diezmos,
            // De la bandeja CALCULADA, no de una semilla paralela: el KPI del
            // Inicio, el badge del tab y la propia bandeja responden a la misma
            // pregunta y tienen que dar el mismo número.
            pendientes: await RevisarCalculado().asuntos().filter { !$0.archivado }.count,
            tramos: Self.seisMeses,
            // La dona reparte EXACTAMENTE los ingresos del periodo, así que
            // su centro y la tarjeta de Ingresos no pueden discrepar.
            ingresosPorCategoria: actual.porCategoria,
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
            Tx(id: "1", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "María Hernández",
               concepto: L.t("Diezmo", "Tithe"), folio: "1042", metodo: L.t("Efectivo", "Cash"), monto: 1_200_00),
            Tx(id: "2", tipo: .gasto, categoria: L.t("Servicios", "Utilities"), persona: "Luz CFE",
               concepto: L.t("Luz CFE", "CFE power"), folio: "0518", metodo: L.t("Transferencia", "Transfer"), monto: 3_410_50),
            Tx(id: "3", tipo: .ingreso, categoria: L.t("Ofrenda", "Offering"), persona: nil,
               concepto: L.t("Ofrenda misionera", "Mission offering"), folio: "1041", metodo: L.t("Culto domingo", "Sunday service"), monto: 6_845_00),
            Tx(id: "4", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "Ana Lucía Torres",
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

/// **Inicio no es un dato: es una consulta**, como el estado financiero y como
/// la bandeja de revisión.
///
/// Era la última pantalla de Tesorería que no tocaba un movimiento real: la
/// primera que se ve al abrir la app enseñaba la iglesia Getsemaní de
/// Monterrey, seis meses de barras escritas a mano y cuatro movimientos
/// inventados, con la sesión de la iglesia de verdad abierta. Lee de los mismos
/// repositorios que las pantallas de las que es resumen, para que Inicio no
/// pueda decir una cifra que Ingresos desmienta una capa más abajo.
struct DashboardCalculado: DashboardRepository {
    private let movimientos = repositorioMovimientos()
    private let agenda = repositorioAgenda()

    func cargar(periodo: Periodo) async throws -> DashboardData {
        async let movs = todos()
        async let asuntos = RevisarCalculado().asuntos()
        async let resumenAgenda = agenda.resumen()
        let todos = await movs

        // **Solo lo aprobado cuenta**, la misma regla del web y de los
        // informes: un movimiento que espera visto bueno todavía no es un
        // hecho contable. Los devueltos no llegan siquiera, los descarta la
        // lista.
        let contables = todos.filter { $0.estadoRevision == .aprobado }
        let actual = CalculadoraInicio.resumen(contables, en: Fechas.intervalo(periodo))
        let anterior = CalculadoraInicio.resumen(contables, en: Fechas.intervalo(periodo, hace: 1))
        let config = ConfiguracionIglesiaViewModel.compartido.config

        return DashboardData(
            church: Church(id: "1",
                           nombre: config.nombre,
                           ciudad: config.ciudad,
                           moneda: config.moneda,
                           tesoreroNombre: config.tesoreroNombre.isEmpty
                               ? nil : config.tesoreroNombre),
            // Lo recibido en efectivo que ningún corte depositado reclama. Es
            // la misma definición que la consulta de `OfflineDepositosRepository`
            // y la que ya usa la pantalla de Depósitos: como lo contado se
            // deposita íntegro, eso ES el efectivo en caja.
            saldoCaja: contables
                .filter { $0.esIngreso && $0.esEfectivo && $0.sinDepositar }
                .reduce(0) { $0 + $1.monto },
            // Estos DOS cuentan todo lo registrado, aprobado o no: son "cuántos
            // movimientos hay" y "cuántos siguen sin depositar", no cifras
            // contables. El hub los enseña juntos y el segundo es trabajo
            // pendiente aunque el visto bueno no haya llegado.
            movimientosTotal: todos.count,
            sinDepositarCount: todos.filter { $0.esIngreso && $0.sinDepositar }.count,
            ingresos: actual.ingresos,
            gastos: actual.gastos,
            // Sin periodo anterior no hay variación que enseñar, que es lo que
            // le pasa a una iglesia en su primer mes con la app.
            deltaSaldo: nil,
            deltaIngresos: CalculadoraInicio.variacion(de: anterior.ingresos, a: actual.ingresos),
            deltaGastos: CalculadoraInicio.variacion(de: anterior.gastos, a: actual.gastos),
            registrosIngreso: actual.registrosIngreso,
            registrosGasto: actual.registrosGasto,
            diezmos: actual.diezmos,
            // De la bandeja CALCULADA: el KPI de Inicio, el badge del tab y la
            // propia bandeja responden a la misma pregunta.
            pendientes: await asuntos.filter { !$0.archivado }.count,
            tramos: Self.seisMeses(contables),
            ingresosPorCategoria: actual.porCategoria,
            recientes: Self.recientes(todos),
            semana: Self.semana(await resumenAgenda))
    }

    // MARK: - Origen

    private func todos() async -> [Movimiento] {
        async let ingresos = try? movimientos.lista(tipo: .ingreso)
        async let gastos = try? movimientos.lista(tipo: .gasto)
        return ((await ingresos) ?? []) + ((await gastos) ?? [])
    }

    // MARK: - Aritmética

    /// Las barras: los seis meses que acaban en el actual. **Siempre seis,
    /// aunque estén vacíos** — una iglesia que empieza en septiembre tiene que
    /// ver una barra creciendo, no una gráfica de un solo palo.
    private static func seisMeses(_ movimientos: [Movimiento]) -> [MesResumen] {
        let cal = Calendar.current
        let hoy = Date()
        return (0..<CalculadoraReportes.mesesDeHistoria).reversed().compactMap { atras in
            guard let mes = cal.date(byAdding: .month, value: -atras, to: hoy),
                  let rango = cal.dateInterval(of: .month, for: mes) else { return nil }
            let delMes = movimientos.filter { rango.contains($0.fecha) }
            return MesResumen(
                clave: Fechas.clavePeriodo(mes),
                // "Sep" — el mes solo, que es lo que cabe bajo una barra.
                etiqueta: L.formateador("LLL").string(from: mes).capitalized,
                ingresos: delMes.filter(\.esIngreso).reduce(0) { $0 + $1.monto },
                gastos: delMes.filter { !$0.esIngreso }.reduce(0) { $0 + $1.monto })
        }
    }

    /// Los últimos cuatro capturados, del más nuevo al más viejo. Sin filtrar
    /// por periodo a propósito: es "lo último que pasó", no un resumen del mes,
    /// y en los primeros días de un mes estaría siempre vacío.
    private static func recientes(_ movimientos: [Movimiento]) -> [Tx] {
        movimientos.sorted { $0.fecha > $1.fecha }.prefix(4).map { m in
            Tx(id: m.id, tipo: m.tipo, categoria: m.categoria, persona: m.persona,
               // El concepto de la fila es la nota; sin ella, la categoría
               // completa, que es lo que enseña la lista de Ingresos.
               concepto: (m.nota?.isEmpty == false ? m.nota! : m.categoriaCompleta),
               folio: m.folio, metodo: m.metodo, monto: m.monto)
        }
    }

    /// "Esta semana": los próximos compromisos de la agenda de verdad, que ya
    /// los calcula el propio protocolo contra la fecha de hoy. El mock traía
    /// cuatro de agosto escritos a mano, así que en septiembre anunciaba un
    /// consejo de ancianos "mañana viernes 21" estando a domingo.
    private static func semana(_ resumen: ResumenAgenda) -> [AgendaItem] {
        resumen.proximos.prefix(4).map { c in
            AgendaItem(id: c.id, dia: c.diaSemana, num: c.numDia,
                       titulo: c.evento.titulo,
                       subtitulo: Self.subtitulo(c),
                       familia: Self.familia(c.evento.tipo))
        }
    }

    /// `"19:00 mañana · salón anexo"`. El lugar solo si lo hay: un punto medio
    /// seguido de nada es peor que no ponerlo.
    private static func subtitulo(_ c: CompromisoProximo) -> String {
        let lugar = c.evento.lugar.trimmingCharacters(in: .whitespaces)
        guard !lugar.isEmpty else { return c.cuando }
        return "\(c.cuando) · \(lugar)"
    }

    /// El punto de color, que tiene cuatro. Se agrupa por lo que la fila ES
    /// —un culto, una reunión, algo de dinero, lo demás—: repartir los colores
    /// por orden de aparición haría que el mismo compromiso cambiara de color
    /// al llegar otro antes.
    private static func familia(_ tipo: TipoEvento) -> Int {
        switch tipo {
        case .culto, .cultoEspecial, .vigilia, .cenaPascual, .bautismo,
             .dedicacionNino, .boda, .ensayo:
            return 0
        case .reunion, .reunionLideres, .reunionAdministrativa, .asamblea,
             .conferencia, .retiro, .campana:
            return 1
        case .deposito, .fechaLimite, .tarea, .carta:
            return 2
        default:
            return 3
        }
    }
}

/// Maqueta sin sesión, cuentas de verdad con ella.
func repositorioDashboard() -> DashboardRepository {
    ModoRevision.sinLogin ? MockDashboardRepository() : DashboardCalculado()
}
