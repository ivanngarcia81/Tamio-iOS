import Foundation

protocol ServiciosRepository {
    func proximos() async throws -> [Servicio]
}

struct MockServiciosRepository: ServiciosRepository {
    func proximos() async throws -> [Servicio] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return Self.servicios
    }

    private static func historial() -> [AsistenciaServicio] {
        [
            AsistenciaServicio(id: "1", fecha: L.fecha("2 ago"),  presentes: 118, total: 140),
            AsistenciaServicio(id: "2", fecha: L.fecha("9 ago"),  presentes: 132, total: 140),
            AsistenciaServicio(id: "3", fecha: L.fecha("16 ago"), presentes: 109, total: 140),
            AsistenciaServicio(id: "4", fecha: L.fecha("23 ago"), presentes: 128, total: 140),
        ]
    }

    private static var servicios: [Servicio] {
        [
            Servicio(id: "1",
                     diaSemana: L.diaSemana("DOM"), numDia: "23",
                     titulo: L.t("Culto matutino", "Morning service"),
                     hora: "10:00",
                     lugar: L.t("templo principal", "main sanctuary"),
                     estadoRoster: .completo,
                     roster: [
                        AsignacionRoster(id: 1, rol: L.t("Predicación", "Preaching"),  persona: L.t("Pastor Abel Ramos", "Pastor Abel Ramos"),  extras: 0),
                        AsignacionRoster(id: 2, rol: L.t("Alabanza", "Worship"),       persona: L.t("Lucía Márquez", "Lucía Márquez"),          extras: 4),
                        AsignacionRoster(id: 3, rol: L.t("Ujieres", "Ushers"),         persona: L.t("Jorge Hernández", "Jorge Hernández"),      extras: 2),
                        AsignacionRoster(id: 4, rol: L.t("Ofrenda", "Offering"),       persona: L.t("Pedro Salas", "Pedro Salas"),              extras: 0),
                        AsignacionRoster(id: 5, rol: L.t("Sonido", "Sound"),           persona: nil,                                           extras: 0),
                     ],
                     historial: historial(),
                     orden: [
                        PuntoOrden(id: 1, hora: "10:00", descripcion: L.t("Bienvenida y oración", "Welcome and prayer")),
                        PuntoOrden(id: 2, hora: "10:10", descripcion: L.t("Alabanza congregacional", "Congregational worship")),
                        PuntoOrden(id: 3, hora: "10:35", descripcion: L.t("Ofrenda y avisos", "Offering and announcements")),
                        PuntoOrden(id: 4, hora: "10:45", descripcion: L.t("Predicación · Hechos 2", "Preaching · Acts 2")),
                     ]),
            Servicio(id: "2",
                     diaSemana: L.diaSemana("DOM"), numDia: "23",
                     titulo: L.t("Culto vespertino", "Evening service"),
                     hora: "18:00",
                     lugar: L.t("templo principal", "main sanctuary"),
                     estadoRoster: .faltaUjier,
                     roster: [
                        AsignacionRoster(id: 6, rol: L.t("Predicación", "Preaching"), persona: L.t("Hno. Ramón Flores", "Bro. Ramón Flores"), extras: 0),
                        AsignacionRoster(id: 7, rol: L.t("Alabanza", "Worship"),      persona: L.t("Equipo alabanza", "Worship team"),        extras: 3),
                        AsignacionRoster(id: 8, rol: L.t("Ujieres", "Ushers"),        persona: nil,                                          extras: 0),
                        AsignacionRoster(id: 9, rol: L.t("Sonido", "Sound"),          persona: L.t("Carlos Rivas", "Carlos Rivas"),           extras: 0),
                     ],
                     historial: historial(),
                     orden: [
                        PuntoOrden(id: 5, hora: "18:00", descripcion: L.t("Oración de apertura", "Opening prayer")),
                        PuntoOrden(id: 6, hora: "18:10", descripcion: L.t("Alabanza y adoración", "Praise and worship")),
                        PuntoOrden(id: 7, hora: "18:40", descripcion: L.t("Predicación", "Preaching")),
                     ]),
            Servicio(id: "3",
                     diaSemana: L.diaSemana("MIÉ"), numDia: "26",
                     titulo: L.t("Reunión de oración", "Prayer meeting"),
                     hora: "19:30",
                     lugar: L.t("salón anexo", "annex hall"),
                     estadoRoster: .sinAsignar,
                     roster: [
                        AsignacionRoster(id: 10, rol: L.t("Dirigente", "Leader"), persona: nil, extras: 0),
                     ],
                     historial: historial(),
                     orden: [
                        PuntoOrden(id: 8, hora: "19:30", descripcion: L.t("Apertura y lectura bíblica", "Opening and Bible reading")),
                        PuntoOrden(id: 9, hora: "19:45", descripcion: L.t("Peticiones y oración en grupos", "Prayer requests and group prayer")),
                     ]),
            Servicio(id: "4",
                     diaSemana: L.diaSemana("DOM"), numDia: "30",
                     titulo: L.t("Santa cena", "Lord's Supper"),
                     hora: "10:00",
                     lugar: L.t("templo principal", "main sanctuary"),
                     estadoRoster: .parcial,
                     roster: [
                        AsignacionRoster(id: 11, rol: L.t("Predicación", "Preaching"),   persona: L.t("Pastor Abel Ramos", "Pastor Abel Ramos"), extras: 0),
                        AsignacionRoster(id: 12, rol: L.t("Alabanza", "Worship"),        persona: L.t("Lucía Márquez", "Lucía Márquez"),         extras: 2),
                        AsignacionRoster(id: 13, rol: L.t("Ujieres", "Ushers"),          persona: nil,                                          extras: 0),
                        AsignacionRoster(id: 14, rol: L.t("Ministración cena", "Supper ministers"), persona: nil,                               extras: 0),
                     ],
                     historial: historial(),
                     orden: [
                        PuntoOrden(id: 10, hora: "10:00", descripcion: L.t("Bienvenida y alabanza", "Welcome and worship")),
                        PuntoOrden(id: 11, hora: "10:30", descripcion: L.t("Predicación", "Preaching")),
                        PuntoOrden(id: 12, hora: "11:00", descripcion: L.t("Celebración de la Santa Cena", "Lord's Supper celebration")),
                     ]),
        ]
    }
}

