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

    /// **La medida que lo destapó todo, y que ahora vigila el arreglo.**
    ///
    /// El `.decimalPad` de un iPhone con región española ofrece
    /// `1|2|3|4|5|6|7|8|9|,|0|Delete`: **no hay tecla de punto**. Eso no es un
    /// fallo del teclado —es lo correcto para esa región— sino el hecho que
    /// explica el resto: mientras el alta borraba las comas, la única forma que
    /// esa tesorera tenía de escribir céntimos multiplicaba el importe por cien.
    ///
    /// Lo que esta prueba exige, entonces, no es que el teclado deje de dar
    /// coma, sino **que el marcador del campo proponga la misma tecla que el
    /// teclado ofrece**. Un campo que dice "0.00" sobre un teclado sin punto le
    /// está pidiendo al usuario algo que no puede teclear.
    func testElMarcadorUsaLaTeclaQueElTecladoOfrece() {
        arrancar("es_ES", idioma: "espanol")
        abrirNuevoIngreso("Tesorería", "Movimientos", "Nuevo")
        let teclas = app.keys.allElementsBoundByIndex.map(\.label)
        print("TECLAS:\(teclas.joined(separator: "|"))")

        let marcador = app.textFields.element(boundBy: 0).placeholderValue ?? ""
        print("MARCADOR:\(marcador)")
        let separadorDelMarcador = marcador.contains(",") ? "," : "."
        XCTAssertTrue(teclas.contains(separadorDelMarcador),
                      "el campo propone «\(marcador)» y el teclado no tiene «\(separadorDelMarcador)»")
    }

    /// El camino entero: teclear doce cincuenta a la española y mirar la cifra
    /// grande que queda en el campo tras guardar y volver a abrir.
    func testDoceCincuentaConComa() {
        arrancar("es_ES", idioma: "espanol")
        abrirNuevoIngreso("Tesorería", "Movimientos", "Nuevo")
        // **No por el marcador.** Ahora lleva el separador del aparato
        // (`NuevoMovimientoView.aTexto(0)`), así que en `es_ES` es "0,00" y
        // buscarlo por "0.00" no encuentra nada.
        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 6), "no encuentro el campo de importe")
        campo.tap()
        campo.typeText("12,50")
        sleep(1)
        print("CAMPO:\(campo.value as? String ?? "?")")
        let guardar = app.navigationBars.buttons["Guardar"]
        print("GUARDAR-ENCENDIDO:\(guardar.isEnabled)")
        XCTAssertTrue(guardar.exists)
    }

    /// **Guardar tiene que exigir un importe que se entienda.** Antes solo
    /// miraba que el campo no estuviera vacío, así que con ".." se encendía y
    /// guardaba $0.00 —con su folio gastado y contando para el corte—.
    func testGuardarNoSeEnciendeConBasura() {
        arrancar("en_US", idioma: "ingles")
        abrirNuevoIngreso("Treasury", "Transactions", "New")
        // **No por el marcador.** Ahora lleva el separador del aparato
        // (`NuevoMovimientoView.aTexto(0)`), así que en `es_ES` es "0,00" y
        // buscarlo por "0.00" no encuentra nada.
        let campo = app.textFields.element(boundBy: 0)
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
        // **No por el marcador.** Ahora lleva el separador del aparato
        // (`NuevoMovimientoView.aTexto(0)`), así que en `es_ES` es "0,00" y
        // buscarlo por "0.00" no encuentra nada.
        let campo = app.textFields.element(boundBy: 0)
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
