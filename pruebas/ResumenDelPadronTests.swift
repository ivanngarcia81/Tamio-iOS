import XCTest
@testable import Tamio

/// **El resumen del padrón tiene que cuadrar con el padrón.**
///
/// La maqueta llevaba ocho cifras escritas a mano —236 activos, 248 de total,
/// 21 incompletos— sobre una `lista()` de siete personas, y el hub de
/// Secretaría y la cabecera de Membresía las leían. En modo revisión la app
/// encabezaba 248 encima de un padrón de siete: cualquiera que tocara la
/// tarjeta veía la contradicción, y de ahí salen las capturas de App Store.
///
/// Estas pruebas no comprueban NÚMEROS CONCRETOS a propósito: si mañana crece
/// la lista de maqueta, tienen que seguir pasando. Lo que comprueban es que el
/// resumen y la lista no puedan contradecirse.
final class ResumenDelPadronTests: XCTestCase {

    func testElTotalEsLaGenteQueHayEnLaLista() async throws {
        let repo = MockMembresiaRepository()
        let lista = try await repo.lista()
        let resumen = await repo.resumen()
        XCTAssertEqual(resumen.total, lista.count,
                       "### el encabezado dice \(resumen.total) sobre un padrón de \(lista.count)")
    }

    /// Los tres estados se excluyen entre sí y no dejan a nadie fuera: es lo
    /// que dice el comentario de `MembresiaResumen`, y conviene que sea verdad.
    func testLosTresEstadosCubrenATodos() async throws {
        let repo = MockMembresiaRepository()
        let lista = try await repo.lista()
        let r = await repo.resumen()
        XCTAssertEqual(r.activos + r.inactivos + r.bajas, lista.count)
    }

    /// Las señales cuentan gente que existe: no puede haber más expedientes
    /// incompletos que personas vivas.
    func testLasSenalesNoSePasanDeLaGenteQueHay() async throws {
        let repo = MockMembresiaRepository()
        let r = await repo.resumen()
        let vivos = r.activos + r.inactivos
        XCTAssertLessThanOrEqual(r.incompletos, vivos,
                                 "### más expedientes incompletos que personas vivas")
        XCTAssertLessThanOrEqual(r.ausencias, vivos)
    }

    /// Y la cuenta compartida, sobre una lista vacía, no inventa nada.
    func testUnPadronVacioNoInventaCifras() {
        let r = MembresiaResumen.de([])
        XCTAssertEqual(r.total, 0)
        XCTAssertEqual(r.incompletos, 0)
        XCTAssertEqual(r.ausencias, 0)
    }
}
