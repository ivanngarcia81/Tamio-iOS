import Foundation
import GRDB

protocol AgendaRepository {
    /// **Las actividades DE UN MES, no todas.** Iba sin argumento y la vista
    /// las repartía por día del mes, así que al pasar a octubre seguía viendo
    /// las de septiembre colocadas en los mismos números. Mientras los eventos
    /// no tenían fecha entera daba igual; con fecha, no.
    func eventos(mes: Date) async throws -> [EventoAgenda]
    /// Alta o edición, la misma función: lo que llega es la actividad entera y
    /// el repositorio decide. Igual que `MembresiaRepository.guardar`.
    func guardar(_ e: EventoAgenda) async throws
    /// Borra de verdad para quien mira, lápida para quien sincroniza.
    func eliminar(id: String) async throws
}

/// **El hub de Secretaría necesita más que la lista: necesita las cuentas.**
///
/// Las llevaba escritas a mano —"MAÑANA · 19:00", "VIE 21", "En agosto 7"—
/// copiadas del handoff de agosto. En septiembre eso decía que el consejo de
/// ancianos era mañana viernes 21 estando a domingo 6, y anunciaba agosto dos
/// filas debajo de una Agenda que ya encabezaba septiembre. Un compromiso que
/// miente en la primera pantalla es peor que no enseñarlo.
///
/// Todo lo de aquí SE CALCULA de `eventos()` contra la fecha de hoy, así que
/// no puede volver a quedarse en un mes viejo, y el día que exista un
/// `OfflineAgendaRepository` heredará las cuentas sin escribir una línea.
struct ResumenAgenda {
    /// Los que vienen, del más cercano al más lejano. Solo sin completar: un
    /// compromiso ya hecho no es un compromiso.
    let proximos: [CompromisoProximo]
    /// Sin completar del mes. Es el número que el hub anuncia en su fila de
    /// Agenda y el que resume la tarjeta.
    let pendientes: Int
    /// Sin completar que caen en la semana en curso.
    let estaSemana: Int

    var proximo: CompromisoProximo? { proximos.first }

    static let vacio = ResumenAgenda(proximos: [], pendientes: 0, estaSemana: 0)
}

/// Un compromiso con su fecha ya resuelta. La semilla guarda el día del mes y
/// nada más —vale para el mes que sea, ver `AgendaViewModel`—, así que el día
/// de la semana hay que calcularlo, no leerlo.
struct CompromisoProximo: Identifiable {
    let evento: EventoAgenda
    let fecha: Date
    /// Días entre hoy y el compromiso. 0 = hoy, 1 = mañana.
    let enDias: Int

    var id: String { evento.id }

    /// `"VIE"` · `"FRI"`. **Con el calendario del aparato, no en UTC**: esta
    /// fecha se ARMA aquí a partir del día del mes y de hoy, no se lee de un
    /// texto guardado, así que no le aplica el aviso de `Fechas.diaSemanaCorto`.
    var diaSemana: String {
        L.formateador("EEE").string(from: fecha).uppercased()
    }

    var numDia: String { String(Calendar.current.component(.day, from: fecha)) }

    /// `"19:00 mañana"` · `"todo el día"`. Lo cercano se dice con palabras,
    /// que es como lo diría una secretaria; a partir de pasado mañana la
    /// palabra no aporta y basta la hora, porque la fila ya lleva su fecha.
    var cuando: String {
        let relativo: String? = switch enDias {
        case 0: L.t("hoy", "today")
        case 1: L.t("mañana", "tomorrow")
        default: nil
        }
        guard let hora = evento.hora else {
            return relativo ?? L.t("todo el día", "all day")
        }
        guard let relativo else { return hora }
        return "\(hora) \(relativo)"
    }

    /// `"MAÑANA · 19:00"`, la línea que encabeza la tarjeta.
    var titularCorto: String {
        let cuando = switch enDias {
        case 0: L.t("HOY", "TODAY")
        case 1: L.t("MAÑANA", "TOMORROW")
        default: "\(diaSemana) \(numDia)"
        }
        guard let hora = evento.hora else { return cuando }
        return "\(cuando) · \(hora)"
    }
}

