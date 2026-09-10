import XCTest
@testable import Tamio

/// **La comprobación que `docs/COMPROBACION-DINERO.md` llama la más importante
/// de la lista, medida en el aparato y con su zona horaria de verdad.**
///
/// `Fechas.desdeTexto("2026-09-06")` devuelve **medianoche UTC**. Cualquier
/// formateador que no fije la zona lo lee con la del aparato y, al oeste de
/// Greenwich —que es donde está la iglesia—, enseña el día ANTERIOR.
///
/// Lo que la lista decía que faltaba saber es **hasta dónde llega**. Medido en
/// el servidor el 10-sep: `transactions` es la ÚNICA tabla que guarda la fecha
/// con hora (34 de 34); las otras ocho columnas vivas son «solo fecha» —cortes,
/// depósitos, servicios, agenda, actas, cartas y dos del padrón—, o sea 29
/// valores que entran por este camino.
///
/// Esta prueba no afirma cuál es el ayudante correcto: **imprime lo que da cada
/// uno** con una fecha conocida y falla solo en los que se corren de día. Así
/// el informe dice qué pantallas mienten y cuáles no, en vez de "las fechas
/// están mal".
final class FechaSoloFechaTests: XCTestCase {

    /// Domingo. Elegido a propósito: si algo se corre, cae en sábado y eso se
    /// ve además en la pastilla del día de la semana.
    private let textoISO = "2026-09-06"
    private let diaEsperado = 6
    private let mesEsperado = 9

    override func setUp() {
        NSLog("[QA-FECHA] zona del aparato: %@ (offset %d s)",
              TimeZone.current.identifier, TimeZone.current.secondsFromGMT())
    }

    /// El control positivo: sin él, una prueba que pase no dice nada —podría
    /// estar corriendo en UTC, donde NADA de esto se reproduce—.
    func testControlLaZonaDelAparatoNoEsUTC() throws {
        let offset = TimeZone.current.secondsFromGMT()
        NSLog("[QA-FECHA] CONTROL offset=%d", offset)
        try XCTSkipIf(offset == 0,
                      "el aparato está en UTC: aquí este fallo no se puede reproducir")
        XCTAssertLessThan(offset, 0,
                          "la iglesia está al oeste de Greenwich; con offset positivo el fallo va al revés")
    }

    /// El parseo en sí, que es el origen de todo.
    func testDesdeTextoDevuelveMedianocheUTC() throws {
        let d = try XCTUnwrap(Fechas.desdeTexto(textoISO))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour], from: d)
        NSLog("[QA-FECHA] desdeTexto → %@ (UTC %d-%02d-%02d %02dh)",
              String(describing: d), c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0)
        XCTAssertEqual(c.day, diaEsperado)
        XCTAssertEqual(c.hour, 0, "no es medianoche UTC: el diagnóstico de abajo no aplica")
    }

    /// **El barrido.** Cada ayudante que produce texto para la pantalla, con la
    /// misma fecha. El que devuelva el día 5 miente.
    func testQueAyudantesSeCorrenDeDia() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se reproduce")

        let d = try XCTUnwrap(Fechas.desdeTexto(textoISO))
        var fallan: [String] = []

        func revisar(_ nombre: String, _ salida: String) {
            let bien = salida.contains("\(diaEsperado)")
                && !(salida.contains("\(diaEsperado - 1)") && !salida.contains("\(diaEsperado)"))
            NSLog("[QA-FECHA] %@ → %@", nombre, salida)
            // El día 5 a secas, sin el 6 por ningún lado, es el corrimiento.
            if salida.contains(" 5") || salida.hasPrefix("5 ") || salida == "5" {
                if !salida.contains("6") { fallan.append("\(nombre) → \(salida)") }
            }
            _ = bien
        }

        revisar("corta(Date)", Fechas.corta(d))
        revisar("cortaConHora(Date)", Fechas.cortaConHora(d, hora: "10:00"))
        revisar("diaLegible(texto)", Fechas.diaLegible(textoISO))
        revisar("diaSemanaCorto(texto)", Fechas.diaSemanaCorto(textoISO))
        revisar("numeroDeDia(texto)", Fechas.numeroDeDia(textoISO))
        revisar("claveDia(Date)", Fechas.claveDia(d))
        revisar("iso(Date)", Fechas.iso(d))
        revisar("diaLegibleLargo(Date)", Fechas.diaLegibleLargo(d))

        XCTAssertTrue(fallan.isEmpty,
                      "### estos ayudantes enseñan el día anterior con una fecha «solo fecha»: "
                      + fallan.joined(separator: " | "))
    }
}
