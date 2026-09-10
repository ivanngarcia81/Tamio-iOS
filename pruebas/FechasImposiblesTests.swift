import XCTest
@testable import Tamio

/// Fechas que una persona escribe mal o que otro programa exporta raro.
final class FechasImposibles: XCTestCase {

    /// **El 31 de febrero no existe.** Si el importador lo acepta, el aporte
    /// entra con otra fecha y el mes al que se imputa cambia.
    func testTreintaYUnoDeFebrero() {
        let d = Fechas.desdeTextoFlexible("31/02/2026")
        if let d { print("31-FEB se leyó como \(Fechas.claveDia(d))") }
        XCTAssertNil(d, "31/02/2026 se aceptó")
    }

    /// Año 1900 y año lejano: se aceptan, y eso está bien; lo que importa es
    /// que la app no se rompa al enseñarlos.
    func testAnioViejoYAnioLejano() {
        XCTAssertNotNil(Fechas.desdeTexto("1900-01-01"))
        XCTAssertNotNil(Fechas.desdeTexto("2999-12-31"))
        print("1900 → \(Fechas.diaLegible("1900-01-01"))")
        print("2999 → \(Fechas.diaLegible("2999-12-31"))")
    }

    /// **La ambigüedad día/mes.** "03/09/2026" es el 3 de septiembre en España
    /// y México; el orden que la app prueba primero lo dice. Con "09/03/2026"
    /// el archivo de un programa en inglés entra corrido seis meses.
    func testDiaPrimeroOMesPrimero() {
        let a = Fechas.desdeTextoFlexible("03/09/2026")
        XCTAssertEqual(a.map(Fechas.claveDia), "2026-09-03")
        // Un CSV exportado por un programa en inglés escribe mes/día:
        let b = Fechas.desdeTextoFlexible("09/03/2026")
        print("09/03/2026 se leyó como \(b.map(Fechas.claveDia) ?? "nil")")
    }
}
