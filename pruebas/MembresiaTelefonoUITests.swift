import XCTest

/// La lista del padrón en el teléfono, para el diff de píxeles: `filaMiembro`
/// es la misma vista en las dos plataformas.
final class MembresiaTelefono: XCTestCase {
    func testParadaEnLaLista() {
        let app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(3)
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership,'")).firstMatch.tap(); sleep(3)
        let p = app.staticTexts["Transfer in progress"].firstMatch
        print("### pastilla en el teléfono \(p.frame)")
        print("MARCA:MT-lista"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
    }
}
