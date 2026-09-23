import XCTest

/// **El logo en el papel**, que es lo que las pruebas unitarias no ven.
///
/// El modo revisión ya no se parchea: va por `-modoRevision YES`. Para ver
/// el logo de verdad en el papel sigue haciendo falta parchear LA COPIA
/// (nunca el repo): en `LogoIglesia.init`, sembrar una imagen —el
/// `PhotosPicker` abre otro proceso y no se conduce desde un XCUITest sin
/// preparar antes el carrete del simulador—:
///
/// ```swift
/// if imagen == nil { imagen = Self.ejemplo() }   // solo en la copia
/// ```
///
/// Lo que encontró el 7 de septiembre, y ninguna prueba unitaria podía:
///
/// 1. **El logo salía en Ajustes y no en el PDF.** `LogoMembrete` tenía la
///    referencia en un `@State`, y el PDF se dibuja con `ImageRenderer`, fuera
///    de la jerarquía de vistas, donde ese `@State` no llega a instalarse. Con
///    una propiedad normal —como `FirmasPDF`— sale.
/// 2. **El membrete de los tres reportes se fue al centro de la página** al
///    meterlo en un `HStack`, que ocupa todo el ancho y reparte el sobrante.
///    Lo devuelve a su sitio un `Spacer(minLength: 0)` al final.
///
/// Y hay un tercer caso que hay que mirar SIEMPRE, porque es el que más se va
/// a dar: una iglesia sin logo. Se comprueba quitando la siembra: el documento
/// tiene que salir exactamente como salía antes, sin hueco reservado.
final class LogoUITests: XCTestCase {

    func testElLogoSaleEnElPDFDelEstadoFinanciero() {
        let app = XCUIApplication()
        // La maqueta y no la iglesia sincronizada: lo que busca es de la
        // semilla, y lo que escribe se queda en memoria (ver `docs/ROJAS-SEPTIEMBRE.md`).
        app.launchArguments += ["-modoRevision", "YES", "-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Treasury"].waitForExistence(timeout: 30))
        app.buttons["Treasury"].tap()
        sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reports'")).firstMatch.tap()
        sleep(3)
        app.staticTexts["Financial statement"].tap()
        sleep(4)
        // El icono de documento de la barra: la vista previa de la hoja que se
        // imprime, que es donde va el membrete. **Por su rótulo, no por
        // coordenadas**: el rediseño de Reportes en tarjetas (17-19 sep) lo
        // movió, y el toque en (0.893, 0.129) caía en otra cosa. El botón es
        // solo icono, pero su `Label` le da nombre (`ReportesView.accionPDF`).
        app.buttons["PDF preview"].firstMatch.tap()
        sleep(5)
        XCTAssertTrue(app.staticTexts["PDF preview"].exists)
    }

    func testLaCartaLlevaElLogoCentradoSobreElNombre() {
        let app = XCUIApplication()
        // La maqueta y no la iglesia sincronizada: lo que busca es de la
        // semilla, y lo que escribe se queda en memoria (ver `docs/ROJAS-SEPTIEMBRE.md`).
        app.launchArguments += ["-modoRevision", "YES", "-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 30))
        app.buttons["Secretary"].tap()
        sleep(2)
        app.swipeUp(); sleep(1); app.swipeUp(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Letter'")).firstMatch.tap()
        sleep(3)
        app.staticTexts["Recommendation letter"].tap()
        sleep(4)
        XCTAssertTrue(app.staticTexts["Iglesia Nueva Vida"].exists)
    }
}
