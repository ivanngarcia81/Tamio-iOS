import XCTest

/// **Lo que ve la tesorera cuando la base de este aparato no se pudo abrir.**
///
/// Se corre en dos pasadas, con el shell estropeando el `.sqlite` entre una y
/// otra (la cabecera de `BaseMudaTests` lleva los comandos). En la primera la
/// base está sana y no debe salir ningún aviso; en la segunda tiene que salir la
/// franja roja en TODAS las pantallas y el detalle en Ajustes · Zona de riesgo.
final class BaseCaida: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(3)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    var franja: String? {
        app.staticTexts.allElementsBoundByIndex.map(\.label)
            .first { $0.contains("NOTHING IS BEING SAVED") }
    }

    /// Pasada 1, con la base sana: **no** puede haber aviso.
    func testConLaBaseSanaNoHayAviso() {
        print("FRANJA:\(franja ?? "«ninguna»")")
        parada("base-sana")
        XCTAssertNil(franja, "sale el aviso de base caída con la base sana")
    }

    /// Pasada 2, con el archivo estropeado.
    func testConLaBaseCaidaAvisaEnTodasPartes() {
        print("FRANJA-INICIO:\(franja ?? "«ninguna»")")
        parada("base-caida-inicio")
        XCTAssertNotNil(franja, "la base está caída y no se avisa en la pantalla de inicio")

        // La franja tapa la app entera, así que sigue puesta al cambiar de zona.
        for pestana in ["Treasury", "Secretary", "Settings"] {
            app.tabBars.buttons[pestana].tap(); sleep(2)
            XCTAssertNotNil(franja, "el aviso desaparece en \(pestana)")
        }
        parada("base-caida-ajustes")

        // Y el detalle, donde se puede leer el error y qué hacer.
        let zona = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Danger zone'")).firstMatch
        for _ in 0..<6 {
            if zona.exists && zona.isHittable { zona.tap(); break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        sleep(2)
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("ZONA-RIESGO:" + textos.joined(separator: "|"))
        parada("base-caida-zona")
        XCTAssertFalse(textos.contains { $0.contains("Measuring…") },
                       "«Measuring…» sigue puesto: no distingue midiendo de base caída")
        XCTAssertTrue(textos.contains { $0.contains("couldn't be opened") },
                      "Zona de riesgo no explica que la base no se pudo abrir")
    }
}
