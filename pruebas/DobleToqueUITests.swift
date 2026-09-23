import XCTest

/// **Doble toque en Guardar.** `guardar()` y `guardarYAgregar()`
/// (`NuevoMovimientoView.swift:624` y `:629`) llaman a `onGuardar` sin ninguna
/// guarda de reentrada.
///
/// El folio ya NO es el riesgo: lo asigna el repositorio al guardar
/// (`OfflineMovimientosRepository.crear`), no la hoja. Lo que queda es que dos
/// llamadas a `onGuardar` son dos `crear` con dos UUID y dos folios distintos:
/// un movimiento duplicado que no se parece a un duplicado.
///
/// **Escribe en la iglesia sincronizada** (no lleva `-modoRevision YES`): cada
/// corrida deja un ingreso nuevo. Por eso cuenta DIFERENCIAS y no filas.
final class DobleToque: XCTestCase {

    var app: XCUIApplication!

    /// **Solo iPhone**: entra por la barra de pestañas, que el iPad no tiene.
    /// En el iPad físico (23-sep) daba roja con «No matches found for
    /// Descendants matching type TabBar».
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-bloqueo.biometrico", "NO"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func irALista() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Transactions'")
        app.buttons.matching(p).firstMatch.tap(); sleep(2)
    }

    func abrirAlta() {
        irALista()
        app.buttons["New"].tap(); sleep(3)
    }

    /// Las filas de la lista con ese importe entero, en cualquiera de los dos
    /// separadores decimales.
    func filas(conImporte n: Int) -> Int {
        app.staticTexts.allElementsBoundByIndex.map(\.label)
            .filter { $0.contains("$\(n).00") || $0.contains("$\(n),00") }.count
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
    ///
    /// **Dos cosas que la versión anterior hacía mal**, vistas en el iPhone
    /// físico el 23-sep, que dio «se guardó 2 veces»:
    /// 1. **Contaba filas con «88.00», no filas nuevas.** La lista traía dos:
    ///    Folio 1027 (de esa corrida, martes 22) y Folio 1023 (del lunes 21, de
    ///    una corrida anterior). La prueba escribe en la iglesia sincronizada,
    ///    así que cada corrida deja su fila y la siguiente la contaba como
    ///    duplicado. Ahora el importe es al azar y se cuenta antes y después.
    /// 2. **Nunca dio el segundo toque.** `guardar.exists && isHittable` hace
    ///    que XCUITest espere a que la app quede quieta, y para entonces la hoja
    ///    ya se ha cerrado: el registro dijo «SEGUNDO-TOQUE: el botón ya no
    ///    está». Un `doubleTap()` de coordenada manda los dos toques en un solo
    ///    evento, sin esperar entre ellos, que es lo que hace un pulgar.
    func testGuardarDosVeces() {
        irALista()
        // Entero y de tres cifras: el marcador del campo lleva el separador
        // del aparato ("0,00" en región española), así que no se teclea ninguno.
        let n = Int.random(in: 100...999)
        let antes = filas(conImporte: n)
        app.buttons["New"].tap(); sleep(3)
        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 6))
        campo.tap(); campo.typeText("\(n)"); sleep(1)
        let guardar = app.navigationBars.buttons["Save"]
        XCTAssertTrue(guardar.waitForExistence(timeout: 5), "no encuentro «Save»")
        guardar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
        sleep(4)
        let despues = filas(conImporte: n)
        print("FILAS-\(n): antes \(antes) · después \(despues)")
        parada("doble-guardar")
        // Control positivo: si no se guardó nada, la prueba no midió nada.
        XCTAssertGreaterThanOrEqual(despues - antes, 1,
                                    "no apareció ninguna fila de $\(n): el doble toque no guardó y la prueba no midió")
        XCTAssertLessThanOrEqual(despues - antes, 1,
                                 "El movimiento se guardó \(despues - antes) veces")
    }
}
