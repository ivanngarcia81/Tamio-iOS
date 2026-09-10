import XCTest

/// El botón "Respaldar ahora" de Ajustes · Zona de riesgo, mirado despacio.
final class RespaldoEnPantalla: XCTestCase {

    func testRespaldarAhora() {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)

        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Danger zone'")
        for _ in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.exists && e.isHittable { e.tap(); break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        sleep(2)
        print("MARCA:respaldo-antes"); fflush(stdout); Thread.sleep(forTimeInterval: 3.5)

        app.buttons["Backup now"].tap()
        Thread.sleep(forTimeInterval: 12)
        print("MARCA:respaldo-despues"); fflush(stdout); Thread.sleep(forTimeInterval: 3.5)
        print("TEXTOS:" + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
    }
}
