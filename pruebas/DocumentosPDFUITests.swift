import XCTest

/// **Los documentos de Secretaría, vistos.** Requiere el parche de modo
/// revisión en la copia (ver `pruebas/LogoUITests.swift`).
///
/// Lo que encontró el 7 de septiembre y ninguna prueba unitaria daba:
///
/// 1. **La hoja se dibujaba estrecha y con todo el texto cortado en "…".**
///    Faltaba `.frame(width: PDFExport.anchoCarta)` en la raíz de cada hoja —el
///    contrato que documenta `HojaCartaEscalada` y que cumplen las otras
///    cuatro—. Sin nadie que proponga un ancho, cada `Text` se mide a UNA
///    línea. Y aun con el ancho puesto, los textos largos necesitan
///    `.fixedSize(horizontal: false, vertical: true)` para envolver.
/// 2. **El acta imprimía dos veces la lista de asistentes**: se le había
///    añadido una tabla de datos de la reunión sin ver que `Acta.cuerpo` ya
///    narra lugar, hora, quién preside, presentes y ausentes.
final class DocumentosPDFUITests: XCTestCase {

    private func alHub(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 30))
        app.buttons["Secretary"].tap()
        sleep(2)
        app.swipeUp(); sleep(1); app.swipeUp(); sleep(2)
    }

    func testElActaTienePDF() {
        let app = XCUIApplication()
        alHub(app)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Minutes'")).firstMatch.tap()
        sleep(3)
        app.cells.firstMatch.tap()
        sleep(2)
        let pdf = app.buttons["PDF"].firstMatch
        XCTAssertTrue(pdf.waitForExistence(timeout: 8), "### el acta no tiene botón de PDF")
        pdf.tap()
        sleep(5)
        XCTAssertTrue(app.staticTexts["PDF preview"].exists)
    }

    /// Una carta a medias se mira y no se entrega; una completa, sí. El botón
    /// ya estaba bloqueado antes — lo que faltaba era que hubiera algo detrás.
    func testLaCartaCompletaSeComparteYLaDeAMediasNo() {
        let app = XCUIApplication()
        alHub(app)
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Letter'")).firstMatch.tap()
        sleep(3)
        app.staticTexts["Recommendation letter"].tap()
        sleep(3)

        app.buttons["Preview"].firstMatch.tap()
        sleep(4)
        XCTAssertFalse(app.buttons["Share"].firstMatch.exists,
                       "### una carta sin llenar no se puede entregar")
        app.buttons["Close"].firstMatch.tap()
        sleep(2)

        for (campo, valor) in [("Member name", "Ana Lucía Torres"),
                               ("Recipient", "Iglesia Betel"),
                               ("Member since", "2019")] {
            let f = app.textFields[campo].firstMatch
            XCTAssertTrue(f.waitForExistence(timeout: 5), "### falta el campo \(campo)")
            f.tap(); f.typeText(valor)
            sleep(1)
        }
        app.swipeDown()
        sleep(1)
        app.buttons["Preview"].firstMatch.tap()
        sleep(5)
        XCTAssertTrue(app.buttons["Share"].firstMatch.exists,
                      "### la carta completa sigue sin poder compartirse")
    }
}
