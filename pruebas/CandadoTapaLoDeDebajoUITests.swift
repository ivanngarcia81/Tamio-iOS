import XCTest

/// **Con el candado puesto, ¿lo de debajo está solo listado o se puede TOCAR?**
///
/// El volcado de `CandadoIPad` en el aparato deja ver, con
/// «The church's accounts are locked.» en pantalla, que el árbol sigue
/// listando `Sign out`, `Danger zone`, `Access & areas` y las cifras de Inicio
/// (`Cash on hand $1,441,200.00`).
///
/// **Eso NO es un hallazgo por sí solo**, y el traspaso lo avisa: con una capa
/// encima XCUITest sigue enumerando lo de abajo. Lo que separa "está en el
/// árbol" de "se puede usar" es `isHittable`, y eso es lo que mide esto.
///
/// Lo que sí sería grave: que un botón de debajo respondiera al dedo con la
/// app bloqueada. `Sign out` y `Danger zone` son los dos peores.
///
/// **Lo que esta prueba NO puede contestar** es si VoiceOver LEE las cifras de
/// debajo: XCUITest las lista aunque estén ocultas para accesibilidad. Eso es
/// el §7 de `COMPROBACION-DINERO.md` y pide VoiceOver de verdad.
final class CandadoTapaLoDeDebajoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(3)
    }

    private var estaBloqueada: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'locked'")).firstMatch.exists
    }

    func testConElCandadoPuestoNadaDeDebajoSeDejaTocar() throws {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if sb.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5) {
            sb.buttons["Cancel"].firstMatch.tap(); sleep(2)
        }
        try XCTSkipUnless(estaBloqueada,
                          "la app no está bloqueada: enciende el candado en Ajustes · Cuenta")

        // **Control positivo**: el botón del propio candado SÍ tiene que ser
        // tocable. Sin esto, un "nada es tocable" podría significar solo que la
        // pantalla no respondía.
        let desbloquear = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Unlock'")).firstMatch
        XCTAssertTrue(desbloquear.exists && desbloquear.isHittable,
                      "### control: el botón de desbloquear no es tocable, así que la medida de abajo no vale")

        let prohibidos = ["Sign out", "Danger zone", "Access & areas", "Account",
                          "Church", "Categories", "Preferences", "New"]
        var tocables: [String] = []
        for etiqueta in prohibidos {
            let b = app.buttons[etiqueta].firstMatch
            let estado = b.exists ? (b.isHittable ? "TOCABLE" : "solo en el árbol") : "no está"
            NSLog("[QA-CANDADO] %@ → %@", etiqueta, estado)
            if b.exists && b.isHittable { tocables.append(etiqueta) }
        }

        XCTAssertTrue(tocables.isEmpty,
                      "### con la app BLOQUEADA estos botones responden al dedo: "
                      + tocables.joined(separator: ", "))
    }
}