extension AgendaRepository {
    /// Las cuentas del hub, calculadas de `eventos()`. Va en la extensión del
    /// protocolo a propósito: es aritmética sobre la lista, no algo que cada
    /// implementación deba repetir a su manera y con su propio criterio.
    func resumen(hoy: Date = Date()) async -> ResumenAgenda {
        let todos = (try? await eventos(mes: hoy)) ?? []
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: hoy)
        let inicioDeHoy = cal.startOfDay(for: hoy)

        // Sin completar: lo hecho no es un compromiso. Mismo criterio que la
        // fila de Agenda del hub, para que las dos cifras no discrepen.
        let pendientes = todos.filter { !$0.completado }

        let conFecha: [CompromisoProximo] = pendientes.compactMap { e in
            guard let fecha = Fechas.desdeTexto(e.fecha) else { return nil }
            // La fecha guardada se parsea en UTC; para restarla contra hoy hay
            // que traerla al día que representa en el calendario del aparato,
            // o "mañana" se convierte en "hoy" al oeste de Greenwich.
            var c = comps
            c.year = Fechas.calendarioUTC.component(.year, from: fecha)
            c.month = Fechas.calendarioUTC.component(.month, from: fecha)
            c.day = Fechas.calendarioUTC.component(.day, from: fecha)
            guard let local = cal.date(from: c) else { return nil }
            let dias = cal.dateComponents([.day], from: inicioDeHoy,
                                          to: cal.startOfDay(for: local)).day ?? 0
            return CompromisoProximo(evento: e, fecha: local, enDias: dias)
        }

        return ResumenAgenda(
            // Los de hoy en adelante, y dentro del mismo día los de todo el
            // día antes que los que tienen hora.
            proximos: conFecha
                .filter { $0.enDias >= 0 }
                .sorted { ($0.enDias, $0.evento.hora ?? "") < ($1.enDias, $1.evento.hora ?? "") },
            pendientes: pendientes.count,
            estaSemana: conFecha.filter {
                cal.isDate($0.fecha, equalTo: hoy, toGranularity: .weekOfYear)
            }.count)
    }
}

