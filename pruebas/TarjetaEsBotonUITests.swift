import XCTest

/// **La tarjeta de plantilla es un botón, no una forma con un gesto encima.**
///
/// Traía de fábrica un botón reconstruido a mano: el aspecto, el hundido
/// (`@State` + `onPressingChanged` + `scaleEffect`), el área tocable
/// (`contentShape` + `onTapGesture`) y la semántica para VoiceOver
/// (`accessibilityAddTraits(.isButton)` + `accessibilityAction`). Ahora es un
/// `Button` de verdad con `.buttonStyle(.tarjeta)`.
///
/// Esto **sí** se puede afirmar, al revés que el aspecto del cristal: o el
/// árbol de accesibilidad la da como botón y se puede activar, o no.
final class TarjetaEsBotonUITests: XCTestCase {

    func testLaTarjetaEsUnBotonYSeActiva() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", "oscuro"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Secretary"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Secretary"].tap(); sleep(2)

        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Letters'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else {
            print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(24)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Letters & transfers»"); return
        }
        fila.tap(); sleep(3)

        // **La tarjeta tiene que salir como BOTÓN**, con su contenido leído de
        // una pieza: nombre, descripción y pista en un solo rótulo. Si alguien
        // deshace el `Button` y vuelve al `onTapGesture`, esto deja de existir.
        let tarjeta = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Transfer' OR label CONTAINS 'Recommendation' OR label CONTAINS 'Baptism'"))
            .firstMatch
        guard tarjeta.waitForExistence(timeout: 10) else {
            print("CARTAS:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(30)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("la tarjeta no aparece como botón en el árbol de accesibilidad"); return
        }
        print("TARJETA:\(tarjeta.label)")
        fflush(stdout)
        // La pantalla tal cual, antes de tocar nada: es lo que se mira para
        // juzgar la tarjeta.
        print("MARCA:cartas-tarjetas"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(tarjeta.isHittable, "la tarjeta existe pero no se puede tocar")

        // Y que al activarla se abra algo: sin esto, un botón que no hace nada
        // pasaría la prueba.
        let antes = app.navigationBars.firstMatch.identifier
        tarjeta.tap(); sleep(3)
        print("MARCA:cartas-tras-tocar"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
        let despues = app.navigationBars.firstMatch.identifier
        XCTAssertNotEqual(antes, despues,
                          "tocar la tarjeta no llevó a ninguna parte (barra: «\(despues)»)")
    }

    /// **La tarjeta de Reportes, que comparte la mitad del patrón.** El toque y
    /// la semántica se arreglan igual; el hundido NO, porque aquí la pulsación
    /// larga la tiene el `contextMenu` y el sistema ya levanta la tarjeta.
    ///
    /// Lo que hay que vigilar, y que compilar no dice: que el menú contextual
    /// siga saliendo ahora que cuelga de un `Button` y no de una forma.
    func testLaTarjetaDeReportesEsUnBoton() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", "oscuro"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Treasury"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Treasury"].tap(); sleep(2)

        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reports'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else {
            print("HUB-TESORERIA:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(24)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Reports»"); return
        }
        fila.tap(); sleep(3)

        let tarjeta = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'report' OR label CONTAINS 'Monthly' OR label CONTAINS 'Annual'"))
            .firstMatch
        guard tarjeta.waitForExistence(timeout: 10) else {
            print("REPORTES:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(30)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("la tarjeta de reporte no aparece como botón"); return
        }
        print("TARJETA-REPORTE:\(tarjeta.label)"); fflush(stdout)
        print("MARCA:reportes-tarjetas"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(tarjeta.isHittable, "la tarjeta existe pero no se puede tocar")

        // **El menú contextual sigue vivo.** Es lo que podía romperse al meter
        // la tarjeta dentro de un `Button`, y no lo dice compilar.
        tarjeta.press(forDuration: 1.2)
        sleep(2)
        print("MARCA:reportes-menu-contextual"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
        let verReporte = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'View report' OR label CONTAINS 'PDF preview'")).firstMatch
        XCTAssertTrue(verReporte.waitForExistence(timeout: 6),
                      "mantener pulsado ya no abre el menú contextual de la tarjeta")
    }
}
