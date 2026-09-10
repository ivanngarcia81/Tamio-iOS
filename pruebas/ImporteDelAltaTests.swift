import XCTest
@testable import Tamio

/// **El importe del alta manual: el mismo texto tiene que valer lo mismo en las
/// dos puertas por las que entra dinero.**
///
/// Había dos parseadores. `Money.desdeTexto` aguanta los dos mundos —"1.960,00"
/// y "1,960.00"— y lo usan el importador de aportes, los recurrentes y la
/// segunda firma; `NuevoMovimientoView.aCentavos` borraba las comas y hacía
/// `Double(...) ?? 0`, y era el que usaba **el alta manual**, o sea la pantalla
/// por la que entra cada ingreso y cada gasto tecleado en el teléfono.
///
/// Con la región del aparato en español eso costaba un factor de cien: el
/// `.decimalPad` de esa región ofrece `1|2|3|4|5|6|7|8|9|,|0|Delete` —volcado
/// del teclado con la app corriendo, en `ImporteEnPantallaUITests`—, así que
/// "12,50" es lo que se teclea para doce cincuenta, y borrando la coma quedaba
/// $1,250.00 en el libro.
///
/// Estas pruebas comparan las dos puertas con el mismo texto. **Estaban en rojo
/// y ahora pasan**: si alguna vuelve a fallar, es que el alta se volvió a
/// escribir su propio parseador.
final class ImporteDelAltaTests: XCTestCase {

    /// El alta y el importador leen igual, caso por caso.
    func comprobar(_ texto: String, _ esperado: Centavos?,
                   _ linea: UInt = #line) {
        XCTAssertEqual(Money.desdeTexto(texto), esperado,
                       "el importador leyó otra cosa de «\(texto)»", line: linea)
        XCTAssertEqual(NuevoMovimientoView.centavos(texto), esperado,
                       "el alta leyó otra cosa de «\(texto)»", line: linea)
    }

    /// Doce cincuenta con coma decimal, que es lo único que el teclado español
    /// deja escribir.
    func testLaComaDecimalNoMultiplicaPorCien() { comprobar("12,50", 1250) }

    /// Mil novecientos sesenta con formato español entero.
    func testElFormatoEspanolEntero() { comprobar("1.960,00", 196_000) }

    /// Y el mismo importe con formato inglés.
    func testElFormatoInglesEntero() { comprobar("1,960.00", 196_000) }

    /// Un decimal suelto.
    func testUnDecimalSuelto() { comprobar("1,5", 150) }

    /// Pegado desde el portapapeles —un correo del banco, una hoja de cálculo—
    /// con símbolo de moneda y espacio de miles.
    func testPegarUnImporteConSimbolo() { comprobar("$ 1 960,00", 196_000) }

    /// **Lo que no se entiende NO puede valer cero.** `Double(...) ?? 0`
    /// convertía cualquier basura en un movimiento de $0.00 que sí se guardaba,
    /// porque el botón solo miraba `!importe.isEmpty`. Ahora devuelve `nil` y
    /// `guardadoHabilitado` no enciende Guardar.
    func testLoQueNoSeEntiendeNoValeCero() {
        for basura in ["", "   ", "mil", "—", "abc"] {
            XCTAssertNil(NuevoMovimientoView.centavos(basura),
                         "«\(basura)» se leería como \(NuevoMovimientoView.centavos(basura) ?? -1)")
        }
    }

    /// El campo se rellena con el separador del aparato, no con un punto fijo:
    /// en región española se abría con "1960.00" y el teclado de esa región no
    /// tiene con qué escribir ese punto.
    func testElCampoSeRellenaConElSeparadorDelAparato() {
        let escrito = NuevoMovimientoView.aTexto(196_000)
        XCTAssertEqual(NuevoMovimientoView.centavos(escrito), 196_000,
                       "lo que el campo escribe («\(escrito)») no vuelve a entrar igual")
        XCTAssertFalse(escrito.contains(","), "no debe llevar separador de miles: «\(escrito)»")
    }

    /// **La ida y vuelta, que es lo que hace una edición segura.** Abrir un
    /// movimiento para corregirlo y guardarlo sin tocar el importe no puede
    /// cambiar la cifra.
    func testLaIdaYVueltaNoMueveLaCifra() {
        for c: Centavos in [1, 99, 100, 1250, 196_000, 1_234_567, 100_000_000] {
            XCTAssertEqual(NuevoMovimientoView.centavos(NuevoMovimientoView.aTexto(c)), c,
                           "\(c) centavos no sobrevivieron a la ida y vuelta")
        }
    }
}