// MARK: - La asistencia, contada

import GRDB

/// Un culto con su lista tomada, tal como lo necesita quien cuenta.
struct CultoConLista: Identifiable, Hashable {
    let id: String
    let fecha: String          // "YYYY-MM-DD"
    let tipo: String
    /// Solo de quien tenía ficha: los visitantes sin ella van aparte.
    let presentes: Int
    let enLista: Int
}

/// Lo que se guarda de una persona en un culto. `razon` y `seguimiento` solo
/// significan algo con `presente` en falso; al marcar presente se limpian,
/// como hace el web.
struct MarcaAsistencia: Hashable {
    let miembroId: String
    let nombre: String
    var presente: Bool
    var razon: String = ""
    var razonOtra: String = ""
    var seguimiento: Bool = false
}

protocol AsistenciaRepository {
    func cultos(desde: String, hasta: String) async throws -> [CultoConLista]
    func lista(culto: String) async throws -> [MarcaAsistencia]
    /// Guarda por DIFERENCIAS y no borrando y reinsertando, como el web: así
    /// el id de cada pareja (culto, persona) se conserva entre guardados y la
    /// baja de quien se quitó viaja como lápida en vez de perderse.
    func guardarLista(culto: String, _ marcas: [MarcaAsistencia]) async throws
    /// Lo de cada persona en el periodo, para la ficha del padrón.
    func porMiembro(desde: String, hasta: String) async throws -> [String: AsistenciaMiembro]
    /// Lo de la congregación, para la pestaña Asistencia.
    func resumen(desde: String, hasta: String) async throws -> AsistenciaResumen
}

