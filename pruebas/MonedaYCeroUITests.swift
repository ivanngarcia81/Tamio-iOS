import XCTest

/// Dos ataques al dinero que no necesitan servidor: cambiar la moneda de la
/// iglesia y guardar un movimiento de cero.
final class MonedaYCero: XCTestCase {

    var app: XCUIApplication!

    func arrancar(_ idioma: String = "ingles") {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", idioma,
                                "-AppleLanguages", idioma == "ingles" ? "(en)" : "(es)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func pestana(_ n: String) { app.tabBars.buttons[n].tap(); sleep(2) }

    @discardableResult
    func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 4 : 1) && e.isHittable { e.tap(); sleep(2); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return false
    }

    func volver() {
        let a = app.navigationBars.buttons.element(boundBy: 0)
        if a.exists && a.isHittable { a.tap(); sleep(2) }
    }

    /// **El "$" del campo de importe está escrito a mano** (`NuevoMovimientoView:385`),
    /// igual que el de `EditarAsuntoView:64`, el centro de la dona
    /// (`CategoryDonutChart:21`) y la fila de «Por revisar» (`RevisarView:298`).
    /// El resto de la app lee `Money.moneda`. Con la iglesia en euros, esos
    /// cuatro siguen diciendo dólares.
    func testCambiarLaMonedaAEuros() {
        arrancar()
        pestana("Settings")
        XCTAssertTrue(abrirFila("Church"), "no entré en Iglesia")
        for _ in 0..<3 { app.swipeUp(velocity: .slow); sleep(1) }
        print("IGLESIA-BOTONES:" + app.buttons.allElementsBoundByIndex
            .map { "\($0.label)\($0.isHittable ? "" : "·NOHIT")" }.joined(separator: "|"))
        parada("iglesia")

        // El selector de moneda: un Picker en un Form.
        let sel = app.buttons.matching(NSPredicate(format: "label CONTAINS 'USD'")).firstMatch
        if sel.exists {
            sel.tap(); sleep(2)
            print("MENU:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            parada("selector-moneda")
            let eur = app.buttons.matching(NSPredicate(format: "label CONTAINS 'EUR'")).firstMatch
            if eur.exists { eur.tap(); sleep(3) }
        } else {
            print("!! no encuentro el selector de moneda")
        }
        print("TRAS-EUR:" + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        parada("iglesia-eur")

        // Guardar y recorrer Tesorería buscando dólares.
        if app.buttons["Save"].exists { app.buttons["Save"].tap(); sleep(3) }
        volver()

        pestana("Treasury")
        abrirFila("Transactions")
        parada("tesoreria-eur-lista")
        let lista = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("LISTA-EUR:" + lista.prefix(20).joined(separator: "|"))

        app.buttons["New"].tap(); sleep(3)
        parada("alta-eur")
        let alta = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("ALTA-EUR:" + alta.prefix(15).joined(separator: "|"))
        XCTAssertFalse(alta.contains("$"),
                       "El campo de importe sigue diciendo «$» con la iglesia en euros")
        app.buttons["Cancel"].tap(); sleep(2)
        volver()

        // **Los otros cuatro sitios donde el "$" iba escrito a mano.** Se
        // recorren enteros porque el símbolo suelto no se ve en un volcado si
        // no se busca: aquí se busca cualquier rótulo que empiece por "$", por
        // "+$" o por "−$".
        func dolaresEn(_ pantalla: String) -> [String] {
            let sueltos = app.staticTexts.allElementsBoundByIndex.map(\.label).filter {
                $0 == "$" || $0.hasPrefix("$") || $0.hasPrefix("+$") || $0.hasPrefix("−$")
            }
            print("DOLARES-EN-\(pantalla):" + sueltos.joined(separator: "|"))
            return sueltos
        }

        // **Sin relanzar.** En modo revisión la moneda la sirve el repositorio
        // de maqueta y no sobrevive a un `terminate()`, así que relanzar aquí
        // mide una iglesia otra vez en dólares y no el arreglo. Las pantallas
        // que siguen se visitan por PRIMERA vez en esta corrida, así que su
        // cuerpo se construye después del cambio.
        pestana("Home")            // el monto compacto de Inicio y la dona
        parada("inicio-eur")
        XCTAssertTrue(dolaresEn("inicio").isEmpty, "Inicio sigue en dólares")
        for _ in 0..<4 { app.swipeUp(velocity: .slow); sleep(1) }
        parada("inicio-eur-abajo")
        XCTAssertTrue(dolaresEn("inicio-abajo").isEmpty, "la dona de Inicio sigue en dólares")

        pestana("To review")       // la fila de la bandeja
        parada("revisar-eur")
        XCTAssertTrue(dolaresEn("revisar").isEmpty, "Por revisar sigue en dólares")
    }

    /// **Un movimiento de $0.00 NO se puede guardar.** El botón miraba solo que
    /// el campo no estuviera vacío, y el parseador viejo devolvía 0 ante lo que
    /// no entendía: con ".." entraba una fila de $0.00 con su folio gastado.
    /// Ahora `guardadoHabilitado` exige un importe que se entienda y sea > 0.
    func testGuardarUnMovimientoDeCero() {
        arrancar()
        pestana("Treasury")
        abrirFila("Transactions")
        app.buttons["New"].tap(); sleep(3)
// No por el marcador: ahora lleva el separador del aparato, así
        // que en región española es "0,00".
        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 6))
        campo.tap(); campo.typeText(".."); sleep(1)
        let guardar = app.navigationBars.buttons["Save"]
        print("CERO · campo=\(campo.value as? String ?? "?") guardar=\(guardar.isEnabled)")
        parada("alta-cero")
        XCTAssertFalse(guardar.isEnabled, "Guardar está encendido con «..»: guardaría $0.00")
        if guardar.isEnabled {
            guardar.tap(); sleep(3)
            parada("lista-con-cero")
            print("LISTA-CERO:" + app.staticTexts.allElementsBoundByIndex.map(\.label)
                .prefix(20).joined(separator: "|"))
        }
    }
}
