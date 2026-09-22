import XCTest

/// **La pasada de la pasada: lo que hay que MIRAR en el iPad.**
///
/// Recorre las pantallas que tocó la pasada de cristal del 16-sep y se para en
/// cada una con una `MARCA:` para que el shell capture. No afirma nada de
/// aspecto —el cristal no se juzga con `XCTAssert`— salvo que el control que se
/// va a mirar EXISTE, para que una captura vacía no pase por buena.
///
/// Va en apaisado, que es donde la columna se estrecha y donde vive casi todo
/// lo que se cambió.
final class PasadaCristalIPadUITests: XCTestCase {

    var app: XCUIApplication!
    /// **El tema llega con el prefijo `TEST_RUNNER_`.** `xcodebuild` NO reenvía
    /// las variables del shell al runner: `ProcessInfo.environment` dentro de
    /// una prueba es el del proceso que corre en el simulador. Solo pasan las
    /// que empiezan por `TEST_RUNNER_`, y llegan sin el prefijo — es lo que ya
    /// hace `postura.sh` con `TEST_RUNNER_POSTURA`, y lo que
    /// `CategoriasDeCristalUITests` dejó escrito el 6-sep. Aun así se repitió el
    /// 16-sep: una corrida de 99 s que se creía en claro y era en oscuro, y solo
    /// se notó porque las capturas salieron con el nombre equivocado.
    ///
    /// Por eso el tema va también en el NOMBRE de cada `MARCA:`: si la variable
    /// no llega, la captura lo delata en vez de mentir.
    var tema: String { ProcessInfo.processInfo.environment["TEMA"] ?? "oscuro" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1", "-bloqueo.biometrico", "NO",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", tema]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(3)
    }

    func parada(_ n: String) { print("MARCA:\(tema)-\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.5) }

    /// Abre una sección de la barra lateral. Vuelca lo que hay si no aparece:
    /// sin eso, un "no existe" manda a buscar el fallo donde no está.
    @discardableResult
    func abrir(_ seccion: String) -> Bool {
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", seccion)).firstMatch
        for _ in 0..<5 {
            if fila.exists && fila.isHittable { fila.tap(); sleep(3); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("NO-ESTA \(seccion) · hay:" + app.buttons.allElementsBoundByIndex.prefix(30)
                .map { String($0.label.prefix(24)) }.joined(separator: "|"))
        fflush(stdout)
        XCTFail("no está «\(seccion)» en la barra lateral")
        return false
    }

    /// Desplaza la COLUMNA, no la pantalla: el pie y las cabeceras solo se
    /// juzgan con filas pasando por detrás, y un `swipeUp` centrado en el iPad
    /// cae en el detalle.
    func desplazarColumna() {
        let arriba = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.72))
        let abajo  = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.32))
        for _ in 0..<2 { arriba.press(forDuration: 0.15, thenDragTo: abajo); sleep(1) }
    }

    func testPasada() {
        // H1 · los dos selectores que dejaron de ser Picker
        if abrir("Income") {
            XCTAssertTrue(app.buttons["capsulaTipoIngreso"].waitForExistence(timeout: 8),
                          "no está la cápsula de Ingresos")
            desplazarColumna()
            parada("H1-ingresos")
        }
        if abrir("Deposits") {
            XCTAssertTrue(app.buttons["Pending"].waitForExistence(timeout: 8),
                          "no está la cápsula «Pending»")
            parada("H1-depositos")
        }

        // H7 · el pie de columna, con la lista desplazada
        if abrir("Membership") { desplazarColumna(); parada("H7-membresia") }
        if abrir("Contributors") { desplazarColumna(); parada("H7-aportantes") }

        // H3 · las cápsulas de la fila del iPad
        if abrir("To review") { desplazarColumna(); parada("H3-revisar") }

        // B · el Registro con la barra devuelta y el borde duro
        if abrir("Log") { desplazarColumna(); parada("B-registro") }

        // Alineado · el selector de periodo en el cuerpo de Inicio
        if abrir("Home") { parada("AL-inicio") }
    }
}
