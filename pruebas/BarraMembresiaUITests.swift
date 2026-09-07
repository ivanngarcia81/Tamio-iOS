import XCTest

/// Que la lupa esté donde Iván la pidió: escondida hasta tirar hacia abajo.
final class BarraMembresiaUITests: XCTestCase {

    func testElCajonDeLaLupa() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 20))
        app.buttons["Secretary"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership,'"))
            .firstMatch.tap()
        sleep(3)

        XCTAssertFalse(app.searchFields.firstMatch.exists,
                       "### el campo no puede estar puesto de entrada")
        // Tirar hacia abajo, DESPACIO y por coordenadas: un `swipeDown` sobre
        // una fila lo interpreta como toque y abre la ficha.
        let arriba = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
        let abajo  = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        arriba.press(forDuration: 0.2, thenDragTo: abajo)
        sleep(2)
        print("### campo tras tirar: \(app.searchFields.allElementsBoundByIndex.map { $0.placeholderValue ?? $0.label })")
        print("### BARRA: \(app.navigationBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label))")
        print("### MARCA-CAJON")
        sleep(5)
    }
}
