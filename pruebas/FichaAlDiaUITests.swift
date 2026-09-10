import XCTest

/// **Que la ficha abierta enseñe el dato de ahora, no el de cuando se abrió.**
///
/// `navigationDestination(item:)` empuja un VALOR, y un valor no cambia: lo que
/// se edite después —o lo que llegue al sincronizar— se veía en la lista y no en
/// la ficha que estaba encima. Y `==` por id lo remataba: SwiftUI daba por buena
/// la vista que ya tenía, así que dos fichas con el mismo id y distinto
/// contenido eran "iguales".
///
/// Lo vio Iván en su iPhone el 10-sep con un donativo: la ficha decía
/// "Folio P-9" —o sea, sin subir— mientras la lista y el servidor ya decían
/// "Folio 9".
///
/// Se corre con el modo revisión ENCENDIDO.
final class FichaAlDia: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    /// El importe grande de la ficha.
    func importeEnFicha() -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label)
            .first { $0.hasPrefix("+") || $0.hasPrefix("−") } ?? "?"
    }

    func testElImporteEditadoSeVeEnLaFichaSinSalirDeElla() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch.tap()
        sleep(3)

        // Abrir la primera fila por su texto: las filas de una `List` no son
        // botones y no se localizan por título.
        let fila = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.hasPrefix("Folio ")
        }
        guard let fila else { return XCTFail("no encuentro ninguna fila") }
        fila.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)

        let antes = importeEnFicha()
        print("FICHA-ANTES:\(antes)")
        parada("ficha-antes")

        guard app.buttons["Edit"].waitForExistence(timeout: 5) else {
            print("BOTONES:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            return XCTFail("no hay botón Edit en la ficha")
        }
        app.buttons["Edit"].tap(); sleep(3)

        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "no encuentro el campo de importe")
        campo.tap()
        for _ in 0..<14 { app.keys["Delete"].tap() }
        campo.typeText("7.77"); sleep(1)
        print("ESCRITO:[\(campo.value as? String ?? "?")]")

        app.navigationBars.buttons["Save"].tap(); sleep(3)

        let despues = importeEnFicha()
        print("FICHA-DESPUES:\(despues)")
        parada("ficha-despues")

        XCTAssertTrue(despues.contains("7.77"),
                      "la ficha sigue enseñando \(despues) tras guardar 7.77")
    }
}
