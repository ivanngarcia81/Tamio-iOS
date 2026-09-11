import XCTest

/// **La pasada de interfaz del iPad · los Ajustes.** Recorre la pantalla de
/// Configuración del iPad parándose en cada postura para que el shell dispare
/// `xcrun simctl io <udid> screenshot`: el adjunto de XCUITest en apaisado
/// devuelve la imagen rotada dentro de un lienzo apaisado y además recorta
/// (§0.0 del traspaso), así que las capturas se toman desde fuera.
///
/// El volcado de cada parada trae el marco de cada rótulo, que es lo que
/// delata un alto de fila que no es el que se cree y un texto que se sale por
/// el borde.
final class AjustesIPadUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        // Un contenedor recién estrenado abre la app en la bienvenida, y
        // entonces la sidebar no existe (§0.-7).
        app.launchArguments = ["-prefs.bienvenidaVista", "1"]
        app.launch()
    }

    /// Se para, avisa, y deja tiempo a que el shell fotografíe.
    private func parada(_ nombre: String) {
        print("MARCA: \(nombre)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 4.0)
    }

    /// Vuelca los rótulos visibles con su marco, y avisa de lo que se sale.
    private func volcar(_ titulo: String) {
        let ancho = app.frame.width
        print("===== VOLCADO \(titulo) · ventana \(app.frame.size)")
        for t in app.staticTexts.allElementsBoundByIndex.prefix(90) {
            guard t.exists, t.isHittable else { continue }
            let f = t.frame
            let fuera = (f.maxX > ancho + 0.5) ? "  ⚠️SEsALE" : ""
            print(String(format: "  %-44@  x=%.0f y=%.0f w=%.0f h=%.0f%@",
                         String(t.label.prefix(44)) as NSString,
                         f.minX, f.minY, f.width, f.height, fuera as NSString))
        }
        print("===== FIN \(titulo)")
        fflush(stdout)
    }

    private func irAConfiguracion() {
        // La sidebar puede venir colapsada en vertical; en apaisado está fija.
        let fila = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Configuración' OR label BEGINSWITH 'Settings'")).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 20), "no aparece la fila de Configuración")
        fila.tap()
    }

    func testAjustesEnApaisado() throws {
        irAConfiguracion()
        sleep(2)
        volcar("ajustes · cuenta")
        parada("ajustes-cuenta")

        // Las secciones de Ajustes, una a una: es donde viven los radios y los
        // altos de fila que esta pasada unifica.
        for nombre in ["Iglesia", "Church",
                       "Institución", "Institution",
                       "Tesorero", "Treasurer",
                       "Acceso", "Access",
                       "Categorías", "Categories",
                       "Preferencias", "Preferences"] {
            let b = app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH %@", nombre)).firstMatch
            guard b.exists, b.isHittable else { continue }
            b.tap()
            sleep(2)
            volcar("ajustes · \(nombre)")
            parada("ajustes-\(nombre)")
        }
    }

    /// La cabecera de la iglesia de la sidebar: hasta esta pasada dibujaba un
    /// galón y no era `Button`. Aquí se comprueba que ahora SÍ lo es y que
    /// lleva a Configuración.
    func testLaCabeceraDeLaIglesiaLleva() throws {
        let cab = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Configuración' OR label CONTAINS 'Settings'")).allElementsBoundByIndex
        print("=== candidatos de cabecera: \(cab.map { $0.label })")
        // La cabecera lleva el nombre de la iglesia por delante del destino.
        let cabecera = app.buttons.matching(NSPredicate(
            format: "label CONTAINS ', ir a Configuración' OR label CONTAINS ', go to Settings'")).firstMatch
        XCTAssertTrue(cabecera.waitForExistence(timeout: 20),
                      "la cabecera de la iglesia no es un botón con destino")
        XCTAssertTrue(cabecera.isHittable, "la cabecera existe pero no se puede tocar")
        cabecera.tap()
        sleep(2)
        volcar("tras tocar la cabecera")
        parada("cabecera-destino")
        // Si llevó a Ajustes, tiene que verse el título de la pantalla.
        let titulo = app.staticTexts.matching(NSPredicate(
            format: "label == 'Configuración' OR label == 'Settings'")).firstMatch
        XCTAssertTrue(titulo.waitForExistence(timeout: 10),
                      "tocar la cabecera no llevó a Configuración")
    }
}
