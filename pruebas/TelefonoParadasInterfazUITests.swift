import XCTest

/// **Las paradas del teléfono para el diff de píxeles.**
///
/// Se corre en el iPhone 17e (390 pt, el más estrecho con iOS 26) y **en
/// inglés**, que es donde las etiquetas son más largas y donde viven casi
/// todas las correcciones de vocabulario de esta pasada.
///
/// **Un diff solo vale con corrida de control** (§0.0): dos corridas del mismo
/// código dan 0.000 %, y cualquier cosa distinta de cero es real. Por eso esta
/// prueba se corre DOS veces antes de tocar nada.
final class TelefonoParadasUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        sleep(2)
    }

    private func parada(_ n: String) {
        print("MARCA: tel__\(n)"); fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }

    private func pestana(_ nombres: [String]) -> Bool {
        for n in nombres {
            let b = app.tabBars.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", n)).firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(2); return true }
        }
        return false
    }

    private func toca(_ nombres: [String]) -> Bool {
        for n in nombres {
            let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", n)).firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(2); return true }
        }
        return false
    }

    func testParadas() throws {
        parada("01-inicio")

        // Tesorería → Aportantes (MiembrosView: cinco de las correcciones)
        _ = pestana(["Treasury", "Tesorería"])
        parada("02-tesoreria")
        if toca(["Contributors", "Aportantes"]) { parada("03-aportantes") }

        // El menú de la barra, donde viven "Import givers…" y "Givers (CSV)"
        if toca(["More", "Más", "ellipsis"]) { parada("04-menu-aportantes") }
        else { app.navigationBars.buttons.element(boundBy: 1).tap(); sleep(1); parada("04-menu-aportantes") }
        app.tap(); sleep(1)

        // Por revisar → EditarAsuntoView ("Giver", "Concept")
        _ = pestana(["To review", "Por revisar"])
        parada("05-porRevisar")
        if toca(["Edit", "Editar"]) { parada("06-editar-asunto") }

        // Secretaría → informes y servicios ("Role", "ROSTER", "PASSAGE")
        _ = pestana(["Secretary", "Secretaría"])
        parada("07-secretaria")
        if toca(["Membership reports", "Informes"]) { parada("08-informes") }
        _ = pestana(["Secretary", "Secretaría"])
        if toca(["Service log", "Registro de servicios"]) { parada("09-servicios") }
    }
}