/// La asistencia desde la base del teléfono. **Nada de esto se guarda: se
/// cuenta.** La racha, la última visita y el porcentaje salen de las filas de
/// `servicioAsistencia`, que es la única versión de la verdad.
struct OfflineAsistenciaRepository: AsistenciaRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func cultos(desde: String, hasta: String) async throws -> [CultoConLista] {
        try await cola.read { db in
            try Row.fetchAll(db, sql: """
                select s.id, s.fecha, s.tipo,
                       sum(case when a.presente and not a.borrado then 1 else 0 end) as presentes,
                       sum(case when a.borrado then 0 else 1 end) as enLista
                  from servicio s
                  left join servicioAsistencia a on a.servicioId = s.id
                 where s.borrado = 0 and s.fecha >= ? and s.fecha <= ?
                 group by s.id
                 order by s.fecha desc
                """, arguments: [desde, hasta])
                .map { CultoConLista(id: $0["id"], fecha: $0["fecha"], tipo: $0["tipo"],
                                     presentes: $0["presentes"] ?? 0, enLista: $0["enLista"] ?? 0) }
        }
    }

    func lista(culto: String) async throws -> [MarcaAsistencia] {
        try await cola.read { db in
            try AsistenciaFila
                .filter(Column("servicioId") == culto && Column("borrado") == false)
                .fetchAll(db)
                .map { MarcaAsistencia(miembroId: $0.miembroId, nombre: $0.nombreSnapshot,
                                       presente: $0.presente, razon: $0.razon,
                                       razonOtra: $0.razonOtra, seguimiento: $0.seguimiento) }
        }
    }

    func guardarLista(culto: String, _ marcas: [MarcaAsistencia]) async throws {
        try await cola.write { db in
            let previas = try AsistenciaFila
                .filter(Column("servicioId") == culto)
                .fetchAll(db)
            let porMiembro = Dictionary(previas.map { ($0.miembroId, $0) }, uniquingKeysWith: { a, _ in a })
            let quedan = Set(marcas.map(\.miembroId))

            for m in marcas {
                // Presente borra la razón y el seguimiento: no se puede estar
                // aquí y tener un motivo para no estar.
                var fila = AsistenciaFila(
                    id: porMiembro[m.miembroId]?.id ?? UUID().uuidString,
                    servicioId: culto, miembroId: m.miembroId, presente: m.presente,
                    razon: m.presente ? "" : m.razon,
                    razonOtra: m.presente ? "" : m.razonOtra,
                    seguimiento: m.presente ? false : m.seguimiento,
                    nombreSnapshot: m.nombre,
                    actualizadoEn: porMiembro[m.miembroId]?.actualizadoEn, borrado: false)
                try fila.save(db)
                try Self.encolar(db, id: fila.id,
                                 operacion: porMiembro[m.miembroId] == nil ? .crear : .actualizar)
            }
            // Quien salió de la lista: lápida, no borrado, o el otro aparato
            // no se entera de que se fue.
            for vieja in previas where !quedan.contains(vieja.miembroId) && !vieja.borrado {
                var f = vieja; f.borrado = true
                try f.update(db)
                try Self.encolar(db, id: f.id, operacion: .eliminar)
            }
        }
    }

    func porMiembro(desde: String, hasta: String) async throws -> [String: AsistenciaMiembro] {
        try await cola.read { db in
            // Del más reciente al más antiguo: así la racha se corta en cuanto
            // aparece el primer culto al que sí vino.
            let filas = try Row.fetchAll(db, sql: """
                select a.miembroId, a.presente, s.fecha
                  from servicioAsistencia a
                  join servicio s on s.id = a.servicioId
                 where a.borrado = 0 and s.borrado = 0 and s.fecha >= ? and s.fecha <= ?
                 order by s.fecha desc
                """, arguments: [desde, hasta])

            var presentes: [String: Int] = [:]
            var totales: [String: Int] = [:]
            var racha: [String: Int] = [:]
            var rachaAbierta: Set<String> = []
            var ultima: [String: String] = [:]

            for f in filas {
                let id: String = f["miembroId"]
                let vino: Bool = f["presente"]
                totales[id, default: 0] += 1
                if vino {
                    presentes[id, default: 0] += 1
                    if ultima[id] == nil { ultima[id] = f["fecha"] }
                    rachaAbierta.insert(id)   // la racha ya no puede crecer
                } else if !rachaAbierta.contains(id) {
                    racha[id, default: 0] += 1
                }
            }
            return totales.reduce(into: [String: AsistenciaMiembro]()) { r, par in
                let (id, total) = par
                r[id] = AsistenciaMiembro(presentes: presentes[id] ?? 0,
                                          servicios: total,
                                          rachaSinAsistir: racha[id] ?? 0,
                                          ultimaVisita: ultima[id])
            }
        }
    }

    func resumen(desde: String, hasta: String) async throws -> AsistenciaResumen {
        let cultos = try await cultos(desde: desde, hasta: hasta)
        guard !cultos.isEmpty else {
            return AsistenciaResumen(promedioPct: 0, serviciosPeriodo: 0, presentesPromedio: 0,
                                     mejorServicio: "—", meses: [], porTipo: [])
        }
        let presentes = cultos.map(\.presentes)
        let enLista = cultos.map(\.enLista).reduce(0, +)
        let totalPresentes = presentes.reduce(0, +)
        let promedioPct = enLista > 0 ? Int((Double(totalPresentes) / Double(enLista) * 100).rounded()) : 0
        let mejor = cultos.max { $0.presentes < $1.presentes }

        // Por mes, del más antiguo al más reciente, que es como se lee una
        // gráfica.
        var porMes: [String: (Int, Int)] = [:]
        for c in cultos {
            let mes = String(c.fecha.prefix(7))
            porMes[mes, default: (0, 0)].0 += c.presentes
            porMes[mes, default: (0, 0)].1 += c.enLista
        }
        let meses = porMes.keys.sorted().map { clave -> MesAsistenciaCongregacion in
            let (p, t) = porMes[clave] ?? (0, 0)
            let d = Fechas.desdeTextoFlexible("\(clave)-01")
            return MesAsistenciaCongregacion(mes: d.map { L.mesCorto($0) } ?? clave,
                                             presentes: p, enRoster: t)
        }

        var porTipo: [String: (Int, Int)] = [:]
        for c in cultos {
            porTipo[c.tipo, default: (0, 0)].0 += c.presentes
            porTipo[c.tipo, default: (0, 0)].1 += 1
        }
        let tipos = porTipo
            .map { TipoAsistencia(tipo: Cultos.etiqueta($0.key),
                                  promedio: $0.value.1 > 0 ? $0.value.0 / $0.value.1 : 0) }
            .sorted { $0.promedio > $1.promedio }

        return AsistenciaResumen(
            promedioPct: promedioPct,
            serviciosPeriodo: cultos.count,
            presentesPromedio: totalPresentes / cultos.count,
            mejorServicio: mejor.map { "\($0.presentes) · \(Fechas.diaLegible($0.fecha))" } ?? "—",
            meses: meses,
            porTipo: tipos)
    }

    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == "asistencia" && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == "asistencia" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "asistencia", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

