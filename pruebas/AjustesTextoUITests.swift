import XCTest

/// **Ajustes con el texto del sistema en grande.**
///
/// Los setenta y ocho tamaños de esta pantalla estaban escritos con
/// `Font.system(size:)`, que no se mueve con Dynamic Type. Cada prueba se corre
/// con su tamaño puesto:
///
///     xcrun simctl ui <udid> content_size large                  → testEnFabrica
///     xcrun simctl ui <udid> content_size accessibility-medium   → testEnAX1
final class AjustesTexto: XCTestCase {
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
        let ajustes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Settings'")).firstMatch
        if !(ajustes.exists && ajustes.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        ajustes.tap(); sleep(3)
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    /// Los cinco rótulos que se miden, uno por familia de tamaño: el título de
    /// la columna (27), la tarjeta grande del detalle (26), una fila (16), un
    /// pie (12.5) y una sección de la sidebar (15.5).
    func alturas() -> [String: CGFloat] {
        var r: [String: CGFloat] = [:]
        for t in ["Settings", "Account", "Version", "Church"] {
            let e = app.staticTexts[t].firstMatch
            if e.exists { r[t] = e.frame.height }
        }
        // "Cerrar sesión" es la etiqueta de un botón, no un texto suelto.
        let salir = app.buttons["Sign out"].firstMatch
        if salir.exists { r["Sign out"] = salir.frame.height }
        print("### alturas \(r.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" })")
        return r
    }

    func testEnFabrica() {
        let a = alturas()
        print("MARCA:AJ-fabrica"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(a["Settings"] ?? 0, 32, accuracy: 3,
                       "### a tamaño de fábrica el título tiene que medir lo del diseño")
        XCTAssertEqual(a["Version"] ?? 0, 21, accuracy: 3)
    }

    func testEnAX1() {
        let a = alturas()
        print("MARCA:AJ-ax1"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        // AX1 es la primera categoría de accesibilidad: todo tiene que crecer.
        // A tamaño de fábrica miden 32.5, 31.5 y 18.5; en AX1, 44, 42 y 29.
        XCTAssertGreaterThan(a["Settings"] ?? 0, 40, "### el título no escaló")
        XCTAssertGreaterThan(a["Account"] ?? 0, 38, "### la tarjeta del detalle no escaló")
        XCTAssertGreaterThan(a["Version"] ?? 0, 25, "### la fila no escaló")
        XCTAssertGreaterThan(a["Church"] ?? 0, 25, "### la fila de la sidebar no escaló")
    }
}
