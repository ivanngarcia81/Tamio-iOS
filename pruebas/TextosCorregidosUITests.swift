import XCTest

/// **Ver en pantalla las correcciones de vocabulario.** Un diff de píxeles a
/// 0.000 % en una pantalla donde SÍ se cambió texto no prueba que el arreglo
/// falle: prueba que el texto cambiado no se ve ahí —un marcador con el campo
/// lleno, un `Picker` bajo el pliegue—. Esta prueba va a buscarlos.
final class TextosCorregidosUITests: XCTestCase {

    private func arranca(_ idioma: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-AppleLanguages", "(\(idioma))",
                               "-AppleLocale", idioma == "es" ? "es_MX" : "en_US"]
        app.launch(); sleep(3)
        return app
    }

    private func seccion(_ app: XCUIApplication, _ nombres: [String]) -> Bool {
        for n in nombres {
            let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", n)).firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(2); return true }
        }
        return false
    }

    private func dice(_ app: XCUIApplication, _ t: String) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", t)).firstMatch.exists
        || app.otherElements.matching(NSPredicate(format: "label CONTAINS %@", t)).firstMatch.exists
    }

    /// ESPAÑOL: «PADRÓN» donde antes se leía «ROSTER», e «Importe» donde antes «Monto».
    func testEnEspanol() throws {
        continueAfterFailure = true
        let app = arranca("es")

        XCTAssertTrue(seccion(app, ["Registro de servicios"]), "no se llega a Servicios")
        // Abrir el primer culto, que es donde vive el padrón.
        let fila = app.buttons.element(boundBy: 18)
        if fila.exists && fila.isHittable { fila.tap(); sleep(2) }
        print("MARCA: txt__es-servicios"); fflush(stdout); Thread.sleep(forTimeInterval: 4)
        print("¿dice PADRÓN? \(dice(app, "PADRÓN"))   ¿queda ROSTER? \(dice(app, "ROSTER"))")
        XCTAssertFalse(dice(app, "ROSTER"), "sigue saliendo ROSTER con la app en español")

        XCTAssertTrue(seccion(app, ["Depósitos"]), "no se llega a Depósitos")
        let corte = app.buttons.element(boundBy: 18)
        if corte.exists && corte.isHittable { corte.tap(); sleep(2) }
        print("MARCA: txt__es-corte"); fflush(stdout); Thread.sleep(forTimeInterval: 4)
        print("¿dice Importe? \(dice(app, "Importe"))   ¿queda Monto? \(dice(app, "Monto"))")
    }

    /// INGLÉS: "Description" en el alta, "Title" en el filtro del padrón,
    /// "Contributor" en el selector de la bandeja.
    func testEnIngles() throws {
        continueAfterFailure = true
        let app = arranca("en")

        XCTAssertTrue(seccion(app, ["Income"]), "no se llega a Ingresos")
        _ = seccion(app, ["New", "Add"])
        sleep(2)
        print("MARCA: txt__en-nuevo"); fflush(stdout); Thread.sleep(forTimeInterval: 4)
        // **«Concepto» CONTIENE «Concept»**, así que un `CONTAINS` da positivo
        // con la app en español y hace pasar por hallazgo lo que es el idioma.
        // Se listan los marcadores y se mira el que empieza por "Concept ·" o
        // es exactamente "Concept".
        let marcadores = app.textFields.allElementsBoundByIndex.compactMap { $0.placeholderValue }
        print("marcadores: \(marcadores)")
        let malo = marcadores.contains { $0 == "Concept" || $0.hasPrefix("Concept ·") }
        let bueno = marcadores.contains { $0.hasPrefix("Description") }
        print("marcador correcto=\(bueno)  sigue el malo=\(malo)")
        XCTAssertFalse(malo, "el marcador sigue diciendo Concept")
        let cancelar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Cancel'")).firstMatch
        if cancelar.exists { cancelar.tap(); sleep(1) }

        XCTAssertTrue(seccion(app, ["Membership reports"]), "no se llega a Informes")
        print("MARCA: txt__en-informes"); fflush(stdout); Thread.sleep(forTimeInterval: 4)
        print("¿dice Title? \(dice(app, "Title"))   ¿queda Role? \(dice(app, "Role"))")
    }
}
