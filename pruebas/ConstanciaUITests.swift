import XCTest

/// **La constancia anual, entera.** `HojaCartaEscalada` mide la hoja para
/// escalarla, y en la primera pasada la mide dentro de una caja de alto cero:
/// un párrafo que necesita dos renglones se conformaba con uno y se recortaba
/// con puntos suspensivos, en el documento que se le entrega a quien aporta.
class Constancia: XCTestCase {
    var app: XCUIApplication!

    func arrancar() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(3)
    }

    /// La frase que certifica, sin recortar.
    /// - Parameter minimo: la hoja se dibuja ESCALADA para caber en el ancho,
    ///   así que el alto de dos renglones no es el mismo en iPad (escala 1,
    ///   38 pt) que en el teléfono (escala ~0.55, 20 pt). Un solo renglón mide
    ///   la mitad en cada caso.
    func comprobarFrase(_ marca: String, minimo: CGFloat) {
        let frase = "This certifies that the person named above made the following voluntary contributions during 2026."
        let e = app.staticTexts[frase].firstMatch
        print("MARCA:\(marca)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
        XCTAssertTrue(e.exists, "### la frase de la constancia sale recortada")
        // Recortada mide un renglón; entera, dos o más.
        XCTAssertGreaterThan(e.frame.height, minimo,
                             "### la frase cabe en un renglón: está recortada")
        print("### frase \(e.frame)")
    }
}

final class ConstanciaIPad: Constancia {
    func testLaFraseSaleEntera() {
        arrancar()
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        let ap = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributors'")).firstMatch
        if !(ap.exists && ap.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        ap.tap(); sleep(2)
        app.staticTexts["Ana Lucía Torres Beltrán"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Documents'")).firstMatch.tap(); sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Annual'")).firstMatch.tap(); sleep(3)
        comprobarFrase("C-ipad", minimo: 25)
        XCUIDevice.shared.orientation = .portrait
    }
}

final class ConstanciaIPhone: Constancia {
    func testLaFraseSaleEntera() {
        arrancar()
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributors'")).firstMatch
        for _ in 0..<4 where !fila.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        fila.tap(); sleep(2)
        app.staticTexts["Ana Lucía Torres Beltrán"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Documents'")).firstMatch.tap(); sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Annual'")).firstMatch.tap(); sleep(3)
        comprobarFrase("C-telefono", minimo: 15)
    }
}
