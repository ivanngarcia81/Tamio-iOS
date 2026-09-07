import XCTest
import GRDB
@testable import Tamio

/// **El folio provisional de una carta.**
///
/// El definitivo lo da el contador del servidor al subir —`siguiente_folio_anual`,
/// que lo entrega y lo reserva en un solo statement—. Lo que se prueba aquí es
/// el de mientras tanto: el número con el que la carta espera, que se ve marcado
/// con "P-" y no se imprime.
///
/// La cuenta importa aunque sea provisional: dos borradores sin subir no pueden
/// llevar el mismo, o en la lista no se distinguen.
@MainActor
final class FolioDeCartaTests: XCTestCase {

    private let repo = OfflineCartasRepository()
    private let año = String(Fechas.claveDia(Date()).prefix(4))

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertFalse(BaseLocal.compartida.enMemoria)
        try BaseLocal.compartida.limpiar()
    }

    private func carta(_ id: String, folio: String, borrada: Bool = false) async throws {
        try await BaseLocal.compartida.cola.write { db in
            try CartaFila(id: id, folio: folio, tipo: "traslado",
                          fechaEmision: Fechas.claveDia(Date()), lugarEmision: "",
                          miembroId: nil, destinatarioTipo: "miembro",
                          destinatarioNombre: "María Hernández",
                          destinatarioDireccion: "", asunto: "", saludo: "",
                          cuerpoHtml: "", despedida: "", firmas: "[]",
                          observaciones: "", estado: "emitida",
                          historialEstados: "[]", entregadaA: "",
                          fechaEntrega: nil, actualizadoEn: nil,
                          borrado: borrada).insert(db)
        }
    }

    func testLaPrimeraCartaDelAñoEsLaUno() async throws {
        let folio = await repo.siguienteFolio(fecha: Date())
        XCTAssertEqual(folio, "P-1", "marcado, porque el bueno lo da el servidor al subir")
    }

    func testCuentaTambienLasCartasQueSubioElEscritorio() async throws {
        // El folio del web: si no se cuenta, el teléfono repite su número.
        try await carta("c1", folio: "CAR-\(año)-0014")
        let folio = await repo.siguienteFolio(fecha: Date())
        XCTAssertEqual(folio, "P-15")
    }

    func testUnaCartaBorradaNoDevuelveSuNumero() async throws {
        try await carta("c1", folio: "CAR-\(año)-0007", borrada: true)
        let folio = await repo.siguienteFolio(fecha: Date())
        XCTAssertEqual(folio, "P-8", "ese folio se emitió y está citado en algún papel")
    }

    func testLosFoliosDeOtroAñoNoCuentan() async throws {
        try await carta("c1", folio: "CAR-1999-0042")
        let folio = await repo.siguienteFolio(fecha: Date())
        XCTAssertEqual(folio, "P-1", "cada año empieza por uno")
    }

    func testUnFolioConFormatoVIEJONoSeCuenta() async throws {
        // Las emitidas antes de este arreglo son "2026-014". No cuentan para el
        // máximo —no son de la serie— y por eso conviven sin chocar.
        try await carta("c1", folio: "\(año)-014")
        let folio = await repo.siguienteFolio(fecha: Date())
        XCTAssertEqual(folio, "P-1")
    }

    func testDosCartasSeguidasNoRepitenNumero() async throws {
        let primero = await repo.siguienteFolio(fecha: Date())
        try await carta("c1", folio: primero)
        let segundo = await repo.siguienteFolio(fecha: Date())
        XCTAssertNotEqual(primero, segundo)
        XCTAssertEqual(segundo, "P-2")
    }
}
