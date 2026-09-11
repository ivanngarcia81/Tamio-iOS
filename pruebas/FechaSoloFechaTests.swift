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

    /// **El inventario de quién lee en qué zona.** No acusa a nadie: informa.
    ///
    /// La primera versión de esta prueba SÍ acusaba —daba por rotos `corta`,
    /// `cortaConHora`, `claveDia` y `diaLegibleLargo` porque con una fecha
    /// «solo fecha» enseñan el día anterior— y la acusación estaba mal
    /// planteada: esos cuatro formatean un INSTANTE en la hora del aparato, y
    /// eso es lo correcto para `transactions`, cuyas 34 fechas vivas llevan
    /// hora. El fallo nunca fue del ayudante: era alimentarlo con un día de
    /// calendario leído como medianoche UTC.
    ///
    /// Lo que esta prueba fija es el reparto, para que no se cruce:
    ///
    /// - **Instantes** (`transactions`): se leen con `desdeTexto` y se pintan
    ///   con `corta` / `cortaConHora` / `diaLegibleLargo`, en hora local.
    /// - **Días de calendario** (las otras ocho columnas): se leen con
    ///   `diaDeCalendario` y se pintan con `diaLegible` / `diaSemanaCorto` /
    ///   `numeroDeDia`, que fijan UTC a propósito.
    ///
    /// Cruzarlos es el fallo, y el que estaba cruzado —`SeguimientoNota`— lo
    /// caza la prueba de abajo.
    func testElRepartoDeZonasSigueSiendoElQueSeDocumento() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se distingue")
        let dia = try XCTUnwrap(Fechas.diaDeCalendario(textoISO))
        let instante = try XCTUnwrap(Fechas.desdeTexto(textoISO))

        for (nombre, salida) in [("diaLegible", Fechas.diaLegible(textoISO)),
                                 ("numeroDeDia", Fechas.numeroDeDia(textoISO)),
                                 ("corta(diaDeCalendario)", Fechas.corta(dia)),
                                 ("claveDia(diaDeCalendario)", Fechas.claveDia(dia))] {
            NSLog("[QA-FECHA] %@ → %@", nombre, salida)
        }

        // **Un día de calendario no se mueve, lo lea quien lo lea.**
        XCTAssertEqual(Fechas.claveDia(dia), textoISO,
                       "### diaDeCalendario + claveDia tienen que ser inversos")
        XCTAssertTrue(Fechas.corta(dia).contains("6"),
                      "### un día de calendario pintado en local enseña otro día")
        XCTAssertEqual(Fechas.numeroDeDia(textoISO), "6")
        XCTAssertTrue(Fechas.diaLegible(textoISO).contains("6"))

        // Y el instante sigue siendo un instante: medianoche UTC del día 6 ES
        // el día 5 por la tarde en Nueva York, y enseñarlo así es correcto.
        XCTAssertNotEqual(Fechas.claveDia(instante), Fechas.claveDia(dia),
                          "### si estos dos coinciden, el aparato está en UTC y la prueba no mide")
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

    /// **El control del arreglo, y la razón de que no valga codificar en UTC.**
    ///
    /// Una nota NUEVA nace con `Date()` —la hora actual, no medianoche
    /// (`MembresiaView.swift:1564`)—. Si la escritura se pasara a UTC, una nota
    /// creada de noche en Nueva York se guardaría con la fecha de MAÑANA. Esta
    /// prueba fija esa mitad: sea cual sea el arreglo, el día que se guarda es
    /// el día LOCAL de la nota.
    func testUnaNotaCreadaDeNocheSeGuardaConElDiaDeHoy() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se reproduce")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        // 23:50 de hoy, hora local: en Nueva York ya es mañana en UTC.
        let hoy = Date()
        let casiMedianoche = cal.date(bySettingHour: 23, minute: 50, second: 0, of: hoy) ?? hoy
        let diaLocal = Fechas.claveDia(casiMedianoche)

        let nota = SeguimientoNota(tipo: .otro, fecha: casiMedianoche,
                                   descripcion: "creada de noche")
        let texto = String(data: try JSONEncoder().encode(nota), encoding: .utf8) ?? ""
        let guardado = try JSONDecoder().decode([String: AnyDecodableFecha].self,
                                                from: Data(texto.utf8))
        let escrito = guardado["fecha"]?.texto ?? ""
        NSLog("[QA-FECHA] nota de las 23:50 → se guardó %@ (día local %@)", escrito, diaLocal)

        XCTAssertEqual(escrito, diaLocal,
                       "### una nota creada de noche se guardó con otro día")

        // Y releerla no la mueve.
        let releida = try JSONDecoder().decode(SeguimientoNota.self, from: Data(texto.utf8))
        XCTAssertEqual(Fechas.claveDia(releida.fecha), diaLocal,
                       "### releer la nota movió su día")
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
