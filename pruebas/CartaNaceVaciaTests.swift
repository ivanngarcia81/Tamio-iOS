import XCTest
@testable import Tamio

/// **Una carta nueva no puede venir con destinatario puesto.**
///
/// `CartaEnEdicion` traía cuatro valores de maqueta escritos dentro, y son
/// justo los que cuenta la comprobación de "faltan campos por completar": con
/// ellos, se podía firmar y emitir sin escribir nada, a nombre de alguien que
/// no existe. Pasó tres veces en la iglesia de verdad el 7 de septiembre.
@MainActor
final class CartaNaceVaciaTests: XCTestCase {

    func testUnaCartaNuevaNoTraeDestinatario() {
        let c = CartaEnEdicion()
        XCTAssertTrue(c.aportante.isEmpty, "«Javier Medina Cruz» no es de esta iglesia")
        XCTAssertTrue(c.iglesiaDestino.isEmpty)
        XCTAssertTrue(c.miembroDesde.isEmpty)
    }

    func testYPorEsoNoSePuedeFirmarSinEscribirNada() {
        let c = CartaEnEdicion()
        XCTAssertEqual(c.camposCompletos, 0)
        XCTAssertLessThan(c.camposCompletos, c.camposTotales,
                          "la comprobación de campos incompletos se cumplía sola")
    }

    func testConLosTresCamposPuestosSiSePuede() {
        var c = CartaEnEdicion()
        c.aportante = "María Hernández"
        c.iglesiaDestino = "Iglesia Betel"
        c.miembroDesde = "2019"
        XCTAssertEqual(c.camposCompletos, c.camposTotales)
    }

    func testLaFirmaLaPropoveLaIglesia() {
        // Un dato de la iglesia se propone; uno inventado, no. Con Ajustes sin
        // pastor, la firma queda vacía y la línea sale en blanco para firmar a
        // mano, que es lo que hace el papel.
        ConfiguracionIglesiaViewModel.compartido.config.pastorNombre = "Pastor de prueba"
        XCTAssertEqual(CartaEnEdicion().firma, "Pastor de prueba")
        ConfiguracionIglesiaViewModel.compartido.config.pastorNombre = ""
        XCTAssertTrue(CartaEnEdicion().firma.isEmpty)
    }
}
