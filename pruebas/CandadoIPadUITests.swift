import XCTest

/// **La pantalla de bloqueo, en iPad.** Es la otra pantalla que el modo
/// revisión no salta pero que no se ve nunca en un recorrido normal: el
/// candado se enciende en Ajustes · Cuenta y sale al volver del fondo.
///
/// Necesita Face ID inscrito en el simulador, que no se hace con `simctl` sino
/// con `notifyutil` (ver `CandadoUITests.swift`).
final class CandadoIPad: XCTestCase {
    var app: XCUIApplication!

    /// **Solo iPad.** Gira a apaisado, y el iPhone solo admite vertical
    /// (`project.yml`). En el teléfono ya la cubre `CandadoUITests`; esta,
    /// corrida en el iPhone físico (23-sep), daba roja sin decir nada de la app.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // **El candado se enciende POR ARGUMENTO, no tocando Ajustes.**
        //
        // `BloqueoBiometrico` lee `activo` una sola vez en su `init`, con
        // `UserDefaults.standard.bool(forKey:)`, y el dominio de argumentos
        // pisa al persistido — es el mismo mecanismo con el que estas pruebas
        // llevan desde siempre poniendo `-prefs.idioma` y
        // `-prefs.bienvenidaVista`. Y no escribe de vuelta: el `didSet` que
        // persiste no dispara en una asignación dentro del `init`.
        //
        // Antes se encendía tocando el interruptor de Ajustes · Cuenta, y eso
        // **dejaba el aparato encendido para siempre**: el 22-sep costó tres
        // corridas del iPad seguidas —todas rojas, con mensajes convincentes
        // sobre barras laterales que no faltaban— hasta descubrir que la app
        // estaba bloqueada desde la corrida anterior. Una prueba que cambia el
        // estado del aparato y no lo deshace envenena a las que vienen detrás.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES",
                                "-bloqueo.biometrico", "YES"]
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

    /// **La app arranca ya bloqueada**, porque el `setUp` lo pide por
    /// argumento. No hace falta encenderlo en Ajustes ni deshacerlo después:
    /// el ajuste guardado del aparato se queda como estaba.
    func testElCandadoEnLasDosOrientaciones() {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func cancelarDialogo() {
            if sb.buttons["Cancel"].firstMatch.waitForExistence(timeout: 6) { sb.buttons["Cancel"].firstMatch.tap(); sleep(2) }
            else if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap(); sleep(2) }
        }
        var bloqueada = sb.buttons["Cancel"].firstMatch.waitForExistence(timeout: 6)
            || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'locked'")).firstMatch.exists

        // Si no salió a la primera, una vuelta al fondo y de vuelta: el
        // candado se echa en `alIrseAlFondo()`, no solo al arrancar.
        if !bloqueada {
            XCUIDevice.shared.press(.home); sleep(3)
            app.activate(); sleep(4)
            bloqueada = sb.buttons["Cancel"].firstMatch.waitForExistence(timeout: 6)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'locked'")).firstMatch.exists
        }
        // Si ni así se bloqueó, el fallo es de la señal y no de la pantalla.
        // Decirlo AQUÍ ahorra leer las cinco aserciones de abajo buscando por
        // qué no aparece nada: todas dirían lo mismo con peores palabras.
        XCTAssertTrue(bloqueada, "### la app no se bloqueó ni al arrancar ni al volver del fondo")
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
