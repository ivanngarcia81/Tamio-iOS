import XCTest

/// **Que a la segunda firma se pueda LLEGAR.**
///
/// La tarjeta solo salía si `dobleFirmaPedida` ya estaba encendido, y no había
/// en toda la app un sitio que lo encendiera: el único `true` vivía en
/// `MockDepositosRepository`. O sea que la función estaba entera —el conteo a
/// ciegas, el veredicto, quitar la firma— y con datos de verdad no se podía
/// alcanzar; y el aviso "Falta la segunda firma" de Por revisar no podía
/// dispararse nunca.
///
/// Esta prueba recorre lo que hace una tesorera: abre un corte, pide la segunda
/// firma, y comprueba que aparece quien puede firmarla.
///
/// Se corre con el modo revisión ENCENDIDO.
final class SegundaFirmaSeAlcanza: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func textos() -> [String] { app.staticTexts.allElementsBoundByIndex.map(\.label) }

    /// **Solo lo que de verdad se ve.** Con una hoja arriba, XCUITest sigue
    /// listando los textos de la pantalla que queda DEBAJO: dando por buenos
    /// esos, la hoja de la firma "enseñaba" el total del corte, que está en el
    /// fondo. `isHittable` es lo que distingue una cosa de la otra.
    func textosVisibles() -> [String] {
        app.staticTexts.allElementsBoundByIndex.filter(\.isHittable).map(\.label)
    }

    /// Abre el corte que NO trae la segunda firma pedida de la maqueta, que es
    /// el caso de un corte de verdad recién creado.
    func abrirCorteSinFirmaPedida() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Deposits'")).firstMatch.tap()
        sleep(3)
        let fila = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Wednesday, September 2 offerings'")).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 6), "no encuentro el corte")
        fila.tap(); sleep(3)
    }

    func testSePuedePedirLaSegundaFirmaDesdeElCorte() {
        abrirCorteSinFirmaPedida()
        print("CORTE:" + textos().joined(separator: "|"))
        parada("corte-antes")

        // La tarjeta tiene que estar, aunque la firma no esté pedida: si solo
        // sale cuando ya está encendida, no hay forma de encenderla.
        XCTAssertTrue(textos().contains("SECOND SIGNATURE"),
                      "la tarjeta de la segunda firma no aparece en un corte que no la pide")

        let interruptor = app.switches.matching(
            NSPredicate(format: "label CONTAINS 'count this money'")).firstMatch
        guard interruptor.waitForExistence(timeout: 5) else {
            print("INTERRUPTORES:" + app.switches.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            return XCTFail("no hay interruptor para pedir la segunda firma")
        }
        interruptor.tap(); sleep(3)
        parada("corte-pedida")

        let despues = textos()
        print("TRAS-PEDIR:" + despues.joined(separator: "|"))
        XCTAssertTrue(despues.contains { $0.contains("Second signature missing") },
                      "se pidió la firma y el corte no lo refleja")
        XCTAssertTrue(app.buttons["Second signature"].exists,
                      "no aparece el botón para firmar")
    }

    /// Y que el conteo sea a ciegas: la hoja pide la cifra **sin** enseñar el
    /// total del corte, que es lo que hace que el control valga algo.
    func testElConteoEsACiegas() {
        abrirCorteSinFirmaPedida()
        let interruptor = app.switches.matching(
            NSPredicate(format: "label CONTAINS 'count this money'")).firstMatch
        guard interruptor.waitForExistence(timeout: 5) else { return XCTFail("sin interruptor") }
        if (interruptor.value as? String) == "0" { interruptor.tap(); sleep(3) }

        // El total del corte, para comprobar que la hoja NO lo enseña.
        let total = textosVisibles().first { $0.hasPrefix("$") } ?? "?"
        print("TOTAL-DEL-CORTE:\(total)")

        app.buttons["Second signature"].tap(); sleep(3)
        let enLaHoja = textosVisibles()
        print("HOJA-FIRMA:" + enLaHoja.joined(separator: "|"))
        parada("hoja-firma")
        XCTAssertFalse(enLaHoja.contains(total),
                       "la hoja enseña el total (\(total)): el conteo deja de ser a ciegas")
    }
}
