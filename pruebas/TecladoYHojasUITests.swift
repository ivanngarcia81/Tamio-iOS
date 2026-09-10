import XCTest

/// Dos cosas propias del teléfono: el teclado que tapa el campo enfocado, y las
/// cuatro `.sheet` que Membresía cuelga del mismo cuerpo (`MembresiaView:33-45`).
final class TecladoYHojas: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    /// **El importe se enfoca solo al presentar la hoja**, así que el teclado
    /// sube con ella. Lo que hay que medir es qué queda tapado debajo.
    func testElTecladoTapaElFormulario() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch.tap(); sleep(2)
        app.buttons["New"].tap(); sleep(3)
        parada("alta-con-teclado")

        let pantalla = app.frame
        let teclado = app.keyboards.firstMatch
        let alturaTeclado = teclado.exists ? teclado.frame.height : 0
        let libre = pantalla.height - alturaTeclado
        print("PANTALLA:\(Int(pantalla.height)) TECLADO:\(Int(alturaTeclado)) LIBRE:\(Int(libre))")

        var tapadas: [String] = []
        for t in app.staticTexts.allElementsBoundByIndex where t.frame.minY > libre && !t.label.isEmpty {
            tapadas.append("\(t.label)@\(Int(t.frame.minY))")
        }
        print("TAPADO:" + tapadas.joined(separator: " / "))
        // No por el marcador: lleva el separador del aparato, así que en
        // región española es "0,00".
        let campo = app.textFields.element(boundBy: 0)
        print("CAMPO-IMPORTE y=\(Int(campo.frame.minY)) visible=\(campo.frame.maxY < libre)")
        XCTAssertTrue(campo.frame.maxY < libre, "el campo enfocado queda bajo el teclado")
    }

    /// Membresía: filtros, alta, edición y seguimiento, una a una.
    func testLasCuatroHojasDeMembresia() {
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Membership,'")
        for _ in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.exists && e.isHittable { e.tap(); break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        sleep(3)

        func probar(_ nombre: String, _ toque: () -> Void) {
            let antes = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
            toque(); sleep(3)
            let despues = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
            let salio = despues != antes
            print("HOJA \(salio ? "OK " : "NO ") \(nombre): \(antes) -> \(despues)")
            fflush(stdout)
            if !salio { XCTFail("no salió: \(nombre)") }
            for etiqueta in ["Cancel", "Close", "Done"] {
                let b = app.buttons[etiqueta]
                if b.exists && b.isHittable { b.tap(); sleep(2); break }
            }
            if app.navigationBars.allElementsBoundByIndex.map(\.identifier) != antes {
                app.swipeDown(velocity: .fast); sleep(2)
            }
        }

        probar("filtros (More filters)") { self.app.buttons["More filters"].tap() }
        probar("alta (New)")             { self.app.buttons["New"].tap() }
        parada("membresia-tras-hojas")

        let fila = app.staticTexts.allElementsBoundByIndex.first { $0.frame.minY > 250 && !$0.label.isEmpty }
        if let fila {
            fila.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
            print("FICHA:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            parada("membresia-ficha")
        }
    }
}
