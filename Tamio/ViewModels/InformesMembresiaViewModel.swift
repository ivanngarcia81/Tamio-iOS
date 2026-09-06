import Foundation

// MARK: - Tipo de periodo para informes

enum PeriodoInforme: String, CaseIterable {
    case mes, trimestre, anio, rango, todo

    var etiqueta: String {
        switch self {
        case .mes:       return L.t("Mes", "Month")
        case .trimestre: return L.t("Trimestre", "Quarter")
        case .anio:      return L.t("Año", "Year")
        case .rango:     return L.t("Rango", "Range")
        case .todo:      return L.t("Todo", "All time")
        }
    }
}

// MARK: - ViewModel

/// Las ocho tarjetas del informe de Miembros, que además FILTRAN la lista.
/// Reflejadas del web (`TarjetaFiltro` de `InformesMembresia.tsx`), con sus
/// mismas ocho identidades y en su mismo orden.
///
/// **Cuatro son estados y cuatro no.** Activos, inactivos y bajas se excluyen
/// entre sí y suman el total; nuevos, recibidos y trasladados son movimientos
/// del periodo —una persona puede ser nueva Y estar activa— y ausencias e
/// incompletos son señales para trabajar. Por eso los porcentajes no cuadran a
/// 100 y no deben presentarse como si lo hicieran.
enum TarjetaPadron: String, CaseIterable, Identifiable {
    case todos, activos, inactivos, nuevos, recibidos, trasladados, ausencias, incompletos
    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .todos:       return L.t("Total", "Total")
        case .activos:     return L.t("Activos", "Active")
        case .inactivos:   return L.t("Inactivos", "Inactive")
        case .nuevos:      return L.t("Nuevos", "New")
        case .recibidos:   return L.t("Recibidos", "Received")
        case .trasladados: return L.t("Trasladados", "Transferred")
        case .ausencias:   return L.t("Ausencias frecuentes", "Frequent absences")
        case .incompletos: return L.t("Expediente incompleto", "Incomplete record")
        }
    }

    /// El mismo criterio con el que `MembresiaRepository.resumen()` cuenta cada
    /// cifra. **Y la cifra de la tarjeta se saca CONTANDO con este predicado**,
    /// no leyendo `MembresiaResumen`: así la tarjeta y la lista son la misma
    /// expresión y no pueden divergir.
    ///
    /// No es paranoia. Al escribir este informe, las tarjetas decían 248, 236 y
    /// 21 sobre una lista de siete personas, porque `MockMembresiaRepository`
    /// devuelve un resumen escrito a mano que su propia `lista()` desmiente. Un
    /// informe que encabeza un número y enseña otro no es un informe. Es la
    /// misma lección que ya dejó escrita `MembresiaResumen.total`: **no se
    /// escribe, se suma.**
    func incluye(_ m: Miembro, año: Int) -> Bool {
        switch self {
        case .todos:       return true
        case .activos:     return !m.estado.esBaja && m.estado.registro == .activo
        case .inactivos:   return !m.estado.esBaja && m.estado.registro != .activo
        case .nuevos:      return m.esNuevo(en: año)
        case .recibidos:   return m.esNuevo(en: año) && m.esRecibido
        case .trasladados: return m.estado.baja?.motivo == "traslado"
                               && Int(m.estado.baja?.fecha.prefix(4) ?? "") == año
        case .ausencias:   return !m.estado.esBaja && m.tieneAusencias
        case .incompletos: return !m.estado.esBaja && !m.expedienteCompleto
        }
    }
}

@Observable
final class InformesMembresiaViewModel {

    // Selección de tipo de periodo
    var periodoTipo: PeriodoInforme = .anio

    // Sub-selectores según tipo
    var mesSeleccionado: Int = 8          // 1-12
    var trimestreSeleccionado: Int = 3    // 1-4
    var añoSeleccionado: Int = 2026
    var rangoDesde: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var rangoHasta: Date = Date()

