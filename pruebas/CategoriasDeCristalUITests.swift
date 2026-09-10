import XCTest

/// **El selector Ingresos/Gastos de Categorías, en cristal.**
///
/// Lo pidió Iván rodeándolo en una captura, igual que el de Agenda en su día.
/// Deja de ser un `Picker(.segmented)` —cuyo fondo opaco se lee como un parche
/// gris pegado encima— y pasa a ser dos cápsulas en un `GlassEffectContainer`.
///
/// Lo que la prueba mira, y que la vista sola no dice: que **solo una** esté
/// marcada. Es el fallo de esta receta: `.glass` hereda el tinte del TabView, y
/// sin destintar las no elegidas las dos salen en verde y las dos parecen
/// activas. `isSelected` lo delata aunque en la captura se vean parecidas.
///
/// Se corre con el modo revisión ENCENDIDO. Para el diff de píxeles y para
/// mirarlo en oscuro y en AX1, las paradas están puestas.
final class CategoriasDeCristal: XCTestCase {

    var app: XCUIApplication!

    /// **El tema se pone por la preferencia de la APP, no con
    /// `simctl ui appearance`.** La app fija `preferredColorScheme` desde
    /// `prefs.tema`, así que mientras esté en "claro" u "oscuro" ignora al
    /// sistema: cambiando solo el simulador se cree estar mirando el modo oscuro
    /// y se está mirando el claro.
    ///
    /// Y va como argumento de lanzamiento en CADA prueba, no leído del entorno:
    /// `ProcessInfo.environment` dentro del test es el del runner en el
    /// simulador, no el del shell, y `xcodebuild` no reenvía las variables. Las
    /// dos cosas costaron una captura cada una.
    func arrancar(tema: String) {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.tema", tema]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func abrirCategorias() {
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Categories'")
        for _ in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.exists && e.isHittable { e.tap(); break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        sleep(3)
    }

    func marcada(_ nombre: String) -> Bool {
        app.buttons[nombre].isSelected
    }

    func testEnClaro() { comprobar(tema: "claro") }
    func testEnOscuro() { comprobar(tema: "oscuro") }

    func comprobar(tema: String) {
        arrancar(tema: tema)
        abrirCategorias()
        XCTAssertTrue(app.buttons["Income"].waitForExistence(timeout: 6),
                      "el selector ya no tiene una cápsula «Income»")
        parada("\(tema)-ingresos")

        // Al abrir: Ingresos marcado y Gastos NO. Las dos condiciones importan;
        // solo la primera pasaría también con las dos teñidas de verde.
        XCTAssertTrue(marcada("Income"),  "Ingresos no sale marcado al abrir")
        XCTAssertFalse(marcada("Expenses"), "Gastos también sale marcado: falta destintar la no elegida")

        app.buttons["Expenses"].tap(); sleep(2)
        parada("\(tema)-gastos")
        XCTAssertTrue(marcada("Expenses"), "tocar Gastos no lo marca")
        XCTAssertFalse(marcada("Income"),  "Ingresos sigue marcado tras tocar Gastos")

        // Y el contenido acompaña, que es de lo que va el control.
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("LISTA-GASTOS:" + textos.prefix(14).joined(separator: "|"))
        // Se comprueba con una categoría VISIBLE de cada lado y no con el botón
        // "Nueva categoría de gasto", que queda bajo el pliegue: buscarlo ahí
        // da un "no existe" que es mentira.
        XCTAssertTrue(textos.contains("Compensation"), "la lista no cambió a gastos")
        XCTAssertFalse(textos.contains("Tithe"), "sigue habiendo categorías de ingreso")
    }
}
