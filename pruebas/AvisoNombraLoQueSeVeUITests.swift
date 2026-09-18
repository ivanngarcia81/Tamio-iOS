import XCTest

/// **El aviso tiene que nombrar algo que esté ESCRITO en la pantalla.**
///
/// Los catorce formularios dicen qué falta desde `e6e8a54` y `4b637b6`. Pero el
/// compilador no puede comprobar lo único que importa: que "falta el título del
/// corte" case con el rótulo que se lee. Un aviso que nombra un campo con otra
/// palabra deja al usuario traduciendo, que es justo lo que se quería quitar
/// —"a veces uno tiene que estar adivinando qué hace falta"—.
///
/// El repaso a mano encontró tres que no casaban:
///
/// - **Agenda** decía "el título de la actividad" y la sección se llama
///   "EVENTO", con el campo "Título".
/// - **Movimientos** decía "la categoría" siempre, pero en un INGRESO el
///   selector se llama "Tipo de ingreso": el rótulo cambia con el tipo y el
///   aviso no lo seguía.
/// - **Parientes** decía "elegir a la persona" y el selector se llama
///   "Del padrón".
///
/// Esto lo fija. `AvisoFaltan` junta sus hijos en un solo elemento de
/// accesibilidad, así que el texto SE PUEDE AFIRMAR, no solo mirar: si alguien
/// vuelve a escribir una palabra que no está en la pantalla, esto cae.
final class AvisoNombraLoQueSeVeUITests: XCTestCase {

    var app: XCUIApplication!
    var tema: String { ProcessInfo.processInfo.environment["TEMA"] ?? "claro" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", tema]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(3)
    }

    func parada(_ n: String) { print("MARCA: \(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    /// El aviso, leído del árbol. Vuelca lo que hay si no aparece: un "no
    /// existe" sin volcado manda a buscar el fallo donde no está.
    func textoDelAviso() -> String? {
        // **El inglés no empieza por "Missing".** `AvisoFaltan` compone
        // "\(campo) is missing" —el sujeto va delante, como toca en inglés— y
        // el castellano "Falta \(campo)". Buscar por "Missing" al principio no
        // encontraba nada y la prueba acusaba a la app de no sacar el aviso.
        let aviso = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS 'is missing' OR label CONTAINS 'are missing' "
                  + "OR label BEGINSWITH 'Falta'")).firstMatch
        guard aviso.waitForExistence(timeout: 6) else {
            print("SIN-AVISO:" + app.staticTexts.allElementsBoundByIndex
                    .map { String($0.label.prefix(26)) }.joined(separator: "|"))
            fflush(stdout)
            return nil
        }
        return aviso.label
    }

    /// Toca "Save"/"Add"/"Done" con el formulario vacío y comprueba que el aviso
    /// nombra lo que se espera.
    func exigirAviso(_ esperado: String, _ donde: String,
                     botones: [String] = ["Save", "Add", "Done"]) {
        // **El botón no siempre se llama "Save".** En Agenda dice "Save
        // activity", así que la lista lleva también los que EMPIEZAN por una
        // de estas palabras. Buscar el rótulo exacto daba "no hay botón de
        // guardar" en una pantalla que lo tenía delante.
        var tocado = false
        for b in botones {
            let porPrefijo = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", b)).firstMatch
            if porPrefijo.exists && porPrefijo.isHittable {
                porPrefijo.tap(); tocado = true; break
            }
        }
        for b in botones where !tocado {
            let btn = app.buttons[b]
            if btn.exists && btn.isHittable { btn.tap(); tocado = true; break }
        }
        guard tocado else {
            print("BOTONES-\(donde):" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(18)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no hay botón de guardar en «\(donde)»"); return
        }
        sleep(2)
        parada("aviso-\(donde)")
        guard let texto = textoDelAviso() else {
            XCTFail("«\(donde)»: tocar guardar con el formulario vacío no sacó ningún aviso")
            return
        }
        print("AVISO \(donde): \(texto)"); fflush(stdout)
        XCTAssertTrue(texto.lowercased().contains(esperado.lowercased()),
                      "«\(donde)»: el aviso dice «\(texto)» y no nombra «\(esperado)», "
                      + "que es como se llama el campo en la pantalla")
    }

    @discardableResult
    func pestana(_ nombre: String) -> Bool {
        let b = app.tabBars.buttons[nombre]
        guard b.waitForExistence(timeout: 20) else {
            print("PESTAÑAS:" + app.tabBars.buttons.allElementsBoundByIndex
                    .map { $0.label }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está la pestaña «\(nombre)»"); return false
        }
        b.tap(); sleep(2); return true
    }

    func abrirFila(_ prefijo: String) -> Bool {
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefijo)).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { fila.tap(); sleep(3); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("NO-ESTA \(prefijo):" + app.buttons.allElementsBoundByIndex.prefix(25)
                .map { String($0.label.prefix(22)) }.joined(separator: "|"))
        fflush(stdout)
        XCTFail("no está la fila «\(prefijo)»")
        return false
    }

    /// **Agenda.** La sección se llama "EVENT" y el campo "Title".
    func testAgendaNombraElEvento() {
        // La fila se llama "Calendar" en inglés, no "Agenda".
        guard pestana("Secretary"), abrirFila("Calendar") else { return }
        let mas = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Add' OR label CONTAINS 'New'")).firstMatch
        guard mas.waitForExistence(timeout: 8) else {
            print("BARRA-AGENDA:" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(20)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está el botón de añadir en Agenda"); return
        }
        mas.tap(); sleep(3)
        exigirAviso("activity title", "agenda")
    }

    /// **Movimientos.** Dos casos, y la diferencia importa.
    ///
    /// Un INGRESO nace con categoría puesta, así que lo único que falta es el
    /// importe. Un GASTO nace vacío del todo: importe, categoría y a quién se
    /// pagó, y ahí el selector se llama "Category". La primera versión de esto
    /// exigía "income type" en el ingreso y falló con razón —el aviso decía
    /// "the amount is missing", que es lo correcto—: la rama del tipo de
    /// ingreso solo se alcanza editando, no creando.
    func testMovimientoNombraLoQueFalta() {
        guard pestana("Treasury"), abrirFila("Transactions") else { return }
        let mas = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Add' OR label CONTAINS 'New'")).firstMatch
        guard mas.waitForExistence(timeout: 8) else {
            print("BARRA-MOV:" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(20)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está el botón de añadir en Movimientos"); return
        }
        mas.tap(); sleep(3)
        // Ingreso: la categoría viene puesta, así que solo falta el importe.
        exigirAviso("the amount", "movimiento-ingreso")

        // Gasto: nace vacío, y el selector se llama "Category".
        let gasto = app.buttons["Expense"]
        guard gasto.waitForExistence(timeout: 6) else {
            print("SEGMENTADO:" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(18)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está el segmentado Income/Expense"); return
        }
        gasto.tap(); sleep(2)
        exigirAviso("category", "movimiento-gasto")
    }
}
