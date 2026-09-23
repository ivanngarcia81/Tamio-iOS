import XCTest

/// **iPad en regular con la columna de detalle estrecha.**
///
/// El iPad mini en vertical con la sidebar fijada deja 744 − 300 = 444 pt para
/// el detalle: por debajo de `Esp.anchoMaestroDetalle`, así que las pantallas
/// de maestro-detalle empujan la ficha en vez de dibujarla al lado. La app
/// sigue en clase de tamaño **regular**, que es lo que distingue esta postura
/// del teléfono — y es la misma que dan Split View a la mitad y Stage Manager.
///
/// Antes de `396b976` no se abría nada: la columna de detalle de un
/// `NavigationSplitView` no trae pila donde empujar, así que la fila se
/// pintaba de verde y ahí se quedaba.
final class EstrechoIPad: XCTestCase {
    var app: XCUIApplication!

    /// **Solo iPad.** El tamaño ya la omite en el iPad grande (abajo), pero en
    /// el teléfono la ventana también mide menos de 1024 y la dejaba pasar:
    /// en el iPhone físico (23-sep) daba roja pidiendo una sidebar fijada que
    /// el teléfono no tiene. Lo que distingue esta postura es la clase
    /// regular, y eso solo lo da el iPad.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-bloqueo.biometrico", "NO",
                                "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        // La sidebar fijada es lo que estrecha la columna: sin ella el detalle
        // mide 744 y la prueba no ejercita nada.
        let mostrar = app.buttons["Show Sidebar"].firstMatch
        if mostrar.exists { mostrar.tap(); sleep(1) }
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    func seccion(_ p: String) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 5), "### no encontré la sección \(p)")
        e.tap(); sleep(2)
    }

    func tocarTexto(_ t: String) {
        let e = app.staticTexts[t].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 5), "### no encontré \(t)")
        e.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2)
    }

    /// El botón de volver de la pila del detalle, que es la prueba de que se
    /// ha empujado algo. La otra barra es la de la sidebar.
    func hayBotonVolver(_ titulo: String) -> Bool {
        app.navigationBars.buttons[titulo].exists
    }

    /// **Se SALTA en un iPad grande, no falla.**
    ///
    /// Esta pasada es del iPad mini —es donde la columna del detalle baja de
    /// 640 pt con la barra lateral fijada, que es lo que dice `LEEME.md`—, y
    /// en esta casa no hay mini: el iPad Pro de 12,9" da 1192 pt. Con un
    /// `XCTAssertLessThan` eso es una roja que no se puede apagar con nada, y
    /// una roja permanente acaba enseñando a ignorar el color. Omitida dice lo
    /// que de verdad pasa: esta prueba no es para este aparato.
    func testLaFichaSeAbreYSeVuelve() throws {
        try XCTSkipUnless(app.frame.width < 1024,
                          "### esta prueba es del iPad pequeño; aquí la ventana mide \(app.frame.width)")
        XCTAssertTrue(app.buttons["Hide Sidebar"].exists, "### la sidebar tiene que estar fijada")

        seccion("Income")
        tocarTexto("Mission offering")
        XCTAssertTrue(app.staticTexts["AUDIT TRAIL"].waitForExistence(timeout: 5),
                      "### tocar la fila no abrió la ficha del movimiento")
        XCTAssertTrue(hayBotonVolver("Income"), "### la ficha se abrió sin botón de volver")
        parada("E-ingresos")

        // Cambiar de sección con una ficha abierta deja la pila en su raíz.
        seccion("Reports")
        XCTAssertTrue(app.staticTexts["Financial statement"].waitForExistence(timeout: 5),
                      "### al cambiar de sección se quedó la ficha anterior encima")
        parada("E-reportes-raiz")

        // Y el reporte también se abre: quien decide si la fila empuja es el
        // ancho, no la clase de tamaño.
        tocarTexto("Financial statement")
        XCTAssertTrue(app.staticTexts["ON-SCREEN SUMMARY"].waitForExistence(timeout: 5),
                      "### tocar el reporte no lo abrió")
        XCTAssertTrue(hayBotonVolver("Reports"), "### el reporte se abrió sin botón de volver")
        // Y sus controles salen UNA vez: la tira de filtros del contenido no se
        // dibuja cuando el reporte está empujado, que si no salen dos.
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Share'")).count, 1,
                       "### los controles del reporte salen dos veces")
        parada("E-reportes-abierto")

        seccion("Deposits")
        tocarTexto("Sunday, September 6 service")
        XCTAssertTrue(hayBotonVolver("Deposits"), "### el corte no se abrió")
        parada("E-depositos")
    }
}
