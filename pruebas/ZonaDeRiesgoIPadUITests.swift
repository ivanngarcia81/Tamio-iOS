import XCTest

/// **La Zona de riesgo del iPad no avisa de que la base está caída.**
///
/// `BaseLocal.caida` se lee en exactamente dos sitios de toda la app:
/// `RootView.swift:225` —la franja, común a las dos formas— y
/// `IPhoneAjustesView.swift:1540`, que es la de TELÉFONO. `SeccionZona`
/// (`ConfiguracionView.swift:1329`), que es la del iPad, **no lo mira**, y su
/// fila de espacio es `estadoBase?.resumen ?? "Midiendo…"` alimentada por
/// `Compactacion.medir()`, que devuelve `nil` cuando la base está en memoria
/// (`Compactacion.swift:53`).
///
/// O sea: con la base caída esta pantalla se queda en «Midiendo…» para
/// siempre. Y es la pantalla a la que va quien sospecha que algo no se está
/// guardando — porque nada se está guardando.
///
/// **Cómo se pone la base en ese estado**: no vale un archivo basura, que da
/// `SQLITE_NOTADB` y `esArchivoDaniado` (`BaseLocal.swift:78`) lo desvía a
/// `seEmpezoDeCero`. Hace falta que la apertura falle sin ser corrupción; sirve
/// dejar un DIRECTORIO llamado `tamio.sqlite` en `Library/Application Support`,
/// que da `SQLITE_CANTOPEN`.
///
///     xcrun devicectl device copy to --device <UDID> \
///       --domain-type appDataContainer --domain-identifier church.tamio.native \
///       --source <carpeta local> --destination "Library/Application Support/tamio.sqlite"
///
/// **Con la base SANA esta prueba debe pasar** —es su control positivo: sin él,
/// un verde no distingue "avisa" de "no llegué a la pantalla"—.
final class ZonaDeRiesgoIPadUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "1"]
        app.launch()
        sleep(3)
    }

    /// Llega a Configuración → Zona de riesgo. En el iPad va por la sidebar.
    private func abrirZonaDeRiesgo() -> Bool {
        for titulo in ["Settings", "Configuración"] {
            let b = app.buttons[titulo]
            if b.waitForExistence(timeout: 5) && b.isHittable { b.tap(); sleep(2); break }
        }
        let zona = app.buttons["Danger zone"]
        guard zona.waitForExistence(timeout: 6) else { return false }
        guard zona.isHittable else { return false }
        zona.tap(); sleep(3)
        return true
    }

    /// El control positivo de la navegación: si esto falla, lo de abajo no mide
    /// la Zona de riesgo sino mi incapacidad de llegar a ella.
    func testControlSeLlegaALaZonaDeRiesgo() {
        XCTAssertTrue(abrirZonaDeRiesgo(), "no se llegó a la Zona de riesgo: nada de lo demás mide nada")
        XCTAssertTrue(app.staticTexts["Storage on this device"].waitForExistence(timeout: 6)
                      || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'torage'"))
                          .firstMatch.waitForExistence(timeout: 3),
                      "la fila de espacio no salió")
    }

    /// **El hallazgo.** La fila de espacio no puede quedarse en «Midiendo…».
    ///
    /// Con la base sana pasa porque `medir()` termina y devuelve un resumen.
    /// Con la base caída, hoy, se queda ahí para siempre y la pantalla no dice
    /// ni una palabra de que nada se está guardando.
    func testLaFilaDeEspacioNoSeQuedaMidiendo() {
        guard abrirZonaDeRiesgo() else {
            return XCTFail("no se llegó a la Zona de riesgo")
        }
        // Generoso: `medir()` recorre la base entera.
        sleep(12)

        let midiendo = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Measuring' OR label BEGINSWITH 'Midiendo'")
        ).firstMatch

        if midiendo.exists && midiendo.isHittable {
            // Si de verdad está midiendo por lentitud, al cabo de otro rato se
            // va. Si sigue, no está midiendo: no hay nada que medir.
            sleep(15)
            let sigue = midiendo.exists && midiendo.isHittable
            XCTAssertFalse(sigue,
                           "### la Zona de riesgo del iPad lleva 27 s en «Midiendo…»: "
                           + "con la base caída se queda así para siempre y no lo dice")
        }
    }
}
