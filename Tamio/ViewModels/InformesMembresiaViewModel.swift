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

    /// **Este informe no sale de la maqueta**, y desde el 7 de septiembre de
    /// 2026 ninguno: un informe que encabeza 248 sobre una lista de siete no es
    /// un informe, son dos pantallas discrepando. Lee del mismo repositorio que
    /// Membresía.
    ///
    /// Aquí decía que "el General sigue leyendo `resumenMes`/`resumenAnio`,
    /// que son constantes escritas a mano". **Ya no era cierto** —el General
    /// usa `resumen`, que cuenta el padrón—, pero las constantes seguían en el
    /// archivo: 210 líneas de personas, ministerios y tres traslados inventados
    /// que nadie llamaba y que el traspaso ya avisaba de no confundir con lo
    /// real. Se fueron con este comentario.
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

    // MARK: Los cuatro filtros combinables del informe de Miembros

    /// Reflejados del web: estado, ministerio, cargo e instrumento. `nil` es
    /// "sin filtrar" —el web usa la cadena "todos" por lo mismo—, así que el
    /// contador del botón no lo cuenta.
    ///
    /// **Combinan con la tarjeta, no la sustituyen.** La tarjeta dice qué
    /// recorte del padrón se mira; estos, qué se busca dentro de él. Elegir
    /// "Incompletos" y luego "música" es la pregunta que hace una secretaria:
    /// a quién de la alabanza le falta expediente.
    var filtroEstado: String?
    var filtroMinisterio: String?
    var filtroCargo: String?
    var filtroInstrumento: String?

    /// Lo que cuenta el globito del botón. La tarjeta NO entra: ya se ve
    /// encendida en su propia fila, y contarla dos veces era el error que
    /// Membresía cometió con el año.
    var filtrosDePadron: Int {
        [filtroEstado, filtroMinisterio, filtroCargo, filtroInstrumento]
            .compactMap { $0 }.count
    }

    func limpiarFiltrosDePadron() {
        filtroEstado = nil; filtroMinisterio = nil
        filtroCargo = nil; filtroInstrumento = nil
    }

    var miembrosFiltrados: [Miembro] {
        miembros.filter { m in
            guard tarjeta.incluye(m, año: añoDelPeriodo) else { return false }
            if let e = filtroEstado, m.estado.clave != e { return false }
            if let mi = filtroMinisterio, !m.ministerios.contains(mi) { return false }
            if let c = filtroCargo, !m.cargos.contains(c) { return false }
            if let i = filtroInstrumento, !m.instrumentos.contains(i) { return false }
            return true
        }
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

    // MARK: - Informe de Seguimiento

    /// Por qué una persona aparece en Seguimiento. Las claves y las reglas son
    /// las del web (`TipoAlerta` en `services/informes/membresia.ts`).
    enum TipoAlerta: String, CaseIterable, Identifiable {
        case rachaServicios, diasSinAsistir, nuevoSeguimiento, expedienteIncompleto
        var id: String { rawValue }

        var etiqueta: String {
            switch self {
            case .rachaServicios:       return L.t("Sin asistir seguido", "Consecutive absences")
            case .diasSinAsistir:       return L.t("Sin venir hace tiempo", "Away for a while")
            case .nuevoSeguimiento:     return L.t("Nuevo por acompañar", "New, needs follow-up")
            case .expedienteIncompleto: return L.t("Expediente incompleto", "Incomplete record")
            }
        }

        /// **Se usa la paleta como está, sin inventar un quinto estado.**
        /// `pendiente` es "pide una acción tuya", y las dos de asistencia la
        /// piden: hay que ir a ver a esa persona. Lo que las distingue es la
        /// etiqueta, no el color; el color dice de qué clase es la cosa.
        var estado: Paleta.Estado {
            switch self {
            case .rachaServicios, .diasSinAsistir: return .pendiente
            case .nuevoSeguimiento:                return .informativo
            case .expedienteIncompleto:            return .terminal
            }
        }
    }

    struct Alerta: Identifiable {
        let miembro: Miembro
        let tipo: TipoAlerta
        /// El dato que la sostiene: la racha, la última visita, lo que falta.
        let detalle: String
        var id: String { "\(miembro.id)-\(tipo.rawValue)" }
    }

    /// **Cuántos servicios seguidos sin venir levantan una alerta.** El web lo
    /// tiene configurable (`umbrales.rachaServicios`, por omisión 3); aquí es
    /// fijo hasta que Ajustes tenga dónde ponerlo, y se nombra para que se vea
    /// que es una decisión y no un 3 suelto en medio de un `filter`.
    static let rachaQueAlerta = 3

    /// **Las alertas pastorales, del padrón.** La pestaña anunciaba "(3)" con
    /// un número escrito a mano y al entrar enseñaba "Próximamente": prometía
    /// tres personas que atender y no daba ninguna.
    ///
    /// Solo se pastorea a quien está en el registro: las bajas no salen.
    /// Una misma persona puede aparecer por dos motivos distintos —eso es
    /// deliberado, son dos cosas que hacer— y por eso el `id` lleva el tipo.
    var alertas: [Alerta] {
        var salida: [Alerta] = []
        for m in miembros where !m.estado.esBaja {
            let racha = m.asistenciaResumen?.rachaSinAsistir ?? 0
            if racha >= Self.rachaQueAlerta {
                salida.append(Alerta(miembro: m, tipo: .rachaServicios,
                                     detalle: L.t("\(racha) servicios seguidos",
                                                  "\(racha) services in a row")))
            } else if let ultima = m.asistenciaResumen?.ultimaVisita, !ultima.isEmpty {
                // Sin racha pero sin venir hace tiempo: el web lo mide en días
                // y en servicios, lo que ocurra primero.
                if let d = Fechas.desdeTexto(ultima),
                   Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0 >= 30 {
                    salida.append(Alerta(miembro: m, tipo: .diasSinAsistir,
                                         detalle: L.t("desde \(Fechas.diaLegible(ultima))",
                                                      "since \(Fechas.diaLegible(ultima))")))
                }
            }
            if m.esNuevo(en: añoSeleccionado) && !m.expedienteCompleto {
                salida.append(Alerta(miembro: m, tipo: .nuevoSeguimiento,
                                     // `fechaIngreso`, la de verdad: `miembroDesde`
                                     // es "Ingresó 2026" y salía "desde Ingresó 2026".
                                     detalle: m.fechaIngreso.isEmpty
                                        ? m.miembroDesde
                                        : L.t("desde \(Fechas.diaLegible(m.fechaIngreso))",
                                              "since \(Fechas.diaLegible(m.fechaIngreso))")))
            }
            if !m.expedienteCompleto {
                let faltan = m.expediente.filter { !$0.completo }.count
                salida.append(Alerta(miembro: m, tipo: .expedienteIncompleto,
                                     detalle: L.t("faltan \(faltan) datos", "\(faltan) fields missing")))
            }
        }
        // Lo que más corre prisa, arriba.
        let orden = TipoAlerta.allCases
        return salida.sorted {
            let a = orden.firstIndex(of: $0.tipo) ?? 0, b = orden.firstIndex(of: $1.tipo) ?? 0
            return a == b ? $0.miembro.nombre < $1.miembro.nombre : a < b
        }
    }

    // MARK: - Resumen según periodo activo

    /// **El General SE CALCULA del padrón, ya no son constantes.**
    ///
    /// Eran cinco `InformeResumen` escritos a mano, uno por periodo, y el de
    /// Año decía 262 miembros y 248 activos mientras el hub decía lo real y el
    /// informe de Miembros —el de al lado, mismo periodo— decía siete. Las
    /// tres cifras se ven a la vez, y era la misma trampa que ya costó una
    /// vuelta al hacer Miembros y Asistencia: **si dos números tienen que
    /// cuadrar, se calculan del MISMO array.**
    ///
    /// Mientras el padrón no ha bajado se devuelven ceros y no la maqueta: un
    /// informe vacío durante medio segundo se entiende; uno con 262 miembros
    /// inventados no.
    var resumen: InformeResumen {
        let año = añoSeleccionado
        let vivos = miembros.filter { !$0.estado.esBaja }

        // Por estado, con los cuatro del registro. Solo se enseñan los que
        // tienen a alguien: cuatro renglones en cero no informan de nada.
        let porEstado = EstadoRegistro.allCases.compactMap { e -> (String, Int)? in
            let n = vivos.filter { $0.estado.registro == e }.count
            return n > 0 ? (e.etiqueta, n) : nil
        }
        let bajas = miembros.filter { $0.estado.esBaja }.count

        // Por ministerio, de los que sirven. Una persona en dos ministerios
        // cuenta en los dos, que es lo que quiere saber quien los coordina.
        var conteo: [String: Int] = [:]
        for m in vivos {
            for clave in m.ministerios { conteo[clave, default: 0] += 1 }
        }
        // En dos pasos y con tipos escritos: en una sola cadena el compilador
        // se rinde ("unable to type-check this expression in reasonable time").
        var porMinisterio: [(String, Int)] = conteo.map { clave, n in
            (Padron.etiquetas([clave]), n)
        }
        porMinisterio.sort { a, b in
            a.1 == b.1 ? a.0 < b.0 : a.1 > b.1
        }

        let completos = vivos.filter(\.expedienteCompleto).count

        // Altas por mes del año elegido, de la fecha en que entraron.
        let altas = (1...12).map { mes in
            MesAlta(id: mes, mes: Self.nombreMes(mes),
                    altas: miembros.filter { Self.entroEn(m: $0, mes: mes, año: año) }.count)
        }

        return InformeResumen(
            totalMiembros: miembros.count,
            periodo: etiquetaPeriodo,
            porEstado: porEstado + (bajas > 0 ? [(L.t("Baja", "Removed"), bajas)] : []),
            porMinisterio: porMinisterio,
            expedienteCompleto: completos,
            expedienteIncompleto: vivos.count - completos,
            // Solo los meses con alguna alta: doce barras en cero no son una
            // gráfica, son ruido.
            altasPorMes: altas.contains { $0.altas > 0 } ? altas : [],
            traslados: trasladosDelPeriodo)
    }

    /// Quien entró en ese mes y año. **`fechaIngreso` y no `miembroDesde`**:
    /// lo segundo es texto para leer —"Ingresó 2026"— y compararlo con
    /// "2026-08" no acierta nunca, así que las altas por mes salían todas en
    /// cero. Se compara por prefijo: parsear para volver a comparar solo añade
    /// un sitio donde perder un día por el huso.
    private static func entroEn(m: Miembro, mes: Int, año: Int) -> Bool {
        m.fechaIngreso.hasPrefix(String(format: "%04d-%02d", año, mes))
    }

    /// Los traslados del padrón: quien se fue con motivo "traslado" y quien
    /// llegó recibido. Salen de las fichas, no de una lista aparte.
    ///
    /// **El folio y la iglesia iban en blanco.** Los dos estaban en el aparato
    /// —el folio y el destino en `trasladoSalida`, la iglesia de origen en el
    /// `iglesiaAnterior` del propio miembro—, y esta función los ponía como
    /// cadena vacía: la tabla del informe pintaba una columna de folio de 110
    /// puntos vacía y otra de iglesia también, en un documento que se comparte
    /// con la junta.
    private var trasladosDelPeriodo: [MovimientoTraslado] {
        let año = añoSeleccionado
        let salidas = miembros.filter {
            $0.estado.baja?.motivo == "traslado"
            && ($0.estado.baja?.fecha.hasPrefix(String(año)) ?? false)
        }.map { m in
            MovimientoTraslado(id: abs(m.id.hashValue),
                               folio: m.trasladoSalida?.folio ?? "",
                               sentido: .salida,
                               persona: m.nombre,
                               iglesia: m.trasladoSalida?.iglesiaDestino ?? "",
                               fecha: Fechas.diaLegible(m.estado.baja?.fecha ?? ""),
                               estado: L.t("Completado", "Completed"))
        }
        // **Una entrada no tiene folio y no es un olvido**: el expediente lo
        // abre y lo numera la iglesia que ENVÍA. Lo que sí consta es de dónde
        // vino, que es `iglesiaAnterior` — el mismo campo que define
        // `esRecibido`, así que quien esté en esta lista lo tiene.
        let entradas = miembros.filter { $0.esRecibido && $0.esNuevo(en: año) }.map { m in
            MovimientoTraslado(id: abs(m.id.hashValue) &+ 1, folio: "",
                               sentido: .entrada,
                               persona: m.nombre, iglesia: m.iglesiaAnterior,
                               fecha: Fechas.diaLegible(m.fechaIngreso),
                               estado: L.t("Completado", "Completed"))
        }
        return salidas + entradas
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

}
