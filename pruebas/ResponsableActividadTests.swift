import XCTest
import GRDB
@testable import Tamio

/// **Quién responde de una actividad se guarda por id, no por nombre.**
/// El web tiene las dos columnas y son excluyentes; iOS guardaba solo el texto,
/// así que la actividad no enlazaba con nadie y una creada en el web —que deja
/// el texto en nulo— llegaba al teléfono sin responsable.
@MainActor
final class ResponsableActividadTests: XCTestCase {

    private let agenda = OfflineAgendaRepository()

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertFalse(BaseLocal.compartida.enMemoria)
        try BaseLocal.compartida.limpiar()
        try await OfflineMembresiaRepository().guardar(
            Miembro(id: "m1", nombre: "María Hernández"))
    }

    private func actividad(responsable: String = "", responsableId: String? = nil) -> EventoAgenda {
        EventoAgenda(id: "e1", fecha: Fechas.claveDia(Date()), hora: "19:00",
                     titulo: "Consejo", descripcion: "", tipo: .reunion,
                     completado: false, responsable: responsable,
                     responsableId: responsableId)
    }

    func testElResponsableDelPadronSeGuardaPorId() async throws {
        try await agenda.guardar(actividad(responsable: "María Hernández", responsableId: "m1"))
        let eventos = try await agenda.eventos(mes: Date())
        let e = try XCTUnwrap(eventos.first)
        XCTAssertEqual(e.responsableId, "m1", "sin el id, el web no puede enlazarla con nadie")
        XCTAssertEqual(e.responsable, "María Hernández", "y se lee el nombre del padrón")
    }

    func testConIdElTextoNoSeGuarda() async throws {
        try await agenda.guardar(actividad(responsable: "María Hernández", responsableId: "m1"))
        let fila = try await BaseLocal.compartida.cola.read { db in
            try EventoAgendaFila.fetchOne(db, key: "e1")
        }
        XCTAssertEqual(fila?.miembroId, "m1")
        XCTAssertEqual(fila?.responsablePersona, "",
                       "son excluyentes, como en el web: dos verdades pueden separarse")
    }

    func testElNombreSeLeeDelPadronYNoDeLaCopia() async throws {
        try await agenda.guardar(actividad(responsable: "Como se llamaba antes", responsableId: "m1"))
        let eventos = try await agenda.eventos(mes: Date())
        let e = try XCTUnwrap(eventos.first)
        XCTAssertEqual(e.responsable, "María Hernández",
                       "quien se case y cambie de apellido no deja actividades con el viejo")
    }

    func testUnResponsableDeFueraSigueSiendoTexto() async throws {
        try await agenda.guardar(actividad(responsable: "El del sonido"))
        let eventos = try await agenda.eventos(mes: Date())
        let e = try XCTUnwrap(eventos.first)
        XCTAssertNil(e.responsableId)
        XCTAssertEqual(e.responsable, "El del sonido")
    }

    func testUnIdQueYaNoEstaEnElPadronNoEnseñaElIdCrudo() async throws {
        try await agenda.guardar(actividad(responsableId: "borrado-hace-un-año"))
        let eventos = try await agenda.eventos(mes: Date())
        let e = try XCTUnwrap(eventos.first)
        XCTAssertEqual(e.responsable, "", "un uid en pantalla no le dice nada a nadie")
    }
}
