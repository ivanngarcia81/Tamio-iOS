import XCTest

/// **Lo que de estas tres frases se puede comprobar mirando.**
///
/// El subtítulo de Actas **no**, y conviene saber por qué: los datos de ejemplo
/// son los que inspiraron la frase escrita a mano, así que el texto calculado
/// sale idéntico —"Minutes 2026-08 in draft"— y la pantalla se ve igual antes y
/// después. La diferencia solo aparece cambiando el padrón de actas, que es lo
/// que hacen las pruebas unitarias con tres listas distintas.
///
/// Lo que sí se ve es el "Guardado hace 2 minutos": las actas de ejemplo no
/// tienen fecha de guardado, así que ahora no debe salir nada bajo el borrador.
final class TextosQueMentianUITests: XCTestCase {

    func testElBorradorYaNoDiceUnaHoraInventada() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 30))
        app.buttons["Secretary"].tap()
        sleep(2)
        app.swipeUp(); sleep(1); app.swipeUp(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Minutes'")).firstMatch.tap()
        sleep(3)
        app.cells.firstMatch.tap()
        sleep(3)
        XCTAssertFalse(app.staticTexts["Saved 2 minutes ago"].exists,
                       "### sigue la hora escrita a mano")
    }
}
