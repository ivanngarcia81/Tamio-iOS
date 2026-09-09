import XCTest

/// Recorrido de captura del iPad: navega por la sidebar, vuelca cada pantalla
/// y se para en cada `MARCA:` para que el shell fotografíe con `simctl`.
/// La orientación se fija con `XCUIDevice.shared.orientation` (§0.0).
final class RecorridoIPad: XCTestCase {

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
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func arrancar(_ o: UIDeviceOrientation) {
        app.launch()
        sleep(2)
        XCUIDevice.shared.orientation = o
        sleep(3)
        // **La ventana se queda como la dejó la última prueba, y sobrevive
        // incluso a reiniciar el simulador.** Si viene estrecha, el recorrido
        // fotografía la forma de teléfono dentro del iPad y el diff de píxeles
        // sale disparado sin que nada haya cambiado. Se devuelve con el botón
        // "Zoom" de los controles de ventana (ver `MultitareaIPadUITests`).
        if app.frame.width < 1000 {
            let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let ctrl = sb.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Window Controls'")).firstMatch
            if ctrl.waitForExistence(timeout: 5) {
                ctrl.tap(); sleep(2)
                if sb.buttons["Zoom"].exists { sb.buttons["Zoom"].tap(); sleep(3) }
            }
            print("### ventana devuelta a \(Int(app.frame.width)) pt")
        }
        print("### ventana: \(app.frame.width) x \(app.frame.height)")
    }

    // MARK: - Ayudantes

