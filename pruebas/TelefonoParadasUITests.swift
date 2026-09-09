import XCTest

/// Paradas del teléfono para el diff de píxeles: Ingresos y Aportantes son las
/// dos listas cuyas filas comparten las dos plataformas.
final class TelefonoParadas: XCTestCase {
    func testIngresosYAportantes() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
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