/// La agenda de verdad: tabla `agenda` de la base local, y de ahí a
/// `public.agenda` por el motor de sincronización.
///
/// **El `estado` es la fuente de si algo está hecho.** El web no tiene un
/// booleano `completado`: tiene `estado` con cinco valores, y "completada" es
/// uno de ellos. Aquí se traduce en las dos direcciones en vez de guardar los
/// dos y dejar que se contradigan. Una actividad cancelada NO cuenta como
/// completada —no se hizo— pero tampoco es un compromiso que siga en pie, así
/// que a efectos del hub se da por cerrada igual.
struct OfflineAgendaRepository: AgendaRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func eventos(mes: Date) async throws -> [EventoAgenda] {
        // Por prefijo de texto y no por rango de fechas: `fecha` es
        // "YYYY-MM-DD" y está indexada, así que "2026-09" acota el mes sin
        // convertir nada y sin que un huso horario pueda correr el borde.
        let clave = Fechas.claveMes(mes)
        return try await cola.read { db in
            try EventoAgendaFila
                .filter(Column("borrado") == false)
                .filter(Column("fecha").like("\(clave)%"))
                .order(Column("fecha").asc, Column("horaInicio").asc)
                .fetchAll(db)
                .map(Self.aEvento)
        }
    }

    func guardar(_ e: EventoAgenda) async throws {
        try await cola.write { db in
            let previa = try EventoAgendaFila.fetchOne(db, key: e.id)
            try Self.aFila(e, actualizadoEn: previa?.actualizadoEn).save(db)
            try Self.encolar(db, id: e.id, operacion: previa == nil ? .crear : .actualizar)
        }
    }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            // Lápida, no borrado: si desapareciera de la tabla, el otro
            // aparato no se enteraría nunca de que ya no está.
            guard var fila = try EventoAgendaFila.fetchOne(db, key: id) else { return }
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    // MARK: - Traducción

    static func aEvento(_ f: EventoAgendaFila) -> EventoAgenda {
        EventoAgenda(
            id: f.id,
            fecha: f.fecha,
            hora: f.diaCompleto ? nil : f.horaInicio,
            titulo: f.nombre,
            // El web enseña el lugar junto a la descripción en la fila; aquí
            // el subtítulo es uno solo, así que se juntan con el mismo
            // separador que usa el resto de la app.
            descripcion: [f.lugar, f.descripcion].filter { !$0.isEmpty }.joined(separator: " · "),
            tipo: f.tipo == "otra" && !f.tipoPersonalizado.isEmpty
                ? .otro : TipoEvento(clave: f.tipo),
            completado: f.estado == "completada" || f.estado == "cancelada",
            todoDia: f.diaCompleto,
            horaFin: f.horaFin,
            lugar: f.lugar,
            responsable: f.responsablePersona,
            ministerio: f.responsableMinisterio,
            notaPie: f.invitado,
            estadoEvento: f.estado,
            esFechaImportante: f.esFechaImportante,
            recordatorios: Self.lista(f.recordatorios))
    }

    static func aFila(_ e: EventoAgenda, actualizadoEn: String?) -> EventoAgendaFila {
        EventoAgendaFila(
            id: e.id,
            fecha: e.fecha,
            nombre: e.titulo,
            tipo: e.tipo.clave,
            tipoPersonalizado: "",
            horaInicio: e.todoDia ? nil : e.hora,
            horaFin: e.todoDia ? nil : e.horaFin,
            diaCompleto: e.todoDia,
            lugar: e.lugar,
            descripcion: e.descripcion,
            miembroId: nil,
            responsablePersona: e.responsable,
            responsableMinisterio: e.ministerio,
            invitado: e.notaPie,
            contacto: "",
            // `completado` manda sobre el estado escrito: si la ficha dice
            // hecha, el estado tiene que decir lo mismo. Y una actividad nueva
            // sin estado nace "programada", como en el web.
            estado: e.completado ? "completada"
                                 : (e.estadoEvento.isEmpty ? "programada" : e.estadoEvento),
            recurrencia: #"{"tipo":"ninguna"}"#,
            excepciones: "[]",
            recordatorios: Self.json(e.recordatorios),
            esFechaImportante: e.esFechaImportante,
            actualizadoEn: actualizadoEn,
            borrado: false)
    }

    /// El JSON de `recordatorios` va y viene como lista de textos. Si trae
    /// cualquier otra cosa —el web guarda offsets numéricos en algunas
    /// versiones— se devuelve vacío en vez de tumbar la lectura de la agenda.
    static func lista(_ json: String) -> [String] {
        guard let d = json.data(using: .utf8),
              let v = try? JSONDecoder().decode([String].self, from: d) else { return [] }
        return v
    }

    static func json(_ v: [String]) -> String {
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == "evento" && Column("registroId") == id)
            .fetchOne(db)
        // Un alta que todavía no ha salido y se edita sigue siendo un alta:
        // mandar `update` de algo que allá no existe no actualiza nada.
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == "evento" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "evento", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

/// El único sitio donde se elige implementación: maqueta sin sesión, base con
/// ella. Igual que `repositorioMembresia()` y `repositorioServicios()`.
func repositorioAgenda() -> AgendaRepository {
    ModoRevision.sinLogin ? MockAgendaRepository() : OfflineAgendaRepository()
}

