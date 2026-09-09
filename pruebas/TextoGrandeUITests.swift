import XCTest

/// Con el texto del sistema en AX1: ni las cifras ni las pastillas de estado
/// pueden salir en dos renglones. Se corre con
/// `xcrun simctl ui <udid> content_size accessibility-medium`.
final class TextoGrande: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    func seccion(_ p: String) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
        if !(e.exists && e.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        XCTAssertTrue(e.waitForExistence(timeout: 5), "### no encontré \(p)")
        e.tap(); sleep(3)
    }

    func testLosImportesDeAportantesNoSeParten() {
        seccion("Contributors")
        parada("X-aportantes")
        let cifras = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$'"))
            .allElementsBoundByIndex.filter { $0.frame.width > 40 && $0.frame.minX > 300 }
        XCTAssertGreaterThan(cifras.count, 5, "### no encontré los totales de la lista")
        for c in cifras {
            XCTAssertLessThan(c.frame.height, 45,
                              "### '\(c.label)' salió en dos renglones: \(c.frame)")
        }
        print("### cifras \(cifras.map { "\($0.label)=\(Int($0.frame.height))" })")
    }

    func testLaPastillaDeIngresosNoSeParte() {
        seccion("Income")
        parada("X-ingresos")
        let pastillas = app.staticTexts.matching(NSPredicate(format: "label == 'Not deposited'"))
            .allElementsBoundByIndex
        XCTAssertGreaterThan(pastillas.count, 3, "### no encontré las pastillas")
        for p in pastillas {
            XCTAssertLessThan(p.frame.height, 40,
                              "### la pastilla salió en dos renglones: \(p.frame)")
        }
        print("### pastillas \(pastillas.map { Int($0.frame.height) })")
    }
}
