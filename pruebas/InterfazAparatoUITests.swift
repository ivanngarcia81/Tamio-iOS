import XCTest

/// **Lo que solo se puede medir en el iPad de verdad.**
///
/// Corre con el modo revisión ENCENDIDO a propósito: la prueba del repintado
/// tiene que CAMBIAR valores, y en el aparato los datos son los de la iglesia.
/// Con el modo encendido se toca la maqueta y no se siembra nada real.
///
/// Las capturas se escriben en `Documents/` y se sacan con
/// `devicectl device copy from`: el adjunto de XCUITest en apaisado sale
/// rotado y recortado (§0.0), y en un aparato no hay `simctl io`.
final class InterfazAparatoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1", "-AppleLanguages", "(es)"]
        app.launch(); sleep(3)
    }

    private func guarda(_ nombre: String) {
        let img = XCUIScreen.main.screenshot().pngRepresentation
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("qa-\(nombre).png")
        try? img.write(to: url)
        print("CAPTURA: qa-\(nombre).png (\(img.count) bytes)")
        fflush(stdout)
    }

    private func vaA(_ n: String) -> Bool {
        let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", n)).firstMatch
        guard b.waitForExistence(timeout: 15), b.isHittable else { return false }
        b.tap(); sleep(2); return true
    }

    // MARK: - 1 · El repintado, que en el simulador NO se reproduce

    /// §4: los controles de una vista empujada con `NavigationLink` dentro de un
    /// `Form` no se repintan cuando cambia el `@State` del padre. Iván lo
    /// encontró DOS veces en su iPhone —el estado civil y los chips— y no se
    /// reproduce en el Mac. Aquí se comprueba que los arreglos aguantan.
    ///
    /// **Con control positivo**: primero se lee el estado, se toca, y se
    /// compara SIN salir de la página. Si el valor solo cambia al salir y
    /// volver, el arreglo no sirve.
    func testLosControlesEmpujadosSeRepintan() throws {
        XCTAssertTrue(vaA("Membresía"), "no se llega a Membresía")
        // Abrir la primera ficha de la lista.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.30)).tap(); sleep(2)
        guarda("miembro-ficha")

        // Entrar en "Servicio y habilidades", que es donde viven los chips.
        guard vaA("Servicio y habilidades") else {
            print("NO SE LLEGÓ a Servicio y habilidades"); guarda("miembro-sin-pagina"); return
        }
        sleep(2)
        guarda("chips-antes")

        // Tocar un chip y mirar SI SE PINTA sin salir de la página.
        let chip = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Alabanza' OR label CONTAINS 'Ujier' OR label CONTAINS 'Música'")).firstMatch
        if chip.waitForExistence(timeout: 8) {
            let antes = chip.isSelected
            chip.tap(); sleep(2)
            let despues = app.buttons.matching(NSPredicate(format: "label == %@", chip.label)).firstMatch.isSelected
            print("CHIP «\(chip.label)» · isSelected antes=\(antes) después=\(despues)")
            guarda("chips-despues")
        } else {
            print("no se encontró un chip conocido; rótulos: \(app.buttons.allElementsBoundByIndex.prefix(25).map { $0.label })")
            guarda("chips-sin-encontrar")
        }

        // Y un interruptor de los que van por `vivo(_:)`.
        let sw = app.switches.firstMatch
        if sw.exists {
            let antes = sw.value as? String
            sw.tap(); sleep(2)
            let despues = app.switches.firstMatch.value as? String
            print("INTERRUPTOR · antes=\(antes ?? "?") después=\(despues ?? "?")")
            guarda("interruptor-despues")
        }
    }

    // MARK: - 2 · El texto que quedó sin ver

    func testElFiltroDelPadronDiceTitle() throws {
        XCTAssertTrue(vaA("Informes de membresía"), "no se llega a Informes")
        sleep(2)
        guarda("informes")
        for n in ["Filtros", "Filtrar"] { if vaA(n) { break } }
        sleep(2)
        guarda("informes-filtros")
        let t = app.staticTexts.allElementsBoundByIndex.compactMap { $0.exists ? $0.label : nil }
        print("¿Cargo? \(t.contains("Cargo"))  ¿Rol? \(t.contains("Rol"))")
        print("rótulos: \(t.prefix(45))")
    }

    // MARK: - 3 · Barrido visual en iOS 27

    func testBarridoVisualEniOS27() throws {
        let secciones = ["Inicio","Ingresos","Gastos","Aportantes","Reportes","Depósitos",
                         "Por revisar","Membresía","Actas","Registro de servicios",
                         "Cartas y traslados","Informes de membresía","Agenda","Registro","Configuración"]
        print("VENTANA: \(app.frame.size)")
        for s in secciones {
            guard vaA(s) else { print("SALTADA \(s)"); continue }
            sleep(2)
            let ancho = app.frame.width
            var fuera = 0
            for t in app.staticTexts.allElementsBoundByIndex.prefix(110) {
                guard t.exists else { continue }
                let f = t.frame
                guard f.width > 0 else { continue }
                if f.maxX > ancho + 0.5 || f.minX < -0.5 {
                    fuera += 1
                    print("  DESBORDA \(s) · \(t.label.prefix(44)) x=\(Int(f.minX))..\(Int(f.maxX)) (ancho \(Int(ancho)))")
                }
            }
            print("SECCIÓN \(s) · desbordes=\(fuera)")
            guarda("sec-\(s.replacingOccurrences(of: " ", with: "-"))")
        }
    }
}
