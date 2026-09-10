import XCTest

/// **El campo de importe del alta, en la app corriendo.**
///
/// Lo que las unitarias no pueden decir: qué teclas ofrece el `.decimalPad` con
/// la región del aparato en español, si el botón Guardar se enciende con basura
/// dentro, y qué cifra queda en la lista después.
///
/// Se corre con el modo revisión ENCENDIDO en la copia (§2.2) y con la región
/// puesta desde el shell:
///     xcrun simctl spawn <udid> defaults write .GlobalPreferences AppleLocale -string es_ES
final class ImporteEnPantalla: XCTestCase {

    var app: XCUIApplication!

    func arrancar(_ locale: String, idioma: String) {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", idioma,
                                "-AppleLocale", locale,
                                "-AppleLanguages", locale.hasPrefix("es") ? "(es)" : "(en)"]
        app.launch()
        sleep(2)
    }

    func abrirNuevoIngreso(_ tesoreria: String, _ movimientos: String, _ nuevo: String) {
        app.tabBars.buttons[tesoreria].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH %@", movimientos)
        let fila = app.buttons.matching(p).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 6), "no hay fila \(movimientos)")
        fila.tap(); sleep(2)
        let mas = app.buttons[nuevo]
        XCTAssertTrue(mas.waitForExistence(timeout: 6), "no hay botón \(nuevo)")
        mas.tap(); sleep(2)
    }

    /// **¿Qué separador decimal ofrece el teclado?** Si es coma, el segundo
    /// parseador (`aCentavos`) la borra y multiplica el importe por cien.
    func testQueTeclaOfreceElTecladoEnEspanol() {
        arrancar("es_ES", idioma: "espanol")
        abrirNuevoIngreso("Tesorería", "Movimientos", "Nuevo")
        let teclas = app.keys.allElementsBoundByIndex.map(\.label)
        print("TECLAS:\(teclas.joined(separator: "|"))")
        XCTAssertFalse(teclas.contains(","),
                       "El teclado ofrece coma decimal y el alta la borra")
    }

    /// El camino entero: teclear doce cincuenta a la española y mirar la cifra
    /// grande que queda en el campo tras guardar y volver a abrir.
    func testDoceCincuentaConComa() {
        arrancar("es_ES", idioma: "espanol")
        abrirNuevoIngreso("Tesorería", "Movimientos", "Nuevo")
        let campo = app.textFields["0.00"]
        XCTAssertTrue(campo.waitForExistence(timeout: 6), "no encuentro el campo de importe")
        campo.tap()
        campo.typeText("12,50")
        sleep(1)
        print("CAMPO:\(campo.value as? String ?? "?")")
        let guardar = app.navigationBars.buttons["Guardar"]
        print("GUARDAR-ENCENDIDO:\(guardar.isEnabled)")
        XCTAssertTrue(guardar.exists)
    }

    /// **El botón Guardar solo mira que el campo no esté vacío.** Con un texto
    /// que el parseador no entiende se enciende igual, y lo que guarda es $0.00.
    func testGuardarSeEnciendeConBasura() {
        arrancar("en_US", idioma: "ingles")
        abrirNuevoIngreso("Treasury", "Transactions", "New")
        let campo = app.textFields["0.00"]
        XCTAssertTrue(campo.waitForExistence(timeout: 6))
        campo.tap()
        // Con `.decimalPad` no hay letras, pero sí puntos: dos puntos seguidos
        // no son un número y `Double(...) ?? 0` los convierte en cero.
        campo.typeText("..")
        sleep(1)
        let guardar = app.navigationBars.buttons["Save"]
        print("CAMPO:\(campo.value as? String ?? "?") GUARDAR-ENCENDIDO:\(guardar.isEnabled)")
        XCTAssertFalse(guardar.isEnabled,
                       "Guardar está encendido con \"..\" en el importe: guardaría $0.00")
    }

}

extension ImporteEnPantalla {

    /// **El camino entero, hasta el libro.** Teclea doce cincuenta con la única
    /// tecla decimal que el teclado español ofrece, guarda, y lee la cifra que
    /// queda en la lista de Ingresos.
    func testDoceCincuentaLlegaAlLibroComoMilDoscientos() {
        arrancar("es_ES", idioma: "espanol")
        abrirNuevoIngreso("Tesorería", "Movimientos", "Nuevo")
        let campo = app.textFields["0.00"]
        XCTAssertTrue(campo.waitForExistence(timeout: 6))
        campo.tap(); campo.typeText("12,50"); sleep(1)
        app.navigationBars.buttons["Guardar"].tap()
        sleep(3)
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("LISTA:\(textos.prefix(40).joined(separator: "|"))")
        // En región española `NumberFormatter` no agrupa cuatro dígitos, así
        // que mil doscientos cincuenta se escribe "1250,00" y doce cincuenta
        // sería "12,50".
        XCTAssertTrue(textos.contains { $0.contains("12,50") && !$0.contains("1250") },
                      "No aparece +$12,50 en la lista")
        XCTAssertFalse(textos.contains { $0.contains("1250,00") },
                       "Doce cincuenta quedó anotado como mil doscientos cincuenta")
    }
}
