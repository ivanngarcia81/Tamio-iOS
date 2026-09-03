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
