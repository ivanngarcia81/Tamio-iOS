import Foundation
import GRDB

protocol ActasRepository {
    func lista() async throws -> [Acta]
    /// Alta o edición: lo que llega es el acta entera. Antes no existía —el
    /// alta solo hacía `insert` en un array del view model— y por eso un acta
    /// nueva desaparecía al volver a entrar.
    func guardar(_ a: Acta) async throws
    func eliminar(id: String) async throws
}

struct MockActasRepository: ActasRepository {
    func lista() async throws -> [Acta] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Las de esta sesión primero: se acaban de escribir y son lo que la
        // secretaria espera ver arriba.
        return Self.añadidas.reversed() + Self.actas.filter { a in
            !Self.añadidas.contains { $0.id == a.id }
        }
    }

    func guardar(_ a: Acta) async throws {
        Self.añadidas.removeAll { $0.id == a.id }
        Self.añadidas.append(a)
    }

    func eliminar(id: String) async throws {
        Self.añadidas.removeAll { $0.id == id }
    }

    nonisolated(unsafe) private static var añadidas: [Acta] = []

    /// **La semilla, ahora con campos en vez de prosa.** Antes cada acta traía
    /// su `cuerpo` escrito a mano; ahora el cuerpo se deriva, así que lo que
    /// se escribe aquí son los datos de la reunión, que es lo que una de
    /// verdad tendría. El año es el corriente para que la maqueta no envejezca
    /// como envejecieron los compromisos del hub.
    private static var actas: [Acta] {
        let año = Calendar.current.component(.year, from: Date())
        return [
            Acta(id: "1", folio: "\(año)-08", tipo: .lideres,
                 fecha: "\(año)-08-21", estado: .borrador,
                 items: [
                    AcuerdoActa(id: 1, texto: L.t("Se aprueba el estado financiero de julio con un saldo de $27,174.50.", "The July financial statement is approved with a balance of $27,174.50.")),
                    AcuerdoActa(id: 2, texto: L.t("Se autoriza la compra del equipo de sonido del salón anexo por hasta $18,000.00.", "The purchase of sound equipment for the annex hall is authorized for up to $18,000.00.")),
                    AcuerdoActa(id: 3, texto: L.t("Se acepta la carta de traslado del hermano Javier Medina Cruz.", "The transfer letter of brother Javier Medina Cruz is accepted.")),
                    AcuerdoActa(id: 4, texto: L.t("Se nombra a la hermana Lucía Márquez coordinadora de la escuela bíblica.", "Sister Lucía Márquez is appointed coordinator of the Bible school.")),
                    AcuerdoActa(id: 5, texto: L.t("Se programan actividades especiales para el mes de septiembre.", "Special activities are scheduled for the month of September.")),
                    AcuerdoActa(id: 6, texto: L.t("Se aprueba el presupuesto de mantenimiento del templo.", "The temple maintenance budget is approved.")),
                 ],
                 lugar: L.t("el salón anexo", "the annex hall"),
                 horaInicio: "19:00",
                 preside: "Pastor Abel Ramos", secretario: "María Hernández Ríos",
                 presentes: ["Pastor Abel Ramos", "María Hernández Ríos", "Pedro Salas Aguirre",
                             "Lucía Márquez Peña", "Ana Lucía Torres", "Javier Medina Cruz",
                             "Daniel Salas Hernández"],
                 ausentes: ["Jorge Hernández", "Carlos Rivas"],
                 quorum: true),

            Acta(id: "2", folio: "\(año)-07", tipo: .asamblea,
                 fecha: "\(año)-07-18", estado: .firmada,
                 items: [
                    AcuerdoActa(id: 7, texto: L.t("Se aprueba el informe semestral del pastor.", "The pastor's semiannual report is approved.")),
                    AcuerdoActa(id: 8, texto: L.t("Se ratifica la junta directiva para el periodo \(año)-\(año + 1).", "The board of directors is ratified for the \(año)-\(año + 1) period.")),
                    AcuerdoActa(id: 9, texto: L.t("Se aprueba el presupuesto para el segundo semestre.", "The second semester budget is approved.")),
                    AcuerdoActa(id: 10, texto: L.t("Se autoriza la renovación del contrato del salón social.", "The renewal of the social hall contract is authorized.")),
                 ],
                 lugar: L.t("el templo", "the sanctuary"),
                 horaInicio: "10:30",
                 preside: "Pastor Abel Ramos", secretario: "María Hernández Ríos",
                 quorum: true,
                 resumen: L.t("Asistieron 142 miembros, cumpliendo el quórum estatutario.",
                              "142 members attended, fulfilling the statutory quorum.")),

            Acta(id: "3", folio: "\(año)-06", tipo: .lideres,
                 fecha: "\(año)-06-14", estado: .firmada,
                 items: [
                    AcuerdoActa(id: 11, texto: L.t("Se aprueba la planificación del campamento de jóvenes.", "The youth camp planning is approved.")),
                    AcuerdoActa(id: 12, texto: L.t("Se acepta la donación del equipo de cocina.", "The kitchen equipment donation is accepted.")),
                    AcuerdoActa(id: 13, texto: L.t("Se aprueba el informe financiero de mayo.", "The May financial report is approved.")),
                 ],
                 lugar: L.t("el salón anexo", "the annex hall"),
                 horaInicio: "19:00",
                 preside: "Pastor Abel Ramos", secretario: "María Hernández Ríos",
                 presentes: ["Pastor Abel Ramos", "María Hernández Ríos", "Pedro Salas Aguirre",
                             "Lucía Márquez Peña", "Ana Lucía Torres", "Daniel Salas Hernández"],
                 quorum: true),

            Acta(id: "4", folio: "\(año)-05", tipo: .otra,
                 fecha: "\(año)-05-03", estado: .firmada,
                 items: [
                    AcuerdoActa(id: 14, texto: L.t("Se aprueba la reparación urgente del techo del templo.", "The urgent repair of the temple roof is approved.")),
                    AcuerdoActa(id: 15, texto: L.t("Se autoriza el uso del fondo de reserva por hasta $25,000.00.", "The use of the reserve fund for up to $25,000.00 is authorized.")),
                 ],
                 lugar: L.t("el salón anexo", "the annex hall"),
                 horaInicio: "18:00",
                 preside: "Pastor Abel Ramos", secretario: "María Hernández Ríos",
                 quorum: true,
                 resumen: L.t("Sesión extraordinaria convocada por el pastor para tratar asuntos urgentes.",
                              "Extraordinary session convened by the pastor to address urgent matters.")),
        ]
    }
}

