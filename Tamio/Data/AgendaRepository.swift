import Foundation

protocol AgendaRepository {
    func eventos() async throws -> [EventoAgenda]
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
