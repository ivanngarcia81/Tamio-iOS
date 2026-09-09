import XCTest

/// Con el texto del sistema en AX1: ni las cifras ni las pastillas de estado
/// pueden salir en dos renglones. Se corre con
/// `xcrun simctl ui <udid> content_size accessibility-medium`.
final class TextoGrande: XCTestCase {
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

    /// El bloque de fecha de "Esta semana" iba en 36 pt fijos: en AX1 el día
    /// salía "SU / N" y el número "2 / 1". Ahora el ancho escala con la letra.
    func testLaFechaDeLaAgendaDeInicioNoSeParte() {
        seccion("Home")
        parada("X-inicio-agenda")
        // Los días de la semana en tres letras y los números del mes: los dos
        // rótulos que viven dentro del bloque estrecho.
        let dias = app.staticTexts.matching(NSPredicate(
            format: "label IN {'MON','TUE','WED','THU','FRI','SAT','SUN'}")).allElementsBoundByIndex
        XCTAssertGreaterThan(dias.count, 1, "### no encontré la agenda de Inicio")
        for d in dias {
            XCTAssertLessThan(d.frame.height, 40,
                              "### '\(d.label)' salió en dos renglones: \(d.frame)")
        }
        print("### días \(dias.map { "\($0.label)=\(Int($0.frame.height))" })")
    }

    /// El selector de vista y la cabecera de días de la Agenda, en la columna
    /// estrecha: "Month" salía "Mont / h" y "MON" salía "MO / N".
    func testElSelectorDeLaAgendaNoSeParte() {
        XCUIDevice.shared.orientation = .portrait; sleep(3)
        seccion("Calendar")
        parada("X-agenda")
        for nombre in ["Month", "Week", "List"] {
            let e = app.buttons.matching(NSPredicate(format: "label == %@", nombre)).firstMatch
            guard e.exists else { continue }
            XCTAssertLessThan(e.frame.height, 60,
                              "### '\(nombre)' salió en dos renglones: \(e.frame)")
            print("### \(nombre)=\(Int(e.frame.height))")
        }
        let dias = app.staticTexts.matching(NSPredicate(
            format: "label IN {'MON','TUE','WED','THU','FRI','SAT','SUN'}")).allElementsBoundByIndex
        for d in dias {
            XCTAssertLessThan(d.frame.height, 40,
                              "### la cabecera '\(d.label)' salió en dos renglones: \(d.frame)")
        }
        print("### cabecera \(dias.map { "\($0.label)=\(Int($0.frame.height))" })")
    }
}
