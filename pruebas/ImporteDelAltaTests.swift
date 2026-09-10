import XCTest
@testable import Tamio

/// **Caza el segundo parseador de dinero.**
///
/// En la app hay dos formas de leer un importe escrito por una persona:
/// `Money.desdeTexto`, que aguanta los dos mundos ("1.960,00" y "1,960.00"), y
/// `NuevoMovimientoView.aCentavos`, que borra las comas y hace
/// `Double(...) ?? 0`. El alta manual —la pantalla por la que entra CADA
/// ingreso y CADA gasto del teléfono— usa la segunda.
///
/// Con la región del aparato en español el `.decimalPad` escribe COMA, así que
/// "12,50" es lo que la tesorera teclea para doce cincuenta. Estas pruebas
/// comparan lo que guardaría el alta con lo que el importador de aportes
/// —`Money.desdeTexto`, el parseador bueno— entiende del mismo texto.
final class ImporteDelAltaTests: XCTestCase {

    /// Doce cincuenta con coma decimal se guarda como MIL DOSCIENTOS CINCUENTA.
    func testLaComaDecimalMultiplicaPorCien() {
        XCTAssertEqual(Money.desdeTexto("12,50"), 1250)
        XCTAssertEqual(NuevoMovimientoView.aCentavos("12,50"), 1250,
                       "Guardó \(Money.fmt(NuevoMovimientoView.aCentavos("12,50"))) en vez de $12.50")
    }

    /// Mil novecientos sesenta con formato español se guarda como $1.96.
    func testElFormatoEspanolEnteroSeVaAlSuelo() {
        XCTAssertEqual(Money.desdeTexto("1.960,00"), 196_000)
        XCTAssertEqual(NuevoMovimientoView.aCentavos("1.960,00"), 196_000,
                       "Guardó \(Money.fmt(NuevoMovimientoView.aCentavos("1.960,00"))) en vez de $1,960.00")
    }

    /// Un peso cincuenta.
    func testUnDecimalSuelto() {
        XCTAssertEqual(Money.desdeTexto("1,5"), 150)
        XCTAssertEqual(NuevoMovimientoView.aCentavos("1,5"), 150,
                       "Guardó \(Money.fmt(NuevoMovimientoView.aCentavos("1,5")))")
    }

    /// Pegado desde el portapapeles —un correo del banco, una hoja de cálculo—
    /// con símbolo y espacio de miles. `Money.desdeTexto` lo entiende.
    func testPegarUnImporteConSimbolo() {
        XCTAssertEqual(Money.desdeTexto("$ 1 960,00"), 196_000)
        XCTAssertEqual(NuevoMovimientoView.aCentavos("$ 1 960,00"), 196_000,
                       "Guardó \(Money.fmt(NuevoMovimientoView.aCentavos("$ 1 960,00")))")
    }

    /// **Lo que no se entiende NO puede valer cero.** `Double(...) ?? 0`
    /// convierte cualquier basura en un movimiento de $0.00 que sí se guarda:
    /// el botón solo mira `!importe.isEmpty`.
    func testLoQueNoSeEntiendeNoDebeValerCero() {
        for basura in ["$ 1 960,00", "1.960,00 MXN", "mil", "..", "—"] {
            XCTAssertNotEqual(NuevoMovimientoView.aCentavos(basura), 0,
                              "\"\(basura)\" se guardaría como $0.00")
        }
    }

    /// Un importe negativo entra tal cual: el signo no se filtra en ningún
    /// sitio y el tipo (ingreso/gasto) ya lleva la dirección del dinero.
    func testNoSeCuelaUnImporteNegativo() {
        let c = NuevoMovimientoView.aCentavos("-50")
        XCTAssertGreaterThanOrEqual(c, 0,
            "Un ingreso de \(Money.fmt(c)) entra con el signo puesto: la dirección del "
            + "dinero ya la lleva el tipo, así que un importe negativo la invierte dos veces")
    }

    /// Notación científica: `Double` la acepta y el campo la deja escribir con
    /// teclado externo o pegando.
    func testNotacionCientifica() {
        XCTAssertLessThan(NuevoMovimientoView.aCentavos("1e9"), 100_000_000,
                          "Guardó \(Money.fmt(NuevoMovimientoView.aCentavos("1e9"))) "
                          + "de un campo en el que solo se tecleó «1e9»")
    }

    /// El otro sentido: lo que el alta escribe en el campo al EDITAR usa punto
    /// fijo (`%.2f`), así que en región española el campo se abre con un punto
    /// que el teclado de esa región no sabe escribir.
    func testElCampoSeRellenaConPuntoSiempre() {
        XCTAssertEqual(NuevoMovimientoView.aTexto(196_000), "1960.00")
    }
}
