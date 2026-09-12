import XCTest
@testable import Tamio

/// **Las tres formas que tiene de verdad `transactions.fecha`, medidas contra
/// `Fechas.desdeTexto`.**
///
/// Escrita el 12-sep-2026, en la pasada de QA del iPhone, porque la medida
/// anterior se había quedado vieja y con ella una conclusión. El 10-sep se
/// midió que «`transactions` es la ÚNICA tabla cuyas fechas llevan hora, 34 de
/// 34» (ver `FechaSoloFechaTests`), y de ahí salió la regla de que a los
/// movimientos la fecha que retrocede NO les alcanza. Hoy la tabla tiene **84
/// filas y tres formas distintas**:
///
/// | forma                  | filas | de dónde sale |
/// |------------------------|-------|---------------|
/// | `2026-09-11T13:16:07Z` |    46 | la app nativa |
/// | `2026-07-12 02:28`     |    33 | la app web    |
/// | `2026-07-27`           |     5 | la app web    |
///
/// `transactions.fecha` es **`text`**, no `date` ni `timestamptz`, así que la
/// base no impone ninguna forma y cada cliente escribe la suya. Eso es el dato
/// de fondo: la conclusión del 10-sep era correcta para las filas que había
/// entonces, y dejó de serlo al crecer la tabla. **Una medida sobre los datos
/// no es una regla sobre el esquema.**
///
/// Esta prueba no arregla nada: fija qué devuelve hoy cada forma, para que la
/// decisión de convención se tome sobre números y para que un cambio futuro en
/// `desdeTexto` no pase inadvertido.
final class FechasDelServidorTests: XCTestCase {

    /// Las tres formas, tal cual salen de `select fecha from transactions`.
    private let instanteZ = "2026-09-11T13:16:07Z"
    private let sinZonaNiSegundos = "2026-07-12 02:28"
    private let diaSuelto = "2026-07-27"

    private func utc(_ formato: String, _ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = formato
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }

    /// Control positivo, y la razón de que el resto se pueda creer: si el
    /// aparato estuviera en UTC esta prueba no podría distinguir nada.
    func testLaZonaDelAparatoNoEsUTC() throws {
        let desvio = TimeZone.current.secondsFromGMT()
        print("QA-ZONA: \(TimeZone.current.identifier) desvío \(desvio)s")
        try XCTSkipIf(desvio == 0,
                      "El aparato está en UTC: esta prueba no mide nada aquí.")
    }

    /// La forma que escribe la app nativa. Es un instante y tiene que volver
    /// como el instante exacto.
    func testElInstanteConZVuelveExacto() {
        let d = Fechas.desdeTexto(instanteZ)
        XCTAssertNotNil(d, "la forma que escribe la propia app no se parsea")
        guard let d else { return }
        XCTAssertEqual(utc("yyyy-MM-dd'T'HH:mm:ss'Z'", d), instanteZ)
    }

    /// **La forma de la app web, sin zona y SIN SEGUNDOS.** Los formatos que
    /// prueba `desdeTexto` son `yyyy-MM-dd'T'HH:mm:ss`, `yyyy-MM-dd HH:mm:ss` y
    /// `yyyy-MM-dd`: ninguno es `yyyy-MM-dd HH:mm`. La pregunta que esta prueba
    /// contesta es si `DateFormatter` acepta el prefijo —y entonces la hora se
    /// pierde pero el día se salva— o devuelve `nil` —y entonces el
    /// `?? Date()` de `MotorSincronizacion:2843` le pone la fecha de HOY a un
    /// movimiento de julio, que sería perder el dato, no desplazarlo—.
    func testLaFormaDeLaWebSinSegundos() {
        let d = Fechas.desdeTexto(sinZonaNiSegundos)
        print("QA-SINSEG: \(sinZonaNiSegundos) -> " +
              (d.map { utc("yyyy-MM-dd'T'HH:mm:ss'Z'", $0) } ?? "nil"))
        XCTAssertNotNil(d, """
            `desdeTexto` no sabe leer la forma que escribe la app web \
            (33 de las 84 filas de transactions). Con nil, \
            MotorSincronizacion:2843 cae al `?? Date()` y el movimiento pasa a \
            tener la fecha de hoy.
            """)
        guard let d else { return }
        XCTAssertEqual(utc("yyyy-MM-dd", d), "2026-07-12",
                       "el día no sobrevive al parseo")
    }

