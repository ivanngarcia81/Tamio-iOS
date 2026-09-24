import XCTest
@testable import Tamio

/// **La ficha de la iglesia sube solo lo que cambió** (`CamposIglesia`, 24-sep).
///
/// Hasta ese día la subida mandaba la ficha entera y ganaba la última: un
/// aparato con un cambio guardado sin conexión lo subía días después y
/// deshacía todo lo que otros hubieran cambiado mientras tanto, en cualquier
/// campo. Así volvió a la iglesia de prueba el nombre de 500 caracteres de
/// `TextoBruto`.
///
/// Probado además de punta a punta contra la iglesia de prueba, con el Mac: la
/// ciudad cambiada «desde otro aparato» en Supabase y el teléfono pendiente en
/// la cola del Mac acabaron los dos en el servidor.
final class CamposIglesiaTests: XCTestCase {

    private func ficha() -> ConfiguracionIglesia {
        var c = ConfiguracionIglesia()
        c.nombre = "Iglesia de prueba"
        c.ciudad = "Saltillo"
        c.telefono = ""
        c.pastorCargo = "Pastor"
        return c
    }

    /// Sin base —las filas de antes del 24-sep— sube todo, como antes.
    func testSinBaseSubeTodo() {
        let parche = CamposIglesia.parche(ficha(), base: nil)
        XCTAssertEqual(parche.count, CamposIglesia.de(ficha()).count)
        XCTAssertEqual(parche["nombre"], .texto("Iglesia de prueba"))
    }

    /// Con la base igual a la ficha no hay nada que subir.
    func testBaseIgualNoSubeNada() {
        let base = CamposIglesia.escribir(CamposIglesia.de(ficha()))
        XCTAssertTrue(CamposIglesia.parche(ficha(), base: base).isEmpty)
    }

    /// Un campo cambiado sube solo, y los demás no viajan: eso es lo que deja
    /// intacto lo que otro aparato cambió mientras tanto.
    func testUnCampoSubeSolo() {
        let base = CamposIglesia.escribir(CamposIglesia.de(ficha()))
        var c = ficha()
        c.telefono = "(844) 555-0142"
        let parche = CamposIglesia.parche(c, base: base)
        XCTAssertEqual(parche, ["telefono": .texto("(844) 555-0142")])
    }

    /// El cargo vacío sube NULO —el web solo traduce su respaldo con nulo— y
    /// vaciarlo cuenta como cambio.
    func testCargoVacioSubeNulo() {
        let base = CamposIglesia.escribir(CamposIglesia.de(ficha()))
        var c = ficha()
        c.pastorCargo = "  "
        let parche = CamposIglesia.parche(c, base: base)
        XCTAssertEqual(parche, ["pastor_cargo": .texto(nil)])
    }

    /// La base sobrevive a su propio JSON: números, booleanos y nulos incluidos.
    func testLaBaseSeLeeComoSeEscribio() {
        var c = ficha()
        c.saldoInicial = 2_500_000
        c.imprimirFirmas = false
        c.secretarioCargo = ""
        let campos = CamposIglesia.de(c)
        XCTAssertEqual(CamposIglesia.leer(CamposIglesia.escribir(campos)), campos)
    }
}