struct MockAgendaRepository: AgendaRepository {
    /// La semilla va por día del mes, así que se coloca en el mes que se pida
    /// y la maqueta enseña algo se mire el mes que se mire. Lo que se dé de
    /// alta en modo revisión vive en `añadidos` mientras dure la app: sin eso,
    /// crear una actividad y volver a entrar la hacía desaparecer, que es
    /// justo lo que la pantalla promete que no pasa.
    func eventos(mes: Date) async throws -> [EventoAgenda] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        let base = Self.semilla.map {
            EventoAgenda(id: $0.id, dia: $0.dia, hora: $0.hora, titulo: $0.titulo,
                         descripcion: $0.descripcion, tipo: $0.tipo,
                         completado: $0.completado, en: mes,
                         todoDia: $0.todoDia, horaFin: $0.horaFin, lugar: $0.lugar,
                         responsable: $0.responsable, ministerio: $0.ministerio,
                         presupuesto: $0.presupuesto, notaPie: $0.notaPie,
                         repeticion: $0.repeticion, estadoEvento: $0.estadoEvento,
                         esFechaImportante: $0.esFechaImportante,
                         recordatorios: $0.recordatorios)
        }
        let clave = Fechas.claveMes(mes)
        return base + Self.añadidos.filter { $0.fecha.hasPrefix(clave) }
    }

    func guardar(_ e: EventoAgenda) async throws {
        Self.añadidos.removeAll { $0.id == e.id }
        Self.añadidos.append(e)
    }

    func eliminar(id: String) async throws {
        Self.añadidos.removeAll { $0.id == id }
    }

    /// Lo dado de alta en esta sesión. Estático porque el repositorio se crea
    /// nuevo en cada llamada a `repositorioAgenda()`.
    nonisolated(unsafe) private static var añadidos: [EventoAgenda] = []

    /// Compromisos sin completar del mes. La sidebar del iPad y el hub de
    /// Secretaría lo leen de aquí en vez de llevar cada uno su propio número.
    static var pendientesCount: Int { semilla.filter { !$0.completado }.count }

    private static let semilla: [EventoAgenda] = [
            EventoAgenda(id: "1",  dia: 2,  hora: "10:00", titulo: L.t("Culto matutino", "Morning service"),             descripcion: L.t("roster completo", "full roster"),                     tipo: .culto,    completado: true),
            EventoAgenda(id: "2",  dia: 5,  hora: "19:30", titulo: L.t("Reunión de oración", "Prayer meeting"),          descripcion: "",                                                        tipo: .reunion,  completado: true),
            EventoAgenda(id: "3",  dia: 9,  hora: "10:00", titulo: L.t("Culto matutino", "Morning service"),             descripcion: L.t("roster completo", "full roster"),                     tipo: .culto,    completado: true),
            EventoAgenda(id: "4",  dia: 12, hora: "19:30", titulo: L.t("Reunión de oración", "Prayer meeting"),          descripcion: "",                                                        tipo: .reunion,  completado: true),
            EventoAgenda(id: "5",  dia: 16, hora: "10:00", titulo: L.t("Culto matutino", "Morning service"),             descripcion: L.t("roster completo", "full roster"),                     tipo: .culto,    completado: true),
            EventoAgenda(id: "6",  dia: 16, hora: nil,     titulo: L.t("Depósito bancario", "Bank deposit"),             descripcion: L.t("Banorte · pendiente", "Banorte · pending"),            tipo: .deposito, completado: true),
            EventoAgenda(id: "7",  dia: 19, hora: "19:30", titulo: L.t("Reunión de oración", "Prayer meeting"),          descripcion: "",                                                        tipo: .reunion,  completado: true),
            EventoAgenda(id: "8",  dia: 20, hora: nil,     titulo: L.t("Revisar bandeja", "Review tray"),                descripcion: L.t("7 movimientos pendientes · vence hoy", "7 pending transactions · due today"), tipo: .tarea, completado: false),
            EventoAgenda(id: "9",  dia: 20, hora: nil,     titulo: L.t("Llamar a Javier Medina", "Call Javier Medina"),  descripcion: L.t("Confirmar iglesia destino del traslado", "Confirm destination church for transfer"), tipo: .tarea, completado: false),
            EventoAgenda(id: "10", dia: 20, hora: nil,     titulo: L.t("Firmar acta 2026-07", "Sign minutes 2026-07"),   descripcion: L.t("Completado el 19 de agosto", "Completed on August 19"), tipo: .tarea, completado: true),
            EventoAgenda(id: "11", dia: 21, hora: "19:00", titulo: L.t("Consejo de ancianos", "Elders council"),         descripcion: L.t("salón anexo · levantar acta", "annex hall · take minutes"), tipo: .reunion, completado: false),
            EventoAgenda(id: "12", dia: 23, hora: "10:00", titulo: L.t("Culto matutino", "Morning service"),             descripcion: L.t("roster completo", "full roster"),                     tipo: .culto,    completado: false),
            EventoAgenda(id: "13", dia: 23, hora: nil,     titulo: L.t("Depósito bancario", "Bank deposit"),             descripcion: L.t("Banorte · 14 movimientos sin depositar", "Banorte · 14 undeposited transactions"), tipo: .deposito, completado: false),
            EventoAgenda(id: "14", dia: 26, hora: nil,     titulo: L.t("Carta de traslado · J. Medina", "Transfer letter · J. Medina"), descripcion: L.t("Pendiente de firma del pastor", "Awaiting pastor's signature"), tipo: .carta, completado: false),
            EventoAgenda(id: "15", dia: 26, hora: "19:30", titulo: L.t("Reunión de oración", "Prayer meeting"),          descripcion: "",                                                        tipo: .reunion,  completado: false),
    ]
}
