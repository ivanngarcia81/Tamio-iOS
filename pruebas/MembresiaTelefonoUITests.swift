import XCTest

/// La lista del padrón en el teléfono, para el diff de píxeles: `filaMiembro`
/// es la misma vista en las dos plataformas.
final class MembresiaTelefono: XCTestCase {
    /// **Solo iPhone**: es la parada del teléfono para el diff de píxeles. En el
    /// iPad físico (23-sep) daba roja con «No matches found for Descendants
    /// matching type TabBar» o su equivalente, que no dice nada de la app: es la
    /// omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testParadaEnLaLista() {
        let app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch(); sleep(3)
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership,'")).firstMatch.tap(); sleep(3)
        let p = app.staticTexts["Transfer in progress"].firstMatch
        print("### pastilla en el teléfono \(p.frame)")
        print("MARCA:MT-lista"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
    }
}
