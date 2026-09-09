import XCTest

/// **La puerta y el candado, en iPad.** El modo revisión salta las dos, así
/// que esta clase se corre con el modo APAGADO y en un simulador **recién
/// creado**: el llavero del simulador es común a todas las apps, y uno que
/// alguna vez tuvo sesión la sigue teniendo aunque se desinstale la app (§3).
final class AccesoIPad: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    /// Avisa de lo que se sale por el borde y de los rótulos partidos.
    func revisar(_ nombre: String) {
        let w = app.frame.width
        var fuera: [String] = []
        for e in app.staticTexts.allElementsBoundByIndex where !e.label.isEmpty {
            if e.frame.maxX > w + 1 || e.frame.minX < -1 { fuera.append("\(e.label)\(e.frame)") }
        }
        print(">>> \(nombre)")
        if !fuera.isEmpty { print("### ⚠️ SE SALE: \(fuera.joined(separator: " · "))") }
        print("### TEXTOS: " + app.staticTexts.allElementsBoundByIndex.prefix(25)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        print("### BOTONES: " + app.buttons.allElementsBoundByIndex.prefix(15)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        print("### CAMPOS: " + app.textFields.allElementsBoundByIndex.map { $0.placeholderValue ?? $0.label }
              .joined(separator: " | ") + " · seguros: "
              + app.secureTextFields.allElementsBoundByIndex.map { $0.placeholderValue ?? $0.label }.joined(separator: " | "))
        fflush(stdout)
        parada(nombre)
    }

    func testLaPuertaEnLasDosOrientaciones() {
        app.launch(); sleep(4)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        revisar("P-01-acceso-apaisado")
        XCUIDevice.shared.orientation = .portrait; sleep(3)
        revisar("P-02-acceso-vertical")
    }

    func testLoQueCuelgaDeLaPuerta() {
        app.launch(); sleep(4)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        // Crear cuenta / recuperar contraseña / y el aviso de campos vacíos.
        for b in ["Create an account", "Sign up", "Forgot"] {
            let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", b)).firstMatch
            if e.waitForExistence(timeout: 3), e.isHittable {
                e.tap(); sleep(2); revisar("P-03-\(b.replacingOccurrences(of: " ", with: "-"))")
                for c in ["Cancel", "Back", "Sign in"] where app.buttons[c].exists {
                    app.buttons[c].tap(); sleep(2); break
                }
            }
        }
        // Entrar sin escribir nada: el botón está vivo a propósito (§4) y es la
        // acción la que dice qué falta.
        if app.buttons["Sign in"].exists {
            app.buttons["Sign in"].tap(); sleep(2)
            revisar("P-04-entrar-vacio")
        }
    }
}
