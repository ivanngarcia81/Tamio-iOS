import XCTest

/// **Lo que ve la tesorera cuando la base de este aparato falla.** Son dos
/// avisos distintos porque son dos situaciones distintas, y confundirlas sería
/// peor que no avisar:
///
/// - **Rojo, "no se guarda nada":** no se pudo abrir ni empezar de cero, así que
///   se trabaja en memoria y al cerrar la app no queda nada.
/// - **Naranja, "estaba dañada, se empezó de cero":** la app SÍ guarda. Un rojo
///   permanente sobre una app que funciona se aprende a ignorar, y a las dos
///   semanas nadie lee ninguno.
///
/// **Cómo se corre.** Tres pasadas, con el shell preparando el contenedor entre
/// una y otra (el contenedor se saca con
/// `xcrun simctl get_app_container <udid> church.tamio.pruebas data`):
///
/// 1. `testConLaBaseSanaNoHayAviso` — sin tocar nada. Es el control positivo:
///    sin él, un aviso que saliera siempre pasaría por bueno.
/// 2. Poner a cero los primeros 4 KB de `tamio.sqlite` →
///    `testLaBaseDaniadaAvisaEnNaranjaYDiceDondeQuedo`.
/// 3. Sustituir `tamio.sqlite` por un DIRECTORIO —así SQLite contesta
///    `CANTOPEN` y no `NOTADB`, que es la rama que no aparta el archivo— →
///    `testLaBaseQueNiSeAbreAvisaEnRojo`.
final class BaseCaida: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(3)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func franja(_ fragmento: String) -> String? {
        app.staticTexts.allElementsBoundByIndex.map(\.label).first { $0.contains(fragmento) }
    }

    var cualquierFranja: String? {
        franja("NOTHING IS BEING SAVED") ?? franja("WAS DAMAGED")
    }

    /// Abre Ajustes · Zona de riesgo y devuelve todo lo que dice.
    func zonaDeRiesgo() -> [String] {
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let zona = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Danger zone'")).firstMatch
        for _ in 0..<6 {
            if zona.exists && zona.isHittable { zona.tap(); break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        sleep(2)
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("ZONA-RIESGO:" + textos.joined(separator: "|"))
        return textos
    }

    /// Pasada 1, con la base sana: **no** puede salir ningún aviso.
    func testConLaBaseSanaNoHayAviso() {
        print("FRANJA:\(cualquierFranja ?? "«ninguna»")")
        parada("sana")
        XCTAssertNil(cualquierFranja, "sale un aviso de base caída con la base sana")
        XCTAssertFalse(zonaDeRiesgo().contains { $0.contains("couldn't be opened") || $0.contains("was damaged") })
    }

    /// Pasada 2, archivo dañado: naranja, y la app sigue guardando.
    func testLaBaseDaniadaAvisaEnNaranjaYDiceDondeQuedo() {
        print("FRANJA:\(cualquierFranja ?? "«ninguna»")")
        parada("daniada")
        XCTAssertNotNil(franja("WAS DAMAGED"), "la base estaba dañada y no se avisa")
        XCTAssertNil(franja("NOTHING IS BEING SAVED"),
                     "dice que no se guarda nada, y sí se guarda: es el aviso equivocado")

        // El aviso tapa la app entera, así que sigue puesto al cambiar de zona.
        for pestana in ["Treasury", "Secretary"] {
            app.tabBars.buttons[pestana].tap(); sleep(2)
            XCTAssertNotNil(franja("WAS DAMAGED"), "el aviso desaparece en \(pestana)")
        }

        let textos = zonaDeRiesgo()
        parada("daniada-zona")
        XCTAssertFalse(textos.contains { $0.contains("Measuring…") },
                       "«Measuring…» sigue puesto")
        XCTAssertTrue(textos.contains { $0.contains("was damaged and a clean one was started") },
                      "Zona de riesgo no explica qué pasó")
        XCTAssertTrue(textos.contains { $0.contains("tamio-danada-") },
                      "no dice dónde quedó la base dañada, que es lo único rescatable")
    }

    /// Pasada 3, la base que ni se abre: rojo, y nada se guarda.
    func testLaBaseQueNiSeAbreAvisaEnRojo() {
        print("FRANJA:\(cualquierFranja ?? "«ninguna»")")
        parada("en-memoria")
        XCTAssertNotNil(franja("NOTHING IS BEING SAVED"),
                        "se trabaja en memoria y no se avisa")
        let textos = zonaDeRiesgo()
        parada("en-memoria-zona")
        XCTAssertTrue(textos.contains { $0.contains("couldn't be opened") },
                      "Zona de riesgo no explica que la base no se pudo abrir")
    }
}
