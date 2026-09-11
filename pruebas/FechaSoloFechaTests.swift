import XCTest
@testable import Tamio

/// **La comprobación que `docs/COMPROBACION-DINERO.md` llama la más importante
/// de la lista, medida EN EL APARATO y con su zona horaria de verdad.**
///
/// `Fechas.desdeTexto("2026-09-06")` devuelve **medianoche UTC**. Un formateador
/// que no fije la zona lo lee con la del aparato y, al oeste de Greenwich
/// —donde está la iglesia—, enseña el día ANTERIOR.
///
/// Medido en el servidor el 10-sep: `transactions` es la ÚNICA tabla cuyas
/// fechas llevan hora (34 de 34); las otras ocho columnas vivas son «solo
/// fecha» —cortes, depósitos, servicios, agenda, actas, cartas y dos del
/// padrón—, 29 valores que entran por este camino.
///
/// **Aviso de instrumento, que costó una corrida.** La primera versión de esta
/// prueba buscaba "un 5 sin ningún 6" en la salida, y `"Sep 5, 2026"` contiene
/// el 6 de «2026»: pasaba en verde midiendo exactamente nada. Ahora cada
/// ayudante se compara contra su MISMO formato renderizado en UTC, que es la
/// respuesta correcta por construcción.
final class FechaSoloFechaTests: XCTestCase {

    /// Domingo, a propósito: si algo se corre cae en sábado.
    private let textoISO = "2026-09-06"

    private func enUTC(_ formato: String, _ d: Date) -> String {
        let f = DateFormatter()
        f.locale = L.locale
        f.dateFormat = formato
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }

    /// El control positivo: sin él una prueba verde no dice nada, porque en UTC
    /// este fallo NO se reproduce.
    func testControlLaZonaDelAparatoNoEsUTC() throws {
        let offset = TimeZone.current.secondsFromGMT()
        NSLog("[QA-FECHA] zona %@ offset %d", TimeZone.current.identifier, offset)
        try XCTSkipIf(offset == 0, "el aparato está en UTC: aquí no se reproduce")
        XCTAssertLessThan(offset, 0, "la iglesia está al oeste de Greenwich")
    }

    func testDesdeTextoDevuelveMedianocheUTC() throws {
        let d = try XCTUnwrap(Fechas.desdeTexto(textoISO))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.day, .hour], from: d)
        XCTAssertEqual(c.day, 6)
        XCTAssertEqual(c.hour, 0, "no es medianoche UTC: el resto del diagnóstico no aplica")
    }

    /// **El barrido**, cada ayudante contra su propio formato en UTC.
    func testQueAyudantesSeCorrenDeDia() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se reproduce")
        let d = try XCTUnwrap(Fechas.desdeTexto(textoISO))

        var fallan: [String] = []
        func revisar(_ nombre: String, _ salida: String, esperado: String) {
            NSLog("[QA-FECHA] %@ → %@ (esperado %@)", nombre, salida, esperado)
            if salida != esperado { fallan.append("\(nombre): «\(salida)» en vez de «\(esperado)»") }
        }

        let fCorta = L.t("d MMM yyyy", "MMM d, yyyy")
        revisar("corta", Fechas.corta(d), esperado: enUTC(fCorta, d))
        revisar("cortaConHora", Fechas.cortaConHora(d, hora: "10:00"),
                esperado: enUTC(fCorta, d) + ", 10:00")
        revisar("claveDia", Fechas.claveDia(d), esperado: "2026-09-06")
        revisar("diaLegibleLargo", Fechas.diaLegibleLargo(d),
                esperado: enUTC(L.t("d 'de' MMMM 'de' yyyy", "MMMM d, yyyy"), d))
        // Estos cuatro YA fijan UTC y son el control negativo del barrido: si
        // alguno apareciera en la lista, el diagnóstico estaría mal planteado.
        revisar("diaLegible", Fechas.diaLegible(textoISO), esperado: enUTC(fCorta, d))
        revisar("diaSemanaCorto", Fechas.diaSemanaCorto(textoISO),
                esperado: Fechas.diaSemanaCorto(textoISO))
        revisar("numeroDeDia", Fechas.numeroDeDia(textoISO), esperado: "6")
        revisar("iso", Fechas.iso(d), esperado: "2026-09-06T00:00:00Z")

        XCTAssertTrue(fallan.isEmpty,
                      "### con una fecha «solo fecha» estos ayudantes dan el día anterior: "
                      + fallan.joined(separator: " | "))
    }

    /// **Lo grave no es el rótulo: es que `claveDia` también ESCRIBE.**
    ///
    /// `SeguimientoNota` decodifica con `desdeTextoFlexible` —que para
    /// `"yyyy-MM-dd"` da medianoche UTC— y codifica con `Fechas.claveDia`, que
    /// formatea en la zona del aparato. Así que **cada ida y vuelta resta un
    /// día**, y se acumula: no es un formateo feo, es el dato moviéndose.
    ///
    /// Los mismos dos extremos están en `DepositosViewModel.textoFecha` (:228),
    /// `CartasViewModel` (:107) y `Secretaria.swift` (:914).
    func testUnaIdaYVueltaDeSeguimientoRestaUnDia() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se reproduce")

        let json = #"{"fecha":"2026-09-06","texto":"visita","tipo":"otro","completado":false}"#
        let dec = JSONDecoder(), enc = JSONEncoder()

        // **Se lee el TEXTO guardado, no se vuelve a formatear.** Medir con
        // `Fechas.claveDia` sobre la fecha releída añade un corrimiento propio
        // y el resultado cuenta de más: la primera versión de esta prueba
        // decía "dos días" en la primera vuelta cuando en realidad es uno por
        // cada escritura.
        var texto = json
        var vistas: [String] = []
        for _ in 0..<3 {
            let nota = try dec.decode(SeguimientoNota.self, from: Data(texto.utf8))
            texto = String(data: try enc.encode(nota), encoding: .utf8) ?? ""
            let guardado = try dec.decode([String: AnyDecodableFecha].self,
                                          from: Data(texto.utf8))
            vistas.append(guardado["fecha"]?.texto ?? "«sin fecha»")
        }
        NSLog("[QA-FECHA] lo que queda GUARDADO en cada vuelta: %@",
              vistas.joined(separator: " → "))

        XCTAssertEqual(vistas.first, "2026-09-06",
                       "### una sola escritura ya movió la fecha de la nota de seguimiento")
        XCTAssertEqual(Set(vistas).count, 1,
                       "### y se mueve otra vez en cada vuelta: \(vistas.joined(separator: " → "))")
    }
}

/// Lee un valor de JSON como texto sin saber su tipo. Sirve para mirar lo que
/// quedó ESCRITO en vez de volver a formatearlo, que es lo que falseaba la
/// medida.
private struct AnyDecodableFecha: Decodable {
    let texto: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        texto = (try? c.decode(String.self)) ?? ""
    }
}
