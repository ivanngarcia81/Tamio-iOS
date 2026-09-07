import XCTest
import GRDB
@testable import Tamio

/// **La v23 y la pastilla de traslado en curso.** Una migración es lo único que
/// no puede fallar en silencio: si `migrate` lanza, `BaseLocal` se cae a una
/// base en memoria sin avisar y se pierde todo lo local.
@MainActor
final class TrasladoEnCursoTests: XCTestCase {

    private let padron = OfflineMembresiaRepository()

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertFalse(BaseLocal.compartida.enMemoria,
                       "la base tenía que abrir EN DISCO con la v23 aplicada")
        try BaseLocal.compartida.limpiar()
        try await padron.guardar(Miembro(id: "m1", nombre: "María Hernández"))
        try await padron.guardar(Miembro(id: "m2", nombre: "Ana Torres"))
    }

    private func sembrar(_ id: String, miembro: String, estado: String,
                         destino: String = "Iglesia Betel") async throws {
        try await BaseLocal.compartida.cola.write { db in
            try TrasladoSalidaFila(id: id, miembroId: miembro, folio: "TS-2026-0001",
                                   fechaSolicitud: "2026-09-01", iglesiaDestino: destino,
                                   estado: estado, actualizadoEn: nil, borrado: false)
                .insert(db)
        }
    }

    private func miembro(_ id: String) async throws -> Miembro {
        let lista = try await padron.lista()
        return try XCTUnwrap(lista.first { $0.id == id })
    }

    func testLaTablaExisteYGuardaUnTraslado() async throws {
        try await sembrar("t1", miembro: "m1", estado: "aprobado")
        let cuantos = try await BaseLocal.compartida.cola.read { db in
            try TrasladoSalidaFila.fetchCount(db)
        }
        XCTAssertEqual(cuantos, 1)
    }

    func testUnTrasladoAbiertoSeVeEnLaFichaSinCambiarElEstado() async throws {
        try await sembrar("t1", miembro: "m1", estado: "cartaEmitida")
        let m = try await miembro("m1")
        XCTAssertEqual(m.trasladoEnCurso?.iglesiaDestino, "Iglesia Betel")
        XCTAssertFalse(m.estado.esBaja,
                       "sigue activa: el traslado es un expediente, no un estado")
        XCTAssertTrue(m.trasladoEnCurso!.etiquetaConDestino.contains("Betel"),
                      "la ficha dice a dónde va")
        XCTAssertFalse(m.trasladoEnCurso!.etiqueta.contains("Betel"),
                       "la pastilla de la lista, no: parte en dos renglones")
    }

    func testUnTrasladoTerminadoYaNoSeEnseña() async throws {
        try await sembrar("t1", miembro: "m1", estado: "completado")
        try await sembrar("t2", miembro: "m2", estado: "cancelado")
        let uno = try await miembro("m1")
        let dos = try await miembro("m2")
        XCTAssertNil(uno.trasladoEnCurso, "completado ya no está en curso")
        XCTAssertNil(dos.trasladoEnCurso, "cancelado tampoco")
    }

    func testCadaTrasladoVaConSuPersona() async throws {
        try await sembrar("t1", miembro: "m2", estado: "solicitud", destino: "Monte Sion")
        let uno = try await miembro("m1")
        let dos = try await miembro("m2")
        XCTAssertNil(uno.trasladoEnCurso)
        XCTAssertEqual(dos.trasladoEnCurso?.iglesiaDestino, "Monte Sion")
    }

    func testSinDestinoLaPastillaSigueDiciendoAlgo() async throws {
        try await sembrar("t1", miembro: "m1", estado: "borrador", destino: "")
        let m = try await miembro("m1")
        let etiqueta = try XCTUnwrap(m.trasladoEnCurso?.etiquetaConDestino)
        XCTAssertFalse(etiqueta.contains("→"), "sin destino no se pinta una flecha a ninguna parte")
        XCTAssertFalse(etiqueta.isEmpty)
    }

    func testUnTrasladoBorradoNoCuenta() async throws {
        try await BaseLocal.compartida.cola.write { db in
            try TrasladoSalidaFila(id: "t1", miembroId: "m1", folio: "TS-2026-0002",
                                   fechaSolicitud: "2026-09-01", iglesiaDestino: "Betel",
                                   estado: "aprobado", actualizadoEn: nil, borrado: true)
                .insert(db)
        }
        let m = try await miembro("m1")
        XCTAssertNil(m.trasladoEnCurso, "una lápida no es un traslado abierto")
    }
}
