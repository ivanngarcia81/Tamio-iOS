import XCTest

/// **Doble toque en Guardar.** `guardar()` y `guardarYAgregar()`
/// (`NuevoMovimientoView.swift`) llaman a `onGuardar` sin ninguna guarda de
/// reentrada, y el folio siguiente se pide en un `Task` que tarda: un segundo
/// toque antes de que llegue usa el MISMO folio.
final class DobleToque: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func abrirAlta() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Transactions'")
        app.buttons.matching(p).firstMatch.tap(); sleep(2)
        app.buttons["New"].tap(); sleep(3)
    }

    /// «Guardar y agregar otro», dos veces seguidas y rápido.
    func testGuardarYAgregarDosVeces() {
        abrirAlta()
        // No por el marcador: lleva el separador del aparato, así que en
        // región española es "0,00".
        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 6))
        campo.tap(); campo.typeText("77"); sleep(1)

        // El botón vive al final del formulario.
        for _ in 0..<5 { app.swipeUp(velocity: .slow) }
        sleep(1)
        let boton = app.buttons["Save and add another"]
        guard boton.waitForExistence(timeout: 5) else {
            print("BOTONES:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            return XCTFail("no encuentro «Save and add another»")
        }
        boton.tap()
        boton.tap()          // sin esperar: es el doble toque de un pulgar nervioso
        sleep(3)
        parada("doble-guardar-y-agregar")

        app.buttons["Cancel"].tap(); sleep(3)
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("LISTA:" + textos.prefix(30).joined(separator: "|"))
        let folios = textos.filter { $0.hasPrefix("Folio ") }
        let repetidos = Dictionary(grouping: folios, by: { $0 }).filter { $0.value.count > 1 }
        print("FOLIOS:" + folios.joined(separator: "|"))
        print("REPETIDOS:\(repetidos.keys.sorted())")
        XCTAssertTrue(repetidos.isEmpty, "Dos movimientos con el mismo folio: \(repetidos.keys.sorted())")
        let setentaYSiete = textos.filter { $0.contains("77.00") }
        print("FILAS-77:\(setentaYSiete.count)")
    }

    /// Doble toque en el «Guardar» de la barra.
    func testGuardarDosVeces() {
        abrirAlta()
        // No por el marcador: lleva el separador del aparato, así que en
        // región española es "0,00".
        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 6))
        campo.tap(); campo.typeText("88"); sleep(1)
        let guardar = app.navigationBars.buttons["Save"]
        guardar.tap()
        // El segundo toque puede no encontrar el botón: la hoja ya se cerró, y
        // eso ES la protección. Se anota en vez de fallar.
        if guardar.exists && guardar.isHittable { guardar.tap() } else { print("SEGUNDO-TOQUE: el botón ya no está") }
        sleep(3)
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        let filas = textos.filter { $0.contains("88.00") }
        print("FILAS-88:\(filas.count)")
        parada("doble-guardar")
        XCTAssertLessThanOrEqual(filas.count, 1, "El movimiento se guardó \(filas.count) veces")
    }
}