    // Informe activo en la lista
    var informeSeleccionado = 0   // 0 General · 1 Miembros · 2 Asistencia · 3 Seguimiento

    // MARK: - Informe de Miembros · el padrón de verdad

    /// **Este informe NO sale de la maqueta.** El General sigue leyendo
    /// `resumenMes`/`resumenAnio`, que son constantes escritas a mano, y para
    /// distribuciones de ejemplo da igual. El padrón no: un informe que
    /// encabeza 248 sobre una lista de siete no es un informe, es dos pantallas
    /// discrepando. Así que lee del mismo repositorio que Membresía.
    private let padronRepo: MembresiaRepository
    private(set) var miembros: [Miembro] = []
    private(set) var padronCargado = false
    /// La tarjeta que está filtrando. `todos` es "sin filtrar", no una novena.
    var tarjeta: TarjetaPadron = .todos

    init(padronRepo: MembresiaRepository = repositorioMembresia()) {
        self.padronRepo = padronRepo
    }

    /// El resumen congregacional del periodo: servicios, promedio y porcentaje.
    private(set) var asistencia: AsistenciaResumen?

    @MainActor
    func cargarPadron() async {
        miembros = (try? await padronRepo.lista()) ?? []
        asistencia = await padronRepo.asistenciaResumen()
        padronCargado = true
    }

    // MARK: - Informe de Asistencia

    /// Cuántos entran en el top. El web lo tiene configurable
    /// (`umbrales.topAsistencia`); aquí es fijo hasta que Ajustes tenga dónde
    /// ponerlo, y se nombra para que se vea que es una decisión y no un 10
    /// suelto en medio de un `prefix`.
    static let cuantosEnElTop = 10

    /// **El aviso que evita que la pantalla parezca rota.** Es del web, con su
    /// misma razón: hubo cultos, pero si en ninguno se tomó lista, cada miembro
    /// sale con "—" y el informe se lee como un fallo en vez de como "falta
    /// tomar lista". Sin el aviso, la bitácora dice que hubo 27 servicios y
    /// esta pantalla no explica por qué no sabe nada de ellos.
    var sinListasTomadas: Bool {
        (asistencia?.serviciosPeriodo ?? 0) > 0
            && miembros.allSatisfy { ($0.asistenciaResumen?.servicios ?? 0) == 0 }
    }

    /// Top por porcentaje. **Los empates se rompen por asistidos**, como en el
    /// web: entre dos al 100%, primero el que vino a más cultos, o el que vino
    /// a uno solo encabezaría la lista de los más constantes.
    ///
    /// Quien no tiene ningún culto en su periodo queda fuera y no cuenta como
    /// 0%: no es que faltara, es que no había a qué faltar.
    ///
    /// **Y quien está de baja tampoco compite.** Lo enseñó la prueba: Rosa
    /// Elena Vega, trasladada en marzo, cerraba "los que más vinieron" con un
    /// 0%. No es un dato malo, es una pregunta mal hecha —dejó la iglesia, no
    /// faltó a los cultos— y ese cero encabezaría la lista al revés en cuanto
    /// alguien la ordenara de menor a mayor.
    var mejoresPorAsistencia: [Miembro] {
        miembros
            .filter { !$0.estado.esBaja && ($0.asistenciaResumen?.servicios ?? 0) > 0 }
            .sorted { a, b in
                if a.asistenciaPct != b.asistenciaPct { return a.asistenciaPct > b.asistenciaPct }
                return (a.asistenciaResumen?.presentes ?? 0) > (b.asistenciaResumen?.presentes ?? 0)
            }
            .prefix(Self.cuantosEnElTop)
            .map { $0 }
    }

    // MARK: Las cuatro cifras, de UNA sola fuente

