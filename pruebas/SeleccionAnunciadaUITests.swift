import XCTest

/// La fila abierta se anuncia, no solo se pinta: `isSelected` en la sidebar,
/// en la sidebar de Ajustes y en las listas de maestro-detalle.
final class SeleccionAnunciada: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    /// La fila de la sidebar, abriéndola si hiciera falta.
    func seccion(_ p: String) -> XCUIElement {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
        if !e.waitForExistence(timeout: 2) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap()
            sleep(2)
        }
        return e
    }

    func testLaSidebarDiceEnQueSeccionEstas() {
        let ingresos = seccion("Income")
        XCTAssertTrue(ingresos.waitForExistence(timeout: 5))
        ingresos.tap(); sleep(2)
        print("### botones: " + app.buttons.allElementsBoundByIndex.prefix(20)
              .map { "\($0.label)[sel=\($0.isSelected)]" }.joined(separator: " "))
        print("### otros: " + app.otherElements.allElementsBoundByIndex.prefix(30)
              .filter { !$0.label.isEmpty }.map { "\($0.label)[sel=\($0.isSelected)]" }.joined(separator: " "))
        XCTAssertTrue(ingresos.isSelected, "### la sección abierta no se anuncia")
        XCTAssertFalse(seccion("Expenses").isSelected, "### otra sección aparece como abierta")

        seccion("Deposits").tap(); sleep(2)
        XCTAssertTrue(seccion("Deposits").isSelected)
        XCTAssertFalse(seccion("Income").isSelected, "### la sección anterior sigue anunciándose")
    }

    /// **En una `List` el rasgo se queda en los elementos de la fila, no en la
    /// celda.** Medido: la celda sigue diciendo `isSelected=false` y son sus
    /// cinco elementos —el icono, el titular, el folio, el importe y la
    /// pastilla— los que lo llevan. Da igual para lo que importa: VoiceOver
    /// anuncia el estado al leer la fila abierta, que es lo que antes no
    /// pasaba en ninguna parte.
    func testLaListaDiceQueFilaEstaAbierta() {
        seccion("Income").tap(); sleep(2)
        app.staticTexts["Mission offering"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2)

        // **El titular está dos veces**: en la fila y en el H1 del detalle.
        // El de la lista es el de la izquierda.
        let enLaLista = app.staticTexts.matching(identifier: "Mission offering")
            .allElementsBoundByIndex.filter { $0.frame.minX < 600 }
        XCTAssertFalse(enLaLista.isEmpty, "### no encontré la fila en la columna")
        let abierto = enLaLista[0]
        XCTAssertTrue(abierto.isSelected, "### la fila abierta no se anuncia como seleccionada")
        // Y solo esa: los titulares de las demás filas no pueden llevarlo.
        let otros = ["Tithe · Ana Lucía Torres", "Wednesday offering", "Building fund"]
        for o in otros {
            for e in app.staticTexts.matching(identifier: o).allElementsBoundByIndex
                        where e.frame.minX < 600 {
                XCTAssertFalse(e.isSelected, "### '\(o)' se anuncia como abierta sin estarlo")
            }
        }
        print("### abierta=\(abierto.isSelected)")
    }

    func testLaSidebarDeAjustesTambien() {
        seccion("Settings").tap(); sleep(2)
        let tesorero = app.buttons["Treasurer & pastor"].firstMatch
        XCTAssertTrue(tesorero.waitForExistence(timeout: 5))
        tesorero.tap(); sleep(2)
        XCTAssertTrue(tesorero.isSelected, "### la sección de ajustes abierta no se anuncia")
        XCTAssertFalse(app.buttons["Categories"].firstMatch.isSelected)
    }
}
