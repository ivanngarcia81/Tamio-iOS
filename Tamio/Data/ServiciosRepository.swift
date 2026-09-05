import Foundation

protocol ServiciosRepository {
    func proximos() async throws -> [Servicio]
    /// Alta o edición: la misma función, como en el padrón. Guarda el culto y
    /// sus dos hijas —puestos y orden— de una vez.
    func guardar(_ s: Servicio) async throws
}

struct MockServiciosRepository: ServiciosRepository {
    private static var almacen: [Servicio] = MockServiciosRepository.servicios

    func proximos() async throws -> [Servicio] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return Self.almacen
    }

    func guardar(_ s: Servicio) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == s.id }) { Self.almacen[i] = s }
        else { Self.almacen.insert(s, at: 0) }
    }

    private static func historial() -> [AsistenciaServicio] {
        [
            AsistenciaServicio(id: "1", fecha: L.fecha("2 ago"),  presentes: 118, total: 140),
            AsistenciaServicio(id: "2", fecha: L.fecha("9 ago"),  presentes: 132, total: 140),
            AsistenciaServicio(id: "3", fecha: L.fecha("16 ago"), presentes: 109, total: 140),
            AsistenciaServicio(id: "4", fecha: L.fecha("23 ago"), presentes: 128, total: 140),
        ]
    }

    private static func puesto(_ clave: String, _ nombre: String = "") -> PuestoServicio {
        PuestoServicio(id: "\(clave)-\(UUID().uuidString.prefix(4))", puesto: clave,
                       nombre: nombre, miembroId: nil)
    }

    private static func punto(_ pos: Int, _ hora: String, _ titulo: String) -> PuntoOrden {
        PuntoOrden(id: "o\(pos)-\(UUID().uuidString.prefix(4))", posicion: pos,
                   hora: hora, titulo: titulo, encargado: "")
    }

    /// Dos cultos del domingo pasado, ya con forma de fila: fecha y tipo, y el
    /// titular se calcula.
    private static var servicios: [Servicio] {
        let cal = Calendar.current
        let domingo = cal.date(byAdding: .day, value: -(cal.component(.weekday, from: Date()) - 1),
                               to: Date()) ?? Date()

        var matutino = Servicio(id: "1")
        matutino.fecha = Fechas.claveDia(domingo)
        matutino.tipo = "dominical"
        matutino.dirige = "Lucía Márquez"
        matutino.predica = L.t("Pastor Abel Ramos", "Pastor Abel Ramos")
        matutino.tituloMensaje = L.t("Un pueblo que ora", "A praying people")
        matutino.textoBiblico = "Hechos 2:42-47"
        matutino.puestos = [
            puesto("predicacion", L.t("Pastor Abel Ramos", "Pastor Abel Ramos")),
            puesto("alabanza", "Lucía Márquez"),
            puesto("ujieres", "Jorge Hernández"),
            puesto("ofrenda", "Pedro Salas"),
            puesto("sonido"),
        ]
        matutino.orden = [
            punto(0, "10:00", L.t("Bienvenida y oración", "Welcome and prayer")),
            punto(1, "10:10", L.t("Alabanza congregacional", "Congregational worship")),
            punto(2, "10:35", L.t("Ofrenda y avisos", "Offering and announcements")),
            punto(3, "10:45", L.t("Predicación · Hechos 2", "Preaching · Acts 2")),
        ]
        matutino.historial = historial()

        var oracion = Servicio(id: "2")
        oracion.fecha = Fechas.claveDia(cal.date(byAdding: .day, value: -3, to: Date()) ?? Date())
        oracion.tipo = "oracion"
        oracion.dirige = L.t("Hno. Ramón Flores", "Bro. Ramón Flores")
        oracion.puestos = [puesto("oracion", L.t("Hno. Ramón Flores", "Bro. Ramón Flores"))]
        oracion.orden = [punto(0, "19:00", L.t("Oración de apertura", "Opening prayer"))]
        oracion.historial = historial()

        return [matutino, oracion]
    }
}