    /// **Las cuatro salen de las fichas, no del resumen congregacional.**
    /// Mezclarlas enseñaba una contradicción en pantalla: "110 de asistencia
    /// total" al lado de "186 de promedio por servicio", que no pueden ser las
    /// dos con 27 servicios. El 186 venía del resumen de la maqueta —un número
    /// de una iglesia de 248— y el 110 de sumar las siete fichas que existen.
    ///
    /// Es el mismo descuadre que ya obligó a contar las tarjetas del informe de
    /// Miembros aquí en vez de pedirlas: **si dos cifras de la misma pantalla
    /// salen de dos sitios, un día se contradicen.** Del resumen se toma solo
    /// el número de servicios, que las fichas no saben.
    ///
    /// La fórmula es la del web (`resumenAsistencia`): presentes sobre plazas
    /// de roster.
    var serviciosDelPeriodo: Int { asistencia?.serviciosPeriodo ?? 0 }

    /// Presentes sumados de todo el padrón en el periodo.
    var asistenciaTotal: Int {
        miembros.reduce(0) { $0 + ($1.asistenciaResumen?.presentes ?? 0) }
    }

    /// Plazas de roster: cuántas veces alguien PUDO venir. Es el denominador
    /// del porcentaje general, y no es servicios × miembros: quien entró al
    /// padrón a mitad de año tuvo menos cultos a los que faltar.
    private var plazasDeRoster: Int {
        miembros.reduce(0) { $0 + ($1.asistenciaResumen?.servicios ?? 0) }
    }

    var promedioPorServicio: Int {
        serviciosDelPeriodo > 0
            ? Int((Double(asistenciaTotal) / Double(serviciosDelPeriodo)).rounded())
            : 0
    }

    /// `nil` cuando no hay de dónde: un 0% diría que no vino nadie, y lo que
    /// pasa es que no se tomó lista.
    var porcentajeGeneral: Int? {
        plazasDeRoster > 0
            ? Int((Double(asistenciaTotal) / Double(plazasDeRoster) * 100).rounded())
            : nil
    }

    /// **No se pide `resumen()` al repositorio, se cuenta aquí.** Es lo único
    /// que garantiza que la tarjeta y la lista digan lo mismo: las dos salen de
    /// `TarjetaPadron.incluye` sobre el mismo array. Pedirlo al repositorio
    /// enseñaba 236 activos encima de una lista de seis.
    func cuenta(_ t: TarjetaPadron) -> Int {
        miembros.filter { t.incluye($0, año: añoDelPeriodo) }.count
    }

    /// El año contra el que se cuentan los movimientos del periodo. Sale del
    /// selector de periodo, no de `Date()`: mirar el informe de 2025 y contar
    /// las altas de 2026 sería mentir con la cara seria.
    var añoDelPeriodo: Int { añoSeleccionado }

    var miembrosFiltrados: [Miembro] {
        miembros.filter { tarjeta.incluye($0, año: añoDelPeriodo) }
    }

    // MARK: - Etiqueta del periodo seleccionado

    var etiquetaPeriodo: String {
        switch periodoTipo {
        case .mes:
            return "\(Self.nombreMes(mesSeleccionado)) \(String(añoSeleccionado))"
        case .trimestre:
            let mesesQ = Self.mesesDelTrimestre(trimestreSeleccionado)
            return "Q\(trimestreSeleccionado) \(String(añoSeleccionado)) · \(mesesQ)"
        case .anio:
            return L.t("Año \(String(añoSeleccionado))", "Year \(String(añoSeleccionado))")
        case .rango:
            return "\(Self.fmtCorto.string(from: rangoDesde)) – \(Self.fmtCorto.string(from: rangoHasta))"
        case .todo:
            return L.t("Todo el historial", "All time")
        }
    }

    // MARK: - Resumen según periodo activo

    var resumen: InformeResumen {
        switch periodoTipo {
        case .mes:       return Self.resumenMes(mes: mesSeleccionado, año: añoSeleccionado)
        case .trimestre: return Self.resumenTrimestre(q: trimestreSeleccionado, año: añoSeleccionado)
        case .anio:      return Self.resumenAnio(año: añoSeleccionado)
        case .rango:     return Self.resumenRango
        case .todo:      return Self.resumenTodo
        }
    }

