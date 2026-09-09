import XCTest

/// La ficha del aportante: las cifras del historial, todas del mismo tamaño.
final class FichaAportante: XCTestCase {
    func testLasCifrasDelHistorialMidenLoMismo() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        let ap = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributors'")).firstMatch
        if !(ap.exists && ap.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        ap.tap(); sleep(2)
        app.staticTexts["Ana Lucía Torres Beltrán"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        print("MARCA:A-ficha"); fflush(stdout); Thread.sleep(forTimeInterval: 3)

        // Los tres aportes recientes de la tarjeta de la derecha.
        let cifras = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$2,800'"))
            .allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(cifras.count, 3, "### no encontré los aportes recientes")
        let altos = cifras.map { $0.frame.height }
        let anchos = cifras.map { $0.frame.width }
        print("### altos \(altos) anchos \(anchos)")
        XCTAssertEqual(altos.max()!, altos.min()!, accuracy: 1.0,
                       "### las cifras salen a tamaños distintos: \(altos)")
        XCTAssertEqual(anchos.max()!, anchos.min()!, accuracy: 1.0,
                       "### las cifras salen a tamaños distintos: \(anchos)")
        XCUIDevice.shared.orientation = .portrait
    }
}

/// La misma ficha en el teléfono: `AportanteDetalle` es una sola vista.
final class FichaAportanteIPhone: XCTestCase {
    func testLasCifrasDelHistorialMidenLoMismo() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(3)
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributors'")).firstMatch
        for _ in 0..<4 where !fila.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        fila.tap(); sleep(2)
        app.staticTexts["Ana Lucía Torres Beltrán"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        // En el teléfono la tarjeta de aportes queda bajo el pliegue.
        for _ in 0..<3 { app.swipeUp(velocity: .slow); sleep(1) }
        print("MARCA:AT-ficha"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        let cifras = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$2,800'"))
            .allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(cifras.count, 2, "### no encontré los aportes recientes")
        let altos = cifras.map { $0.frame.height }
        print("### teléfono altos \(altos)")
        XCTAssertEqual(altos.max()!, altos.min()!, accuracy: 1.0,
                       "### las cifras salen a tamaños distintos: \(altos)")
    }
}
