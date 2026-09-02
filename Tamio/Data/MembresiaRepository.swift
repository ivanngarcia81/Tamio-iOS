import Foundation

protocol MembresiaRepository {
    func lista() async throws -> [Miembro]
    func resumen() async -> MembresiaResumen
    func asistenciaResumen() async -> AsistenciaResumen
}

/// Datos falsos que reproducen la pantalla de Membresía del handoff.
struct MockMembresiaRepository: MembresiaRepository {
    func resumen() async -> MembresiaResumen {
        MembresiaResumen(total: 248, activos: 236, inactivos: 6, nuevos: 14,
                         recibidos: 3, trasladados: 5, ausencias: 9, incompletos: 21)
    }

    func asistenciaResumen() async -> AsistenciaResumen {
        AsistenciaResumen(
            promedioPct: 74,
            serviciosPeriodo: 27,
            presentesPromedio: 186,
            mejorServicio: "214 · 23 ago",
            meses: [
                MesAsistenciaCongregacion(mes: L.t("Ene","Jan"), presentes: 168, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Feb","Feb"), presentes: 182, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Mar","Mar"), presentes: 164, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Abr","Apr"), presentes: 196, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("May","May"), presentes: 176, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Jun","Jun"), presentes: 204, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Jul","Jul"), presentes: 158, enRoster: 230),
                MesAsistenciaCongregacion(mes: L.t("Ago","Aug"), presentes: 214, enRoster: 230),
            ],
            porTipo: [
                TipoAsistencia(tipo: L.t("Culto matutino",    "Morning service"),  promedio: 186),
                TipoAsistencia(tipo: L.t("Culto vespertino",  "Evening service"),  promedio: 108),
                TipoAsistencia(tipo: L.t("Reunión de oración","Prayer meeting"),   promedio: 74),
                TipoAsistencia(tipo: L.t("Escuela bíblica",   "Bible school"),     promedio: 62),
            ]
        )
    }

    func lista() async throws -> [Miembro] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.miembros
    }

    private static func serie(_ base: Double) -> [MesAsistencia] {
        let et = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago"]
        let vals = [0.7, 0.85, 0.6, 0.9, 0.8, 0.95, 0.88, base]
        return zip(et, vals).map { MesAsistencia(mes: $0.0, valor: $0.1) }
    }

    private static func expediente(completo: Bool = true) -> [ItemExpediente] {
        [
            ItemExpediente(campo: L.t("Nombre y apellidos","Full name"),    completo: completo),
            ItemExpediente(campo: L.t("Teléfono","Phone"),                  completo: completo),
            ItemExpediente(campo: L.t("Correo","Email"),                    completo: completo),
            ItemExpediente(campo: L.t("Dirección","Address"),               completo: completo),
            ItemExpediente(campo: L.t("Fecha de bautismo","Baptism date"),  completo: completo),
        ]
    }

    private static var miembros: [Miembro] {
        [
            Miembro(id: 1, nombre: "María Hernández Ríos",
                    subtitulo: L.t("Ingresó 2014 · damas · 96%","Joined 2014 · women · 96%"),
                    estado: .activo, asistenciaPct: 96,
                    area: L.t("Enseñanza · niños","Teaching · children"),
                    miembroDesde: L.t("Ingresó 2014","Joined 2014"),
                    asistencia: serie(0.96),
                    enRoster: "26 de 27", rachaSinAsistir: L.t("0 servicios","0 services"),
                    ultimaVisita: "23 ago",
                    seguimientoRazon: nil, ausenciaNota: nil,
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),      valor: "14 mar 2014"),
                        Dato(etiqueta: L.t("Se congrega desde","Attends since"),  valor: "Junio 2012"),
                        Dato(etiqueta: L.t("Bautismo","Baptism"),                 valor: "12 abr 2014"),
                        Dato(etiqueta: L.t("Cargos","Roles"),                     valor: L.t("Maestra","Teacher")),
                        Dato(etiqueta: L.t("Instrumentos","Instruments"),         valor: L.t("Voz","Voice")),
                    ],
                    expediente: expediente(),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"), fecha: "14 mar 2014"),
                        MovMembresia(titulo: L.t("Bautismo en agua","Water baptism"),    fecha: "12 abr 2014"),
                        MovMembresia(titulo: L.t("Se congrega desde","Attends since"),   fecha: "Junio 2012"),
                    ]),

            Miembro(id: 2, nombre: "Lucía Márquez Peña",
                    subtitulo: L.t("Ingresó 2019 · música · 92%","Joined 2019 · music · 92%"),
                    estado: .activo, asistenciaPct: 92,
                    area: L.t("Alabanza","Worship"),
                    miembroDesde: L.t("Ingresó 2019","Joined 2019"),
                    asistencia: serie(0.92),
                    enRoster: "25 de 27", rachaSinAsistir: L.t("0 servicios","0 services"),
                    ultimaVisita: "23 ago",
                    seguimientoRazon: nil, ausenciaNota: nil,
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),     valor: "8 feb 2019"),
                        Dato(etiqueta: L.t("Se congrega desde","Attends since"), valor: "Octubre 2018"),
                        Dato(etiqueta: L.t("Bautismo","Baptism"),                valor: "15 mar 2019"),
                        Dato(etiqueta: L.t("Cargos","Roles"),                    valor: L.t("Coordinadora escuela bíblica","Bible school coordinator")),
                    ],
                    expediente: expediente(),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"), fecha: "8 feb 2019"),
                        MovMembresia(titulo: L.t("Bautismo en agua","Water baptism"),    fecha: "15 mar 2019"),
                    ]),

            Miembro(id: 3, nombre: "Pedro Salas Aguirre",
                    subtitulo: L.t("Ingresó 2021 · diaconado · 88%","Joined 2021 · deaconship · 88%"),
                    estado: .activo, asistenciaPct: 88,
                    area: L.t("Ujier","Usher"),
                    miembroDesde: L.t("Ingresó 2021","Joined 2021"),
                    asistencia: serie(0.88),
                    enRoster: "24 de 27", rachaSinAsistir: L.t("0 servicios","0 services"),
                    ultimaVisita: "23 ago",
                    seguimientoRazon: nil, ausenciaNota: nil,
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),     valor: "12 jun 2021"),
                        Dato(etiqueta: L.t("Bautismo","Baptism"),                valor: "4 jul 2021"),
                        Dato(etiqueta: L.t("Cargos","Roles"),                    valor: L.t("Diácono","Deacon")),
                    ],
                    expediente: expediente(),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"), fecha: "12 jun 2021"),
                    ]),

            Miembro(id: 4, nombre: "Javier Medina Cruz",
                    subtitulo: L.t("Traslado en proceso · 41%","Transfer in progress · 41%"),
                    estado: .traslado, asistenciaPct: 41,
                    area: L.t("Sin área","No area"),
                    miembroDesde: L.t("Ingresó 2021","Joined 2021"),
                    asistencia: serie(0.41),
                    enRoster: "11 de 27", rachaSinAsistir: L.t("6 servicios","6 services"),
                    ultimaVisita: "12 jul",
                    seguimientoRazon: L.t("Seis servicios seguidos sin asistir · Traslado sin carta entregada",
                                          "Six consecutive services without attendance · Transfer letter not delivered"),
                    ausenciaNota: L.t("· traslado","· transfer"),
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),     valor: "3 mar 2021"),
                        Dato(etiqueta: L.t("Bautismo","Baptism"),                valor: "20 mar 2021"),
                    ],
                    expediente: expediente(completo: false),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"),     fecha: "3 mar 2021"),
                        MovMembresia(titulo: L.t("Solicitud de traslado iniciada","Transfer request started"), fecha: "12 ago 2026"),
                    ]),

            Miembro(id: 5, nombre: "Ana Lucía Torres",
                    subtitulo: L.t("Ingresó 2016 · sin ministerio · 62%","Joined 2016 · no ministry · 62%"),
                    estado: .activo, asistenciaPct: 62,
                    area: L.t("Intercesión","Intercession"),
                    miembroDesde: L.t("Ingresó 2016","Joined 2016"),
                    asistencia: serie(0.62),
                    enRoster: "17 de 27", rachaSinAsistir: L.t("3 servicios","3 services"),
                    ultimaVisita: "2 ago",
                    seguimientoRazon: L.t("Tres servicios seguidos sin asistir","Three consecutive services without attendance"),
                    ausenciaNota: L.t("· enfermedad","· illness"),
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),      valor: "19 sep 2016"),
                        Dato(etiqueta: L.t("Bautismo","Baptism"),                 valor: "2 oct 2016"),
                        Dato(etiqueta: L.t("Cargos","Roles"),                     valor: L.t("Intercesor","Intercessor")),
                    ],
                    expediente: expediente(),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"), fecha: "19 sep 2016"),
                    ]),

            Miembro(id: 6, nombre: "Familia Ruvalcaba",
                    subtitulo: L.t("4 integrantes · diezman · 84%","4 members · tithe givers · 84%"),
                    estado: .activo, asistenciaPct: 84,
                    area: L.t("Varios","Various"),
                    miembroDesde: L.t("Ingresó 2016","Joined 2016"),
                    asistencia: serie(0.84),
                    enRoster: "23 de 27", rachaSinAsistir: L.t("1 servicio","1 service"),
                    ultimaVisita: "23 ago",
                    seguimientoRazon: nil, ausenciaNota: nil,
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),      valor: "7 ene 2016"),
                        Dato(etiqueta: L.t("Bautismo","Baptism"),                 valor: "14 feb 2016"),
                        Dato(etiqueta: L.t("Integrantes","Members"),              valor: "4"),
                    ],
                    expediente: expediente(),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"), fecha: "7 ene 2016"),
                    ]),

            Miembro(id: 7, nombre: "Daniel Guerra Salinas",
                    subtitulo: L.t("Recibido por traslado · 78%","Received by transfer · 78%"),
                    estado: .nuevo, asistenciaPct: 78,
                    area: L.t("Sin área","No area"),
                    miembroDesde: L.t("Ingresó 2026","Joined 2026"),
                    asistencia: serie(0.78),
                    enRoster: "6 de 27", rachaSinAsistir: L.t("0 servicios","0 services"),
                    ultimaVisita: "23 ago",
                    seguimientoRazon: L.t("Nuevo en el periodo","New in the period"),
                    ausenciaNota: nil,
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),      valor: "6 jul 2026"),
                        Dato(etiqueta: L.t("Iglesia anterior","Previous church"), valor: L.t("Iglesia Emanuel · Torreón","Iglesia Emanuel · Torreón")),
                    ],
                    expediente: expediente(completo: false),
                    movimientos: [
                        MovMembresia(titulo: L.t("Recibido por traslado","Received by transfer"), fecha: "6 jul 2026"),
                    ]),

            Miembro(id: 8, nombre: "Rosa Elena Vega",
                    subtitulo: L.t("Traslado aceptado","Transfer accepted"),
                    estado: .baja, asistenciaPct: 0,
                    area: L.t("Sin área","No area"),
                    miembroDesde: L.t("Ingresó 2013","Joined 2013"),
                    asistencia: serie(0),
                    enRoster: "0 de 27", rachaSinAsistir: L.t("27 servicios","27 services"),
                    ultimaVisita: "14 mar",
                    seguimientoRazon: nil, ausenciaNota: nil,
                    datos: [
                        Dato(etiqueta: L.t("Fecha de ingreso","Join date"),      valor: "11 ago 2013"),
                        Dato(etiqueta: L.t("Fecha de baja","Removal date"),       valor: "14 mar 2026"),
                    ],
                    expediente: expediente(),
                    movimientos: [
                        MovMembresia(titulo: L.t("Alta como miembro","Added as member"), fecha: "11 ago 2013"),
                        MovMembresia(titulo: L.t("Traslado enviado","Transfer sent"),    fecha: "14 mar 2026"),
                    ]),
        ]
    }
}
