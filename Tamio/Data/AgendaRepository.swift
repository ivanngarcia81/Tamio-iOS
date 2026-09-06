import Foundation

protocol AgendaRepository {
    func eventos() async throws -> [EventoAgenda]
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
        let todos = (try? await eventos()) ?? []
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: hoy)
        let inicioDeHoy = cal.startOfDay(for: hoy)

        // Sin completar: lo hecho no es un compromiso. Mismo criterio que la
        // fila de Agenda del hub, para que las dos cifras no discrepen.
        let pendientes = todos.filter { !$0.completado }

        let conFecha: [CompromisoProximo] = pendientes.compactMap { e in
            var c = comps
            c.day = e.dia
            guard let fecha = cal.date(from: c) else { return nil }
            let dias = cal.dateComponents([.day], from: inicioDeHoy,
                                          to: cal.startOfDay(for: fecha)).day ?? 0
            return CompromisoProximo(evento: e, fecha: fecha, enDias: dias)
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

/// El único sitio donde se elige implementación. Hoy solo hay maqueta: la
/// agenda no tiene tabla local ni entra en el motor de sincronización, aunque
/// `public.agenda` ya existe en Supabase con datos puestos por el web. Cuando
/// se escriba `OfflineAgendaRepository` se cambia aquí y el hub y la Agenda lo
/// heredan a la vez.
func repositorioAgenda() -> AgendaRepository {
    MockAgendaRepository()
}

struct MockAgendaRepository: AgendaRepository {
    func eventos() async throws -> [EventoAgenda] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return Self.semilla
    }

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