/// Los cultos desde la base del teléfono, con sus puestos y su orden.
struct OfflineServiciosRepository: ServiciosRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func proximos() async throws -> [Servicio] {
        try await cola.read { db in
            let filas = try ServicioFila
                .filter(Column("borrado") == false)
                .order(Column("fecha").desc)
                .fetchAll(db)
            let puestos = try ServicioPuestoFila.filter(Column("borrado") == false).fetchAll(db)
            let orden = try ServicioOrdenFila.filter(Column("borrado") == false).fetchAll(db)

            var porCulto: [String: [PuestoServicio]] = [:]
            for p in puestos {
                porCulto[p.servicioId, default: []].append(
                    PuestoServicio(id: p.id, puesto: p.puesto, nombre: p.nombre, miembroId: p.miembroId))
            }
            var ordenPorCulto: [String: [PuntoOrden]] = [:]
            for o in orden {
                ordenPorCulto[o.servicioId, default: []].append(
                    PuntoOrden(id: o.id, posicion: o.posicion, hora: o.hora,
                               titulo: o.titulo, encargado: o.encargado))
            }
            return filas.map { f in
                var s = Servicio(id: f.id)
                s.fecha = f.fecha; s.tipo = f.tipo
                s.dirige = f.dirige; s.predica = f.predica
                s.tituloMensaje = f.tituloMensaje; s.textoBiblico = f.textoBiblico
                s.resumenMensaje = f.resumenMensaje
                s.participaciones = Padron.lista(f.participaciones)
                s.temaEscuela = f.temaEscuela; s.maestroEscuela = f.maestroEscuela
                s.visitantes = MiembroFila.lista(f.visitantes)
                s.ninos = f.ninos; s.jovenes = f.jovenes; s.adultos = f.adultos
                s.eventos = f.eventos
                s.puestos = porCulto[f.id] ?? []
                s.orden = (ordenPorCulto[f.id] ?? []).sorted { $0.posicion < $1.posicion }
                return s
            }
        }
    }

    func guardar(_ s: Servicio) async throws {
        try await cola.write { db in
            let previa = try ServicioFila.fetchOne(db, key: s.id)
            try ServicioFila(id: s.id, fecha: s.fecha, tipo: s.tipo,
                             dirige: s.dirige, predica: s.predica,
                             tituloMensaje: s.tituloMensaje, textoBiblico: s.textoBiblico,
                             resumenMensaje: s.resumenMensaje,
                             participaciones: Padron.json(s.participaciones),
                             temaEscuela: s.temaEscuela, maestroEscuela: s.maestroEscuela,
                             visitantes: MiembroFila.json(s.visitantes),
                             ninos: s.ninos, jovenes: s.jovenes, adultos: s.adultos,
                             eventos: s.eventos, actualizadoEn: previa?.actualizadoEn,
                             borrado: false).save(db)
            try Self.encolar(db, entidad: "culto", id: s.id,
                             operacion: previa == nil ? .crear : .actualizar)

            // Las hijas, por diferencias: el que se quitó queda como lápida,
            // o el otro aparato no se entera de que ya no está. Se escriben
            // sueltas y no con un genérico: dos funciones de ocho líneas se
            // leen mejor que una que tiene que preguntar de qué tipo es cada
            // fila para saber su id.
            let puestosPrevios = try ServicioPuestoFila
                .filter(Column("servicioId") == s.id).fetchAll(db)
            let puestosQuedan = Set(s.puestos.map(\.id))
            for p in s.puestos {
                let existia = puestosPrevios.contains { $0.id == p.id }
                try ServicioPuestoFila(id: p.id, servicioId: s.id, puesto: p.puesto,
                                       nombre: p.nombre, miembroId: p.miembroId,
                                       actualizadoEn: puestosPrevios.first { $0.id == p.id }?.actualizadoEn,
                                       borrado: false).save(db)
                try Self.encolar(db, entidad: "puesto", id: p.id,
                                 operacion: existia ? .actualizar : .crear)
            }
            for vieja in puestosPrevios where !puestosQuedan.contains(vieja.id) && !vieja.borrado {
                var f = vieja; f.borrado = true
                try f.update(db)
                try Self.encolar(db, entidad: "puesto", id: f.id, operacion: .eliminar)
            }

            let ordenPrevio = try ServicioOrdenFila
                .filter(Column("servicioId") == s.id).fetchAll(db)
            let ordenQueda = Set(s.orden.map(\.id))
            for o in s.orden {
                let existia = ordenPrevio.contains { $0.id == o.id }
                try ServicioOrdenFila(id: o.id, servicioId: s.id, posicion: o.posicion,
                                      hora: o.hora, titulo: o.titulo, encargado: o.encargado,
                                      actualizadoEn: ordenPrevio.first { $0.id == o.id }?.actualizadoEn,
                                      borrado: false).save(db)
                try Self.encolar(db, entidad: "orden", id: o.id,
                                 operacion: existia ? .actualizar : .crear)
            }
            for vieja in ordenPrevio where !ordenQueda.contains(vieja.id) && !vieja.borrado {
                var f = vieja; f.borrado = true
                try f.update(db)
                try Self.encolar(db, entidad: "orden", id: f.id, operacion: .eliminar)
            }
        }
    }

    private static func encolar(_ db: Database, entidad: String, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == entidad && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == entidad && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: entidad, registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

func repositorioServicios() -> ServiciosRepository {
    ModoRevision.sinLogin ? MockServiciosRepository() : OfflineServiciosRepository()
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
/// Las listas nacen vacías: lo que se está probando es tomarlas.
struct MockAsistenciaRepository: AsistenciaRepository {
    private static var listas: [String: [MarcaAsistencia]] = [:]

    /// Los cultos de la maqueta son los de `MockServiciosRepository`: uno solo
    /// en los dos sitios, o la lista se tomaría sobre un culto que la pantalla
    /// de Servicios no enseña.
    func cultos(desde: String, hasta: String) async throws -> [CultoConLista] {
        let servicios = (try? await MockServiciosRepository().proximos()) ?? []
        return servicios
            .filter { $0.fecha >= desde && $0.fecha <= hasta }
            .map { s in
                let l = Self.listas[s.id] ?? []
                return CultoConLista(id: s.id, fecha: s.fecha, tipo: s.tipo,
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