/// Los tipos de culto del app web, con sus claves.
enum Cultos {
    static let tipos = ["dominical", "oracion", "estudio", "jovenes", "damas",
                        "caballeros", "vigilia", "evangelistico", "especial", "otro"]

    static func etiqueta(_ clave: String) -> String {
        switch clave {
        case "dominical":     return L.t("Culto dominical", "Sunday service")
        case "oracion":       return L.t("Reunión de oración", "Prayer meeting")
        case "estudio":       return L.t("Estudio bíblico", "Bible study")
        case "jovenes":       return L.t("Jóvenes", "Youth")
        case "damas":         return L.t("Damas", "Women")
        case "caballeros":    return L.t("Caballeros", "Men")
        case "vigilia":       return L.t("Vigilia", "Vigil")
        case "evangelistico": return L.t("Evangelístico", "Evangelistic")
        case "especial":      return L.t("Especial", "Special")
        case "otro":          return L.t("Otro", "Other")
        default:              return clave
        }
    }
}

/// La asistencia de la maqueta. Almacén ESTÁTICO para que lo que se marca en
/// el modo revisión siga ahí al volver a abrir la hoja, como en los demás
/// mocks del proyecto.
///
/// Los cultos vienen sembrados —cuatro domingos y dos reuniones de oración—
/// porque una pantalla de asistencia sin cultos no se puede enseñar, y las
/// listas nacen vacías: lo que se está probando es tomarlas.
struct MockAsistenciaRepository: AsistenciaRepository {
    private static var cultosSembrados: [CultoConLista] = {
        let hoy = Date()
        let cal = Calendar.current
        return (0..<6).map { i in
            let d = cal.date(byAdding: .day, value: -7 * i, to: hoy) ?? hoy
            return CultoConLista(id: "culto-\(i)", fecha: Fechas.claveDia(d),
                                 tipo: i % 3 == 1 ? "oracion" : "dominical",
                                 presentes: 0, enLista: 0)
        }
    }()
    private static var listas: [String: [MarcaAsistencia]] = [:]

    func cultos(desde: String, hasta: String) async throws -> [CultoConLista] {
        Self.cultosSembrados
            .filter { $0.fecha >= desde && $0.fecha <= hasta }
            .map { c in
                let l = Self.listas[c.id] ?? []
                return CultoConLista(id: c.id, fecha: c.fecha, tipo: c.tipo,
                                     presentes: l.filter(\.presente).count, enLista: l.count)
            }
    }

    func lista(culto: String) async throws -> [MarcaAsistencia] { Self.listas[culto] ?? [] }

    func guardarLista(culto: String, _ marcas: [MarcaAsistencia]) async throws {
        Self.listas[culto] = marcas.map { m in
            var x = m
            if x.presente { x.razon = ""; x.razonOtra = ""; x.seguimiento = false }
            return x
        }
    }

    func porMiembro(desde: String, hasta: String) async throws -> [String: AsistenciaMiembro] {
        [:]   // La ficha de la maqueta trae sus propios números.
    }

    func resumen(desde: String, hasta: String) async throws -> AsistenciaResumen {
        await MockMembresiaRepository().asistenciaResumen()
    }
}

func repositorioAsistencia() -> AsistenciaRepository {
    ModoRevision.sinLogin ? MockAsistenciaRepository() : OfflineAsistenciaRepository()
}
