import XCTest

/// **Los nueve botones de barra que quedaron sin decidir**, y que son otro caso
/// que los diecinueve con cristal sobre cristal.
///
/// - Los **«Listo» / «Guardar»** de las hojas llevan `.glassProminent`. Ahí el
///   relleno puede ser la enfatización legítima de una acción de confirmación
///   —lo que el sistema pone por omisión en `confirmationAction`— y no una
///   cápsula de más. No se toca sin verlo.
/// - Los **«Compartir»** de las previas de PDF llevan `.glass` puesto A
///   PROPÓSITO, para BAJAR del prominente. El motivo escrito era el contraste
///   —símbolo blanco sobre el verde de marca, ~2.4:1 en oscuro— y ese motivo se
///   resolvió el 16-sep con `Paleta.sobreMarca`, así que toca volver a mirarlos.
///
/// Esta prueba solo abre y se para: la decisión es de Iván.
final class BotonesDeHojaUITests: XCTestCase {
    /// **Solo iPhone**: llega a Movimientos por la pestaña Treasury. En el iPad
    /// físico (23-sep) daba roja con «No matches found for Descendants matching
    /// type TabBar» o su equivalente, que no dice nada de la app: es la omisión
    /// de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testHojaDeFiltros() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", ProcessInfo.processInfo.environment["TEMA"] ?? "claro"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Treasury"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Treasury"].tap(); sleep(2)

        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else { XCTFail("no está «Transactions»"); return }
        fila.tap(); sleep(3)

        // **«Period and filters: …», no «Filter».** El rótulo de accesibilidad
        // del botón de las tres rayas dice el periodo y los filtros puestos,
        // que es lo que hay que oír al tocarlo. Lo dijo el volcado.
        let filtros = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Period and filters' OR label BEGINSWITH 'Periodo y filtros'")).firstMatch
        guard filtros.waitForExistence(timeout: 8) else {
            print("BARRA:" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está el botón de filtros"); return
        }
        filtros.tap(); sleep(3)

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 8),
                      "la hoja de filtros no tiene «Done»")
        print("MARCA:hoja-filtros-\(ProcessInfo.processInfo.environment["TEMA"] ?? "claro")")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }
}
