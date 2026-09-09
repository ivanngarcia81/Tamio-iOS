import XCTest

/// **La pantalla de bloqueo, en iPad.** Es la otra pantalla que el modo
/// revisión no salta pero que no se ve nunca en un recorrido normal: el
/// candado se enciende en Ajustes · Cuenta y sale al volver del fondo.
///
/// Necesita Face ID inscrito en el simulador, que no se hace con `simctl` sino
/// con `notifyutil` (ver `CandadoUITests.swift`).
final class CandadoIPad: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(3)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    func volcado(_ n: String) {
        print(">>> \(n)")
        print("### TEXTOS: " + app.staticTexts.allElementsBoundByIndex.prefix(20)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        print("### BOTONES: " + app.buttons.allElementsBoundByIndex.prefix(15)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        fflush(stdout)
        parada(n)
    }

    /// **El candado se queda encendido entre corridas**, así que la prueba
    /// tiene que servir para las dos entradas: la primera vez hay que
    /// encenderlo en Ajustes, y a partir de ahí la app ya arranca bloqueada.
    func testElCandadoEnLasDosOrientaciones() {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func cancelarDialogo() {
            if sb.buttons["Cancel"].firstMatch.waitForExistence(timeout: 6) { sb.buttons["Cancel"].firstMatch.tap(); sleep(2) }
            else if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap(); sleep(2) }
        }
        var bloqueada = sb.buttons["Cancel"].firstMatch.waitForExistence(timeout: 6)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'locked'")).firstMatch.exists

        if !bloqueada {
            // Encenderlo en Ajustes · Cuenta.
            let ajustes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Settings'")).firstMatch
            if !(ajustes.exists && ajustes.isHittable) {
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
            }
            ajustes.tap(); sleep(2)
            app.buttons["Account"].firstMatch.tap(); sleep(2)
            let interruptor = app.switches.firstMatch
            print("### interruptor valor=\(interruptor.value ?? "-")")
            if interruptor.exists, (interruptor.value as? String) == "0" { interruptor.tap(); sleep(2) }
            XCUIDevice.shared.press(.home); sleep(3)
            app.activate(); sleep(4)
            bloqueada = true
        }
        cancelarDialogo()
        volcado("B-01-candado-apaisado")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'locked'")).firstMatch.exists,
                      "### no salió la pantalla de bloqueo")
        // Y no puede salir un NSError crudo (§4).
        let crudo = app.staticTexts.matching(NSPredicate(format:
            "label CONTAINS[c] 'LocalAuthentication' OR label CONTAINS[c] \"couldn't be completed\"")).firstMatch
        XCTAssertFalse(crudo.exists, "### salió un error crudo: \(crudo.label)")

        XCUIDevice.shared.orientation = .portrait; sleep(3)
        volcado("B-02-candado-vertical")

        // Y el botón de reintentar vuelve a pedir la huella o la cara.
        let reintentar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Unlock'")).firstMatch
        if reintentar.exists {
            reintentar.tap(); sleep(3)
            print("### tras reintentar: diálogo=\(sb.buttons["Cancel"].firstMatch.exists)")
            XCTAssertTrue(sb.buttons["Cancel"].firstMatch.exists, "### reintentar no volvió a pedir la biometría")
            parada("B-03-reintento")
            cancelarDialogo()
        }
    }
}
