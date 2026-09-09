import XCTest

/// Paradas del teléfono para el diff de píxeles: Ingresos y Aportantes son las
/// dos listas cuyas filas comparten las dos plataformas.
final class TelefonoParadas: XCTestCase {
    func testIngresosYAportantes() {
        let app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
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