    /// El día suelto: 5 filas. Vuelve como medianoche **UTC**, que al oeste de
    /// Greenwich es el día anterior en cuanto se formatea en local.
    func testElDiaSueltoEsMedianocheUTCyPorEsoRetrocede() {
        guard let d = Fechas.desdeTexto(diaSuelto) else {
            return XCTFail("el día suelto no se parsea")
        }
        XCTAssertEqual(utc("yyyy-MM-dd HH:mm", d), "2026-07-27 00:00",
                       "no es medianoche UTC; la premisa de Z4 habría cambiado")

        // Y la consecuencia, que es lo que ve quien usa la app: el mismo
        // instante formateado en la zona del aparato.
        let enLocal = Fechas.corta(d)
        let enUTC = utc("MMM d, yyyy", d)
        print("QA-DIA: \(diaSuelto) -> local «\(enLocal)» · UTC «\(enUTC)»")

        // `diaDeCalendario` es la media solución que ya está escrita: para la
        // forma canónica devuelve medianoche LOCAL, y entonces no retrocede.
        guard let dCal = Fechas.diaDeCalendario(diaSuelto) else {
            return XCTFail("diaDeCalendario no leyó la forma canónica")
        }
        XCTAssertEqual(Fechas.corta(dCal), utc("MMM d, yyyy", dCal),
                       "diaDeCalendario debería coincidir consigo mismo en local")
        print("QA-DIACAL: \(diaSuelto) -> local «\(Fechas.corta(dCal))»")
    }

    /// El contraste que da la decisión: sobre la MISMA cadena, el camino de hoy
    /// y el que ya existe escrito dan días distintos al oeste de Greenwich.
    func testLosDosCaminosDiscrepanEnElDia() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() >= 0,
                      "Al este de Greenwich no hay desvío que medir.")
        guard let viejo = Fechas.desdeTexto(diaSuelto),
              let nuevo = Fechas.diaDeCalendario(diaSuelto) else {
            return XCTFail("una de las dos no parseó")
        }
        let dViejo = Fechas.corta(viejo), dNuevo = Fechas.corta(nuevo)
        print("QA-DISCREPA: desdeTexto «\(dViejo)» · diaDeCalendario «\(dNuevo)»")
        XCTAssertNotEqual(dViejo, dNuevo, """
            Los dos caminos coinciden: o el aparato está en UTC —y el control \
            positivo debería haber saltado— o `desdeTexto` cambió.
            """)
    }

    /// **La consecuencia completa, que es el hallazgo: no se desplaza el día, se
    /// pierden el día Y la hora.**
    ///
    /// `MotorSincronizacion:2843-2859` hace dos cosas con esa cadena:
    ///
    ///     let fechaDate = Fechas.desdeTexto(fecha) ?? Date()
    ///     let hf = DateFormatter()               // <- sin timeZone: la del aparato
    ///     hf.dateFormat = "HH:mm"
    ///     ... hora: hf.string(from: fechaDate),
    ///         fecha: fechaDate.timeIntervalSince1970
    ///
    /// Aquí se reproducen esas dos líneas tal cual —el tipo que las contiene es
    /// privado del motor y no se puede instanciar desde fuera, así que esto es
    /// un espejo, no el camino real; si el motor cambia, esta prueba deja de
    /// hablar de él y hay que volver a mirarla—.
    func testElMovimientoDeLaWebPierdeElDiaYLaHora() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() >= 0,
                      "Al este de Greenwich no hay desvío que medir.")
        let fechaDate = Fechas.desdeTexto(sinZonaNiSegundos) ?? Date()
        let hf = DateFormatter()
        hf.locale = Locale(identifier: "en_US_POSIX")
        hf.dateFormat = "HH:mm"
        let hora = hf.string(from: fechaDate)
        let dia = Fechas.corta(fechaDate)

        print("QA-PERDIDA: la web escribió «\(sinZonaNiSegundos)» · " +
              "el teléfono enseña «\(dia)» a las «\(hora)»")

        // Lo que la web escribió: 12 de julio, 02:28.
        XCTAssertEqual(hora, "02:28", """
            La hora del movimiento no es la que escribió la web. \
            `desdeTexto` no sabe leer `yyyy-MM-dd HH:mm` —sus formatos piden \
            segundos—, acepta solo el prefijo del día y devuelve medianoche \
            UTC, así que la hora se inventa desde la zona del aparato.
            """)
        XCTAssertEqual(dia, utc("MMM d, yyyy", Fechas.diaDeCalendario("2026-07-12")!),
                       "el día tampoco es el que escribió la web")
    }
}