    func parada(_ nombre: String) {
        print("MARCA:\(nombre)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.0)
    }

    /// Un solo snapshot: `debugDescription` trae etiqueta, marco y estado de
    /// todo el árbol. Leer `label`/`frame`/`isHittable` elemento a elemento
    /// re-consulta el árbol cada vez y en iPad tarda minutos.
    func volcado(_ titulo: String) {
        print(">>> \(titulo)")
        let d = app.debugDescription
        for l in d.split(separator: "\n") where l.contains("Button,") || l.contains("StaticText,") || l.contains("TextField,") || l.contains("NavigationBar,") || l.contains("Sheet,") {
            print("  " + l.trimmingCharacters(in: .whitespaces))
        }
        fflush(stdout)
    }

    /// Fila de la sidebar por el principio de su etiqueta. En vertical la
    /// sidebar está colapsada: se abre con el botón de la barra y se vuelve a
    /// intentar.
    @discardableResult
    func seccion(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<4 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: 2) && e.isHittable {
                e.tap(); sleep(2); return true
            }
            abrirSidebar()
            // En el iPad mini la sidebar no cabe entera: bajar dentro de ella.
            if intento > 0 {
                let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.7))
                let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3))
                a.press(forDuration: 0.1, thenDragTo: b); sleep(1)
            }
        }
        print("  !! no encontré la sección \(prefijo)")
        return false
    }

    func abrirSidebar() {
        let t = app.navigationBars.buttons.matching(identifier: "ToggleSidebar").firstMatch
        if t.exists { t.tap(); sleep(1); return }
        let b = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch
        if b.exists { b.tap(); sleep(1); return }
        print("  !! no encontré el botón de la sidebar")
    }

    /// Cierra la sidebar superpuesta (vertical) tocando el detalle.
    func cerrarSidebar() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        sleep(1)
    }

    @discardableResult
    func tocarTexto(_ t: String) -> Bool {
        let e = app.staticTexts[t].firstMatch
        guard e.waitForExistence(timeout: 4) else { print("  !! no encontré el texto \(t)"); return false }
        e.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        sleep(2)
        return true
    }

    @discardableResult
    func tocarBoton(_ prefijo: String) -> Bool {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefijo)).firstMatch
        guard e.waitForExistence(timeout: 4), e.isHittable else { print("  !! no encontré el botón \(prefijo)"); return false }
        e.tap(); sleep(2)
        return true
    }

    func cerrarHoja() {
        for n in ["Cancel", "Close", "Done", "Cancelar", "Cerrar"] {
            let b = app.buttons[n].firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(1); return }
        }
        // Esc del teclado físico o toque fuera de la hoja
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        sleep(1)
    }

    // MARK: - Recorridos

    func recorrido(_ p: String) {
        // Inicio
        seccion("Home"); volcado("Inicio"); parada("\(p)-01-inicio")
        app.swipeUp(velocity: .slow); sleep(1); parada("\(p)-01-inicio-2")

        // Ingresos + detalle + filtros + nuevo
        seccion("Income"); volcado("Ingresos"); parada("\(p)-02-ingresos")
        if tocarTexto("Mission offering") { volcado("Ingresos · detalle"); parada("\(p)-02-ingresos-detalle") }
        if tocarBoton("Period and filters") || tocarBoton("Filters") { volcado("Ingresos · filtros"); parada("\(p)-02-ingresos-filtros"); cerrarHoja() }
        if tocarBoton("New") { volcado("Ingresos · nuevo"); parada("\(p)-02-ingresos-nuevo"); cerrarHoja() }

        seccion("Expenses"); volcado("Gastos"); parada("\(p)-03-gastos")

        // Aportantes
        seccion("Contributors"); volcado("Aportantes"); parada("\(p)-04-aportantes")
        if tocarTexto("María Hernández Ríos") { volcado("Aportantes · ficha"); parada("\(p)-04-aportantes-ficha") }

        // Reportes
        seccion("Reports"); volcado("Reportes"); parada("\(p)-05-reportes")
        if tocarTexto("Annual report") { volcado("Reportes · anual"); parada("\(p)-05-reportes-anual") }
        if tocarTexto("Financial statement") { app.swipeUp(velocity: .slow); sleep(1); parada("\(p)-05-reportes-estado-2") }

        // Depósitos
        seccion("Deposits"); volcado("Depósitos"); parada("\(p)-06-depositos")
        if tocarBoton("New") { volcado("Depósitos · nuevo corte"); parada("\(p)-06-depositos-nuevo"); cerrarHoja() }

        // Por revisar
        seccion("To review"); volcado("Revisar"); parada("\(p)-07-revisar")

        // Secretaría
        seccion("Membership"); volcado("Membresía"); parada("\(p)-08-membresia")
        if tocarTexto("María Hernández Ríos") { volcado("Membresía · ficha"); parada("\(p)-08-membresia-ficha") }
        for pest in ["Attendance", "Follow-up"] where app.buttons[pest].exists {
            app.buttons[pest].tap(); sleep(2); volcado("Membresía · \(pest)"); parada("\(p)-08-membresia-\(pest)")
        }

        seccion("Minutes"); volcado("Actas"); parada("\(p)-09-actas")
        seccion("Service log"); volcado("Servicios"); parada("\(p)-10-servicios")
        seccion("Letters"); sleep(3); volcado("Cartas"); parada("\(p)-11-cartas")
        seccion("Membership reports"); volcado("Informes"); parada("\(p)-12-informes")
        app.swipeUp(velocity: .slow); sleep(1); parada("\(p)-12-informes-2")
        seccion("Calendar"); volcado("Agenda"); parada("\(p)-13-agenda")
        for vista in ["Week", "List"] where app.buttons[vista].exists {
            app.buttons[vista].tap(); sleep(2); parada("\(p)-13-agenda-\(vista)")
        }
        seccion("Log"); volcado("Registro"); parada("\(p)-14-registro")
        seccion("Settings"); volcado("Ajustes"); parada("\(p)-15-ajustes")
        for fila in ["Institution", "Treasurer", "Access", "Categories", "Preferences", "Data"] {
            if tocarBoton(fila) || tocarTexto(fila) { volcado("Ajustes · \(fila)"); parada("\(p)-15-ajustes-\(fila)") }
        }
    }

    func testApaisado() { arrancar(.landscapeLeft); recorrido("L") }
    func testVertical() { arrancar(.portrait); recorrido("P") }

    /// Solo el inventario de arranque, para aprender etiquetas.
    func testInventario() {
        arrancar(.landscapeLeft)
        volcado("arranque apaisado")
        parada("inv-L")
        XCUIDevice.shared.orientation = .portrait; sleep(3)
        print("### ventana vertical: \(app.frame.width) x \(app.frame.height)")
        volcado("arranque vertical")
        parada("inv-P")
    }
}
