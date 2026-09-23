import XCTest

/// Paradas del teléfono para el diff de píxeles: Ingresos y Aportantes son las
/// dos listas cuyas filas comparten las dos plataformas.
final class TelefonoParadas: XCTestCase {
    /// **Solo iPhone**: son las paradas del teléfono para el diff de píxeles. En
    /// el iPad físico (23-sep) daba roja con «No matches found for Descendants
    /// matching type TabBar» o su equivalente, que no dice nada de la app: es la
    /// omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testIngresosYAportantes() {
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
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch.tap(); sleep(3)
        print("MARCA:TP-ingresos"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let ap = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributors'")).firstMatch
        for _ in 0..<4 where !ap.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        ap.tap(); sleep(3)
        print("MARCA:TP-aportantes"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
    }
}
