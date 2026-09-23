import XCTest

/// **El chip del periodo del reporte, que se pintaba su propia cápsula.**
///
/// Lo vio Iván en "Annual report" y en "Financial statement": el "2026" salía
/// como una pastilla gris DENTRO de la cápsula de cristal del sistema, porque
/// `chipFiltro` llevaba `.background(Color(.tertiarySystemFill), in: Capsule())`
/// y estos menús viven en el `toolbar`.
///
/// No afirma aspecto —eso se mira en la captura— pero sí que el chip EXISTE y
/// se puede tocar: si alguien lo deja sin cápsula y sin contenido, esto cae.
final class ChipDePeriodoUITests: XCTestCase {
    /// **Solo iPad.** Pide barra lateral o apaisado, y el iPhone no tiene
    /// ninguna de las dos (`project.yml`: solo vertical; `RootView`: la barra
    /// lateral solo con `.regular`). Corrida en el teléfono daba rojas que no
    /// decían nada de la app: ver `docs/ROJAS-SEPTIEMBRE.md`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    func testReporteAnual() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", ProcessInfo.processInfo.environment["TEMA"] ?? "claro"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        // La maqueta: el chip del año solo sale si hay movimientos, y así
        // corre igual en un simulador sin sesión que en el aparato.
        app.launchArguments += ["-modoRevision", "YES"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(3)

        let reportes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reports'")).firstMatch
        for _ in 0..<5 {
            if reportes.exists && reportes.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard reportes.waitForExistence(timeout: 10) else {
            print("LATERAL:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Reports» en la barra lateral"); return
        }
        reportes.tap(); sleep(3)

        // **En el iPad no es un botón.** La lista de la columna es una fila
        // con `onTapGesture` (`ReportesView.listaColumna`), y lo que la
        // accesibilidad ve es el texto «Annual report». La tarjeta-botón es
        // solo del teléfono (`tarjetasReportes`). Buscando `buttons` la
        // prueba no la encontraba nunca en el iPad (roja en el físico, 23-sep).
        let anual = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Annual report'")).firstMatch
        guard anual.waitForExistence(timeout: 10) else {
            print("REPORTES:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(26)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está la tarjeta del reporte anual"); return
        }
        anual.tap(); sleep(4)

        // El chip del año, que es el que se pintaba su cápsula.
        let chip = app.buttons.matching(NSPredicate(format: "label CONTAINS '202'")).firstMatch
        if !chip.waitForExistence(timeout: 8) {
            print("BARRA-REPORTE:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
        }
        // Lo que la cabecera promete: que el chip EXISTE. Antes solo se imprimía.
        XCTAssertTrue(chip.exists, "### no está el chip del año en el reporte anual")
        print("MARCA:reporte-anual-\(ProcessInfo.processInfo.environment["TEMA"] ?? "claro")")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }
}
