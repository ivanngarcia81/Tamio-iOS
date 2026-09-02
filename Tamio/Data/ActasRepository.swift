import Foundation

protocol ActasRepository {
    func lista() async throws -> [Acta]
}

struct MockActasRepository: ActasRepository {
    func lista() async throws -> [Acta] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return Self.actas
    }

    private static var actas: [Acta] {
        [
            Acta(id: 1, folio: "2026-08", tipo: L.t("Consejo", "Council"),
                 fecha: L.t("21 de agosto", "August 21"),
                 acuerdos: 6, estado: .borrador,
                 cuerpo: L.t(
                    "En Monterrey, Nuevo León, a las 19:00 horas del 21 de agosto de 2026, reunidos en el salón anexo los miembros del consejo, con la asistencia de siete de nueve integrantes, se declaró legalmente instalada la sesión.",
                    "In Monterrey, Nuevo León, at 19:00 hours on August 21, 2026, the council members gathered in the annex hall. With seven of nine members present, the session was declared legally convened."
                 ),
                 items: [
                    AcuerdoActa(id: 1, texto: L.t("Se aprueba el estado financiero de julio con un saldo de $27,174.50.", "The July financial statement is approved with a balance of $27,174.50.")),
                    AcuerdoActa(id: 2, texto: L.t("Se autoriza la compra del equipo de sonido del salón anexo por hasta $18,000.00.", "The purchase of sound equipment for the annex hall is authorized for up to $18,000.00.")),
                    AcuerdoActa(id: 3, texto: L.t("Se acepta la carta de traslado del hermano Javier Medina Cruz.", "The transfer letter of brother Javier Medina Cruz is accepted.")),
                    AcuerdoActa(id: 4, texto: L.t("Se nombra a la hermana Lucía Márquez coordinadora de la escuela bíblica.", "Sister Lucía Márquez is appointed coordinator of the Bible school.")),
                    AcuerdoActa(id: 5, texto: L.t("Se programan actividades especiales para el mes de septiembre.", "Special activities are scheduled for the month of September.")),
                    AcuerdoActa(id: 6, texto: L.t("Se aprueba el presupuesto de mantenimiento del templo.", "The temple maintenance budget is approved.")),
                 ]),
            Acta(id: 2, folio: "2026-07", tipo: L.t("Asamblea", "Assembly"),
                 fecha: L.t("18 de julio", "July 18"),
                 acuerdos: 4, estado: .firmada,
                 cuerpo: L.t(
                    "En Monterrey, Nuevo León, a las 10:30 horas del 18 de julio de 2026, se celebró la asamblea general ordinaria con la asistencia de 142 miembros, cumpliendo el quórum estatutario.",
                    "In Monterrey, Nuevo León, at 10:30 hours on July 18, 2026, the regular general assembly was held with 142 members in attendance, fulfilling the statutory quorum."
                 ),
                 items: [
                    AcuerdoActa(id: 7, texto: L.t("Se aprueba el informe semestral del pastor.", "The pastor's semiannual report is approved.")),
                    AcuerdoActa(id: 8, texto: L.t("Se ratifica la junta directiva para el periodo 2026-2027.", "The board of directors is ratified for the 2026-2027 period.")),
                    AcuerdoActa(id: 9, texto: L.t("Se aprueba el presupuesto para el segundo semestre.", "The second semester budget is approved.")),
                    AcuerdoActa(id: 10, texto: L.t("Se autoriza la renovación del contrato del salón social.", "The renewal of the social hall contract is authorized.")),
                 ]),
            Acta(id: 3, folio: "2026-06", tipo: L.t("Consejo", "Council"),
                 fecha: L.t("14 de junio", "June 14"),
                 acuerdos: 3, estado: .firmada,
                 cuerpo: L.t(
                    "En Monterrey, Nuevo León, a las 19:00 horas del 14 de junio de 2026, reunidos los miembros del consejo, se declaró instalada la sesión con seis de nueve integrantes presentes.",
                    "In Monterrey, Nuevo León, at 19:00 hours on June 14, 2026, the council members gathered. The session was declared open with six of nine members present."
                 ),
                 items: [
                    AcuerdoActa(id: 11, texto: L.t("Se aprueba la planificación del campamento de jóvenes.", "The youth camp planning is approved.")),
                    AcuerdoActa(id: 12, texto: L.t("Se acepta la donación del equipo de cocina.", "The kitchen equipment donation is accepted.")),
                    AcuerdoActa(id: 13, texto: L.t("Se aprueba el informe financiero de mayo.", "The May financial report is approved.")),
                 ]),
            Acta(id: 4, folio: "2026-05", tipo: L.t("Extraordinaria", "Extraordinary"),
                 fecha: L.t("3 de mayo", "May 3"),
                 acuerdos: 2, estado: .firmada,
                 cuerpo: L.t(
                    "En Monterrey, Nuevo León, a las 18:00 horas del 3 de mayo de 2026, se celebró sesión extraordinaria del consejo convocada por el pastor para tratar asuntos urgentes.",
                    "In Monterrey, Nuevo León, at 18:00 hours on May 3, 2026, an extraordinary council session was held, convened by the pastor to address urgent matters."
                 ),
                 items: [
                    AcuerdoActa(id: 14, texto: L.t("Se aprueba la reparación urgente del techo del templo.", "The urgent repair of the temple roof is approved.")),
                    AcuerdoActa(id: 15, texto: L.t("Se autoriza el uso del fondo de reserva por hasta $25,000.00.", "The use of the reserve fund for up to $25,000.00 is authorized.")),
                 ]),
        ]
    }
}
