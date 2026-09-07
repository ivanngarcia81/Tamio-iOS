import XCTest

/// **Ajustes visto por un rol que no es el administrador.**
///
/// Para correrla hay que parchear LA COPIA (nunca el repo): `ModoRevision`
/// `activada = true` y, en `SesionSupabase.restaurar()`, el perfil de ejemplo
/// con el rol que se quiera probar. Sin eso la app pide credenciales y el
/// perfil por omisión es `.administrador`, que lo ve todo y no prueba nada.
///
/// Corrida el 7 de septiembre en un iPad Pro con rol `.tesorero`: Categorías
/// sí, Zona de riesgo no, y el índice termina en Preferencias sin dejar el
/// separador de la Zona colgando. La variante de iPhone con `.secretaria`
/// enseñó además lo que la prueba unitaria no puede ver: que el número de
/// versión, que vivía al pie de la Zona, sigue apareciendo al pie de General.
final class AjustesPorRolUITests: XCTestCase {

    func testElTesoreroVeCategoriasPeroNoLaZona() {
        let app = XCUIApplication()
        app.launch()
        sleep(6)
        // La sidebar del iPad arranca plegada: el botón de arriba a la
        // izquierda. Por coordenadas porque no tiene identificador propio.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.031, dy: 0.06)).tap()
        sleep(2)
        let ajustes = app.buttons["Settings"].firstMatch
        XCTAssertTrue(ajustes.waitForExistence(timeout: 10))
        ajustes.tap()
        sleep(3)
        XCTAssertTrue(app.staticTexts["Categories"].exists,
                      "### al tesorero le desaparecieron sus categorías")
        XCTAssertFalse(app.staticTexts["Danger zone"].exists,
                       "### de la Zona de riesgo salen los CSV de la tesorería y del padrón")
    }
}
