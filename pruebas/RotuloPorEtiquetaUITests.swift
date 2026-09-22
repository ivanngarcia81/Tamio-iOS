import XCTest

/// **Buscar un rótulo por su ETIQUETA, no por su tipo.**
///
/// En iOS 27, XCUITest resuelve algunos `UILabel` como `Other` en vez de
/// `StaticText`, y entonces `app.staticTexts["…"]` no casa **aunque el rótulo
/// esté en pantalla**. Lo dice el propio registro de la corrida, que es como se
/// encontró el 22-sep:
///
///     Automation type mismatch: computed Other from legacy attributes vs
///     StaticText from modern attribute. XC_kAXXCAttributeElementType = UILabel
///
/// El síntoma es de los caros: la prueba muere diciendo que no encuentra un
/// nombre que está a la vista, e invita a buscar el fallo en la app. En el iPad
/// de Iván se llevó por delante `ConstanciaIPad`, que ni llegó a comprobar la
/// frase de la constancia —lo único de esa tanda que mide daño al usuario—.
///
/// **El fichero se llama `…UITests.swift` a propósito.** `pruebas/aparato_yaml.py`
/// reparte por nombre: lo que NO acaba así va al paquete de unidad, que no
/// enlaza XCUITest y no compilaría esta extensión.
extension XCUIApplication {
    /// El elemento cuyo rótulo es exactamente ese, del tipo que sea.
    func rotulo(_ texto: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", texto))
            .firstMatch
    }
}
