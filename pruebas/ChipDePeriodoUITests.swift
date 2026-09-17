import XCTest

/// **El chip del periodo del reporte, que se pintaba su propia cápsula.**
///
/// Lo vio Iván en "Annual report" y en "Financial statement": el "2026" salía
/// como una pastilla gris DENTRO de la cápsula de cristal del sistema, porque
/// `chipFiltro` llevaba `.background(Color(.tertiarySystemFill), in: Capsule())`
/// y estos menús viven en el `toolbar`.
///
/// No afirma aspecto —eso se mira en la captura— pero sí que el chip EXISTE y
/// se puede tocar: si alguien lo deja sin cápsula y sin contenido, esto cae.
final class ChipDePeriodoUITests: XCTestCase {

    func testReporteAnual() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", ProcessInfo.processInfo.environment["TEMA"] ?? "claro"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(3)

        let reportes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reports'")).firstMatch
        for _ in 0..<5 {
            if reportes.exists && reportes.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard reportes.waitForExistence(timeout: 10) else {
            print("LATERAL:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Reports» en la barra lateral"); return
        }
        reportes.tap(); sleep(3)

        let anual = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Annual'")).firstMatch
        guard anual.waitForExistence(timeout: 10) else {
            print("REPORTES:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(26)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está la tarjeta del reporte anual"); return
        }
        anual.tap(); sleep(4)

        // El chip del año, que es el que se pintaba su cápsula.
        let chip = app.buttons.matching(NSPredicate(format: "label CONTAINS '202'")).firstMatch
        if !chip.waitForExistence(timeout: 8) {
            print("BARRA-REPORTE:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
        }
        print("MARCA:reporte-anual-\(ProcessInfo.processInfo.environment["TEMA"] ?? "claro")")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }
}