/// Las actas de verdad: tabla `acta` de la base local, y de ahí a
/// `public.actas` por el motor de sincronización.
struct OfflineActasRepository: ActasRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista() async throws -> [Acta] {
        try await cola.read { db in
            try ActaFila
                .filter(Column("borrado") == false)
                // La más reciente arriba, que es como se trabaja: el acta del
                // mes pasado se corrige, la de hace dos años se consulta.
                .order(Column("fecha").desc)
                .fetchAll(db)
                .map(Self.aActa)
        }
    }

    func guardar(_ a: Acta) async throws {
        let previa = try await cola.read { db in try ActaFila.fetchOne(db, key: a.id) }
        try await cola.write { db in
            // Las firmas no las toca el formulario: se recogen aparte. Si se
            // sobreescribieran aquí, corregir una coma en un acta ya firmada
            // borraría las firmas.
            try Self.aFila(a, previa: previa).save(db)
            try Self.encolar(db, id: a.id, operacion: previa == nil ? .crear : .actualizar)
        }
        // Solo al PASAR a cerrada. `cerrada` y `archivada` son el mismo paso
        // para el web, que tiene cinco estados donde aquí hay siete.
        let cerradaAhora = a.estado == .cerrada || a.estado == .archivada
        let cerradaAntes = previa.map { EstadoActa(rawValue: $0.estado) == .cerrada
                                     || EstadoActa(rawValue: $0.estado) == .archivada } ?? false
        if cerradaAhora && !cerradaAntes {
            await anotarSuceso(.actaCerrada, ["folio": a.folio, "titulo": a.titulo])
        }
    }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            guard var fila = try ActaFila.fetchOne(db, key: id) else { return }
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    // MARK: - Traducción

    static func aActa(_ f: ActaFila) -> Acta {
        Acta(id: f.id,
             folio: f.folio,
             tipo: TipoActa(clave: f.tipo),
             fecha: f.fecha,
             // El estado local guarda el caso de iOS, no la clave del web.
             estado: EstadoActa(rawValue: f.estado) ?? EstadoActa(clave: f.estado),
             items: Self.acuerdos(f.acuerdos),
             tituloPersonalizado: f.titulo.isEmpty ? nil : f.titulo,
             lugar: f.lugar,
             horaInicio: f.horaInicio,
             horaCierre: f.horaCierre,
             preside: f.preside,
             secretario: f.secretario,
             presentes: Self.textos(f.presentes),
             ausentes: Self.textos(f.ausentes),
             invitados: Self.textos(f.invitados),
             quorum: f.quorum,
             agenda: f.agenda,
             resumen: f.resumen,
             mociones: Self.mociones(f.mociones),
             confidencial: f.confidencial,
             firmas: Self.firmas(f.firmas),
             actualizadoEn: f.actualizadoEn)
    }

    static func aFila(_ a: Acta, previa: ActaFila?) -> ActaFila {
        ActaFila(id: a.id,
                 folio: a.folio,
                 tipo: a.tipo.rawValue,
                 titulo: a.tituloPersonalizado ?? "",
                 fecha: a.fecha,
                 horaInicio: a.horaInicio,
                 horaCierre: a.horaCierre,
                 lugar: a.lugar,
                 preside: a.preside,
                 secretario: a.secretario,
                 testigo: previa?.testigo ?? "",
                 presentes: Self.json(a.presentes),
                 ausentes: Self.json(a.ausentes),
                 invitados: Self.json(a.invitados),
                 quorum: a.quorum,
                 agenda: a.agenda,
                 resumen: a.resumen,
                 mociones: Self.jsonMociones(a.mociones),
                 acuerdos: Self.jsonAcuerdos(a.items),
                 estado: a.estado.rawValue,
                 confidencial: a.confidencial,
                 fechaAprobacion: previa?.fechaAprobacion,
                 // **Las firmas solo se pisan si el acta trae unas.** El
                 // formulario de alta no las recoge, así que guardar una
                 // corrección desde ahí no puede borrar las que ya había.
                 firmas: a.firmas.isEmpty ? (previa?.firmas ?? "[]")
                                          : Self.jsonFirmas(a.firmas),
                 actualizadoEn: previa?.actualizadoEn,
                 borrado: false,
                 // Igual que la carta: nueva, folio provisional; editada,
                 // conserva el que tuviera.
                 folioProvisional: previa?.folioProvisional ?? true)
    }

    // MARK: - Los JSON del web

    /// **Los acuerdos del web son objetos, no textos.** `ActaAcuerdo` lleva
    /// `texto`, `responsable` y `fecha_limite`; el iOS solo enseña el texto.
    /// Se leen los tres y se escribe el texto con los otros dos vacíos, en vez
    /// de guardar una lista de cadenas que el web no sabría abrir.
    private struct AcuerdoJSON: Codable {
        var texto: String
        var responsable: String = ""
        var fecha_limite: String? = nil
    }

    private struct MocionJSON: Codable {
        var texto: String
        var presenta: String = ""
        var secunda: String = ""
        var resultado: String = ""
    }

    static func acuerdos(_ json: String) -> [AcuerdoActa] {
        guard let d = json.data(using: .utf8),
              let v = try? JSONDecoder().decode([AcuerdoJSON].self, from: d) else { return [] }
        return v.enumerated().map { AcuerdoActa(id: $0.offset + 1, texto: $0.element.texto) }
    }

    static func jsonAcuerdos(_ items: [AcuerdoActa]) -> String {
        let v = items.map { AcuerdoJSON(texto: $0.texto) }
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    static func mociones(_ json: String) -> [String] {
        guard let d = json.data(using: .utf8),
              let v = try? JSONDecoder().decode([MocionJSON].self, from: d) else { return [] }
        return v.map(\.texto)
    }

    static func jsonMociones(_ textos: [String]) -> String {
        let v = textos.map { MocionJSON(texto: $0) }
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    /// La firma del web: `rol`, `firmado` y `fecha`. Ver `ActaFirma`.
    private struct FirmaJSON: Codable {
        var rol: String
        var firmado: Bool
        var fecha: String?
    }

    static func firmas(_ json: String) -> [FirmaActa] {
        guard let d = json.data(using: .utf8),
              let v = try? JSONDecoder().decode([FirmaJSON].self, from: d) else { return [] }
        return v.map { FirmaActa(rol: RolFirmaActa(clave: $0.rol),
                                 firmado: $0.firmado, fecha: $0.fecha) }
    }

    static func jsonFirmas(_ firmas: [FirmaActa]) -> String {
        let v = firmas.map { FirmaJSON(rol: $0.rol.rawValue, firmado: $0.firmado,
                                       fecha: $0.fecha) }
        guard let d = try? JSONEncoder().encode(v),
              let s = String(data: d, encoding: .utf8) else { return "[]" }
        return s
    }

    /// Las listas de nombres sí son cadenas sueltas allá.
    static func textos(_ json: String) -> [String] {
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
            .filter(Column("entidad") == "acta" && Column("registroId") == id)
            .fetchOne(db)
        let efectiva: OperacionPendiente.Operacion =
            (previa?.operacion == OperacionPendiente.Operacion.crear.rawValue
             && operacion == .actualizar) ? .crear : operacion
        try OperacionPendiente
            .filter(Column("entidad") == "acta" && Column("registroId") == id)
            .deleteAll(db)
        var nueva = OperacionPendiente(id: nil, entidad: "acta", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: previa?.creadoEn ?? Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

/// Maqueta sin sesión, base con ella.
func repositorioActas() -> ActasRepository {
    ModoRevision.sinLogin ? MockActasRepository() : OfflineActasRepository()
}
