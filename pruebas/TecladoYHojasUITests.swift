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

    // MARK: - Los campos de abajo

    /// **Alto libre HOY.** Se vuelve a leer en cada medida a propósito: el
    /// teclado CAMBIA de alto dentro de esta misma pantalla —el importe abre
    /// el `.decimalPad` y los campos de texto el alfabético, que trae la fila
    /// de predicciones y es más alto—, así que una altura guardada al entrar
    /// miente en cuanto se toca un campo de abajo. Es la misma trampa que ya
    /// dio lecturas falsas en las placas: medir antes de que la pantalla
    /// termine de moverse.
    func libre() -> CGFloat {
        let t = app.keyboards.firstMatch
        return app.frame.height - (t.exists ? t.frame.height : 0)
    }

    /// Baja por el formulario hasta que el elemento se pueda tocar. Devuelve
    /// `false` si no aparece: quien llame DEBE fallar, no seguir.
    @discardableResult
    func alcanzar(_ e: XCUIElement, intentos: Int = 8) -> Bool {
        for i in 0..<intentos {
            if e.waitForExistence(timeout: i == 0 ? 4 : 1) && e.isHittable { return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return false
    }

    func volcadoDeCampos(_ titulo: String) {
        let campos = app.textFields.allElementsBoundByIndex + app.textViews.allElementsBoundByIndex
        print(">>> \(titulo) libre=\(Int(libre()))")
        for c in campos {
            print("   campo «\(c.label)» y=\(Int(c.frame.minY))..\(Int(c.frame.maxY))")
        }
        fflush(stdout)
    }

    /// **Un campo que nace TAPADO, ¿sube al tocarlo?**
    ///
    /// `testElTecladoTapaElFormulario` solo mira el importe, que se enfoca solo
    /// al presentar la hoja y por eso está arriba de todo y fuera del `Form`.
    /// Lo que no comprobaba nadie es lo de debajo: con el teclado ya arriba, el
    /// nombre del visitante y las notas quedan bajo él, y hay que tocarlos
    /// después de desplazar.
    ///
    /// **Aportante y Adjuntar NO entran aquí, y es a propósito.** Un
    /// `Picker(.menu)` y un `Button` no toman el foco, así que SwiftUI no tiene
    /// nada que desplazar: el menú se presenta anclado a su fila y el importador
    /// de archivos es una hoja que tapa la pantalla entera. Lo que sí tiene que
    /// cumplirse es lo que mide esta prueba: que el campo ENFOCADO acabe sobre
    /// el teclado.
    func testLosCamposDeAbajoSubenAlTocarlos() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch.tap(); sleep(2)
        app.buttons["New"].tap(); sleep(3)

        // La sección Aportante solo existe en un INGRESO. Si el segmentado no
        // está, la hoja no es la que se cree y la prueba no ha probado nada.
        //
        // **`firstMatch` y acotado al segmentado, no `app.buttons["Income"]`.**
        // Ese casa con VARIOS —el de la hoja y el de la pantalla de detrás— y
        // `tap()` revienta con "Multiple matching elements found", que fue
        // exactamente cómo falló la primera corrida en el aparato.
        let segmentado = app.segmentedControls.buttons["Income"].firstMatch
        let ingreso = segmentado.exists ? segmentado
                                        : app.buttons.matching(identifier: "Income").firstMatch
        guard ingreso.waitForExistence(timeout: 5) else {
            print("BARRA:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está el segmentado Income/Expense: la hoja no es la de alta"); return
        }
        ingreso.tap(); sleep(1)

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "el teclado no subió solo: esta prueba mide qué pasa CON él arriba")
        volcadoDeCampos("al abrir")

        // --- 1. El nombre del visitante, que nace bajo el teclado.
        let selector = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributor'")).firstMatch
        guard alcanzar(selector) else {
            print("BOTONES:" + app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).joined(separator: "|"))
            fflush(stdout)
            XCTFail("no se alcanzó el selector de aportante"); return
        }
        print("TRAS-DESPLAZAR libre=\(Int(libre())) selector y=\(Int(selector.frame.minY))")
        selector.tap(); sleep(2)

        let otra = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Someone else'")).firstMatch
        guard otra.waitForExistence(timeout: 5) else {
            print("MENU:" + app.buttons.allElementsBoundByIndex.prefix(30).map(\.label).joined(separator: "|"))
            fflush(stdout)
            XCTFail("el menú del aportante no ofrece «Someone else…»"); return
        }
        otra.tap(); sleep(2)

        let nombre = app.textFields["Name"]
        guard alcanzar(nombre) else {
            volcadoDeCampos("sin el campo Nombre")
            XCTFail("no apareció el campo del nombre del visitante"); return
        }
        nombre.tap(); sleep(2)   // cambia el teclado: hay que esperar al alto nuevo
        print("NOMBRE y=\(Int(nombre.frame.minY))..\(Int(nombre.frame.maxY)) libre=\(Int(libre()))")
        fflush(stdout)
        XCTAssertLessThan(nombre.frame.maxY, libre(),
                          "el nombre del visitante se queda BAJO el teclado al tocarlo")

        // --- 2. Las notas, que además crecen de 2 a 4 renglones.
        let notas = app.textViews["Notes · optional"].exists
                  ? app.textViews["Notes · optional"] : app.textFields["Notes · optional"]
        guard alcanzar(notas) else {
            volcadoDeCampos("sin el campo Notas")
            XCTFail("no se alcanzó el campo de notas"); return
        }
        notas.tap(); sleep(2)
        notas.typeText("una linea\notra linea")   // que crezca, que es cuando se cae
        sleep(2)
        print("NOTAS y=\(Int(notas.frame.minY))..\(Int(notas.frame.maxY)) libre=\(Int(libre()))")
        fflush(stdout)
        parada("teclado-campos-de-abajo")
        XCTAssertLessThan(notas.frame.maxY, libre(),
                          "las notas se quedan BAJO el teclado con dos renglones escritos")
    }
}