    // MARK: - Helpers de nombre

    static func nombreMes(_ m: Int) -> String {
        let cortos = L.t("Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic",
                         "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec")
            .split(separator: " ").map(String.init)
        return m >= 1 && m <= 12 ? cortos[m - 1] : "?"
    }

    static func mesesDelTrimestre(_ q: Int) -> String {
        switch q {
        case 1: return L.t("Ene–Mar", "Jan–Mar")
        case 2: return L.t("Abr–Jun", "Apr–Jun")
        case 3: return L.t("Jul–Sep", "Jul–Sep")
        case 4: return L.t("Oct–Dic", "Oct–Dec")
        default: return "Q\(q)"
        }
    }

    private static let fmtCorto: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = L.t("d MMM yy", "MMM d, yy"); f.locale = L.locale; return f
    }()

    // MARK: - Mock data por periodo

    private static func resumenMes(mes: Int, año: Int) -> InformeResumen {
        let altas = [3, 1, 2, 4, 2, 1, 5, 3, 0, 0, 0, 0]
        let n = nombreMes(mes)
        return InformeResumen(
            totalMiembros: 248,
            periodo: "\(n) \(año)",
            porEstado: [
                (L.t("Activo", "Active"), 236),
                (L.t("Nuevo", "New"), 7),
                (L.t("Traslado", "Transfer"), 2),
                (L.t("Inactivo", "Inactive"), 3),
            ],
            porMinisterio: [
                (L.t("Enseñanza", "Teaching"), 46),
                (L.t("Música", "Music"), 38),
                (L.t("Ujieres", "Ushers"), 24),
                (L.t("Niños", "Children"), 22),
            ],
            expedienteCompleto: 227, expedienteIncompleto: 21,
            altasPorMes: [MesAlta(id: 1, mes: n, altas: mes <= 12 ? altas[mes - 1] : 0)],
            traslados: [trasladoJavier]
        )
    }

    private static func resumenTrimestre(q: Int, año: Int) -> InformeResumen {
        let grupos: [[Int]] = [[1,2,3],[4,5,6],[7,8,9],[10,11,12]]
        let meses = grupos[min(q - 1, 3)]
        let altasData = [3, 1, 2, 4, 2, 1, 5, 3, 0, 0, 0, 0]
        return InformeResumen(
            totalMiembros: 248,
            periodo: "Q\(q) \(año) · \(mesesDelTrimestre(q))",
            porEstado: [
                (L.t("Activo", "Active"), 236),
                (L.t("Nuevo", "New"), 9),
                (L.t("Traslado", "Transfer"), 2),
                (L.t("Inactivo", "Inactive"), 1),
            ],
            porMinisterio: [
                (L.t("Enseñanza", "Teaching"), 46),
                (L.t("Música", "Music"), 38),
                (L.t("Ujieres", "Ushers"), 24),
                (L.t("Niños", "Children"), 22),
                (L.t("Medios", "Media"), 14),
            ],
            expedienteCompleto: 240, expedienteIncompleto: 8,
            altasPorMes: meses.enumerated().map { idx, m in
                MesAlta(id: idx + 1, mes: nombreMes(m), altas: altasData[m - 1])
            },
            traslados: [trasladoJavier, trasladoDaniel]
        )
    }

    private static func resumenAnio(año: Int) -> InformeResumen {
        InformeResumen(
            totalMiembros: 262,
            periodo: L.t("Año \(año)", "Year \(año)"),
            porEstado: [
                (L.t("Activo", "Active"), 248),
                (L.t("Inactivo", "Inactive"), 6),
                (L.t("Visitante", "Visitor"), 4),
                (L.t("En proceso", "In process"), 2),
                (L.t("Trasladado", "Transferred"), 2),
            ],
            porMinisterio: [
                (L.t("Enseñanza", "Teaching"), 46),
                (L.t("Música", "Music"), 38),
                (L.t("Ujieres", "Ushers"), 24),
                (L.t("Niños", "Children"), 22),
                (L.t("Medios", "Media"), 14),
                (L.t("Cocina", "Kitchen"), 12),
            ],
            expedienteCompleto: 250, expedienteIncompleto: 12,
            altasPorMes: [
                MesAlta(id: 1,  mes: L.t("ene","jan"), altas: 3),
                MesAlta(id: 2,  mes: L.t("feb","feb"), altas: 1),
                MesAlta(id: 3,  mes: L.t("mar","mar"), altas: 2),
                MesAlta(id: 4,  mes: L.t("abr","apr"), altas: 4),
                MesAlta(id: 5,  mes: L.t("may","may"), altas: 2),
                MesAlta(id: 6,  mes: L.t("jun","jun"), altas: 1),
                MesAlta(id: 7,  mes: L.t("jul","jul"), altas: 5),
                MesAlta(id: 8,  mes: L.t("ago","aug"), altas: 3),
            ],
            traslados: [trasladoJavier, trasladoDaniel, trasladoRosa]
        )
    }

    private static let resumenRango = InformeResumen(
        totalMiembros: 248,
        periodo: L.t("Rango personalizado", "Custom range"),
        porEstado: [
            (L.t("Activo", "Active"), 236),
            (L.t("Nuevo", "New"), 5),
            (L.t("Traslado", "Transfer"), 2),
        ],
        porMinisterio: [
            (L.t("Enseñanza", "Teaching"), 44),
            (L.t("Música", "Music"), 36),
            (L.t("Ujieres", "Ushers"), 22),
        ],
        expedienteCompleto: 235, expedienteIncompleto: 13,
        altasPorMes: [
            MesAlta(id: 1, mes: L.t("jul","jul"), altas: 2),
            MesAlta(id: 2, mes: L.t("ago","aug"), altas: 3),
        ],
        traslados: [trasladoJavier, trasladoDaniel]
    )

    private static let resumenTodo = InformeResumen(
        totalMiembros: 280,
        periodo: L.t("Todo el historial", "All time"),
        porEstado: [
            (L.t("Activo", "Active"), 248),
            (L.t("Inactivo", "Inactive"), 12),
            (L.t("Visitante", "Visitor"), 8),
            (L.t("Trasladado", "Transferred"), 10),
            (L.t("Baja", "Removed"), 2),
        ],
        porMinisterio: [
            (L.t("Enseñanza", "Teaching"), 52),
            (L.t("Música", "Music"), 44),
            (L.t("Ujieres", "Ushers"), 30),
            (L.t("Niños", "Children"), 28),
            (L.t("Medios", "Media"), 18),
            (L.t("Cocina", "Kitchen"), 14),
        ],
        expedienteCompleto: 265, expedienteIncompleto: 15,
        altasPorMes: [
            MesAlta(id: 1,  mes: "2024", altas: 18),
            MesAlta(id: 2,  mes: "2025", altas: 22),
            MesAlta(id: 3,  mes: "2026", altas: 21),
        ],
        traslados: [trasladoJavier, trasladoDaniel, trasladoRosa]
    )

    // MARK: - Exportación

    var csvExportString: String {
        let r = resumen
        var lines: [String] = []
        lines.append(L.t("Informe de Membresía", "Membership Report") + ",\(r.periodo)")
        lines.append(L.t("Total de miembros", "Total members") + ",\(r.totalMiembros)")
        lines.append("")
        lines.append(L.t("Por Estado", "By Status"))
        lines.append(L.t("Estado,Cantidad", "Status,Count"))
        r.porEstado.forEach { lines.append("\($0.0),\($0.1)") }
        lines.append("")
        lines.append(L.t("Por Ministerio", "By Ministry"))
        lines.append(L.t("Ministerio,Cantidad", "Ministry,Count"))
        r.porMinisterio.forEach { lines.append("\($0.0),\($0.1)") }
        lines.append("")
        lines.append(L.t("Altas por mes", "New per month"))
        lines.append(L.t("Mes,Altas", "Month,New"))
        r.altasPorMes.forEach { lines.append("\($0.mes),\($0.altas)") }
        lines.append("")
        lines.append(L.t("Expediente completo,Expediente incompleto",
                         "File complete,File incomplete"))
        lines.append("\(r.expedienteCompleto),\(r.expedienteIncompleto)")
        lines.append("")
        lines.append(L.t("Movimientos de traslado", "Transfer movements"))
        lines.append(L.t("Folio,Tipo,Persona,Iglesia,Fecha,Estado",
                         "Folio,Type,Person,Church,Date,Status"))
        r.traslados.forEach { t in
            lines.append([t.folio, t.tipoTraslado, t.persona, t.iglesia, t.fecha, t.estado]
                .map { "\"\($0)\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    var textoInforme: String {
        let r = resumen
        var t = ""
        t += L.t("INFORME DE MEMBRESÍA", "MEMBERSHIP REPORT") + "\n"
        t += r.periodo + "\n"
        t += String(repeating: "─", count: 40) + "\n\n"
        t += L.t("Total de miembros: \(r.totalMiembros)", "Total members: \(r.totalMiembros)") + "\n\n"
        t += L.t("MIEMBROS POR ESTADO", "MEMBERS BY STATUS") + "\n"
        r.porEstado.forEach { t += "  \($0.0): \($0.1)\n" }
        t += "\n" + L.t("MIEMBROS POR MINISTERIO", "MEMBERS BY MINISTRY") + "\n"
        r.porMinisterio.forEach { t += "  \($0.0): \($0.1)\n" }
        t += "\n" + L.t("ALTAS POR MES", "NEW PER MONTH") + "\n"
        r.altasPorMes.forEach { t += "  \($0.mes): \($0.altas)\n" }
        t += "\n" + L.t("ESTADO DEL EXPEDIENTE", "FILE STATUS") + "\n"
        t += "  " + L.t("Completo: \(r.expedienteCompleto)", "Complete: \(r.expedienteCompleto)") + "\n"
        t += "  " + L.t("Incompleto: \(r.expedienteIncompleto)", "Incomplete: \(r.expedienteIncompleto)") + "\n"
        t += "\n" + L.t("MOVIMIENTOS DE TRASLADO", "TRANSFER MOVEMENTS") + "\n"
        r.traslados.forEach { t += "  \($0.folio) · \($0.tipoTraslado) · \($0.persona) · \($0.estado)\n" }
        return t
    }

    // MARK: - Traslados mock compartidos

    private static let trasladoJavier = MovimientoTraslado(
        id: 1, folio: "TS-2026-014", tipoTraslado: L.t("Enviado","Sent"),
        persona: "Javier Medina Cruz",
        iglesia: L.t("Iglesia Betel · Saltillo","Iglesia Betel · Saltillo"),
        fecha: "12 ago 2026", estado: L.t("Pendiente de firma","Awaiting signature"))

    private static let trasladoDaniel = MovimientoTraslado(
        id: 2, folio: "TE-2026-007", tipoTraslado: L.t("Recibido","Received"),
        persona: "Daniel Guerra Salinas",
        iglesia: L.t("Iglesia Emanuel · Torreón","Iglesia Emanuel · Torreón"),
        fecha: "6 jul 2026", estado: L.t("Completado","Completed"))

    private static let trasladoRosa = MovimientoTraslado(
        id: 3, folio: "TS-2026-011", tipoTraslado: L.t("Enviado","Sent"),
        persona: "Rosa Elena Vega",
        iglesia: L.t("Iglesia Getsemaní · Reynosa","Iglesia Getsemaní · Reynosa"),
        fecha: "14 mar 2026", estado: L.t("Entregado","Delivered"))
}
