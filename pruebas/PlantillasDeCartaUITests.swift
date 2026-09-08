import XCTest

/// **La sección "Plantillas" de Cartas se queda vacía a veces, y no se
/// recupera.** Encontrado el 8 de septiembre de 2026 en la pasada de interfaz
/// del iPhone. Esta prueba NO afirma: abre Cartas veinte veces seguidas y
/// cuenta cuántas se quedan sin filas, que es lo único que se puede hacer con
/// un fallo que no sale siempre.
///
/// **Lo que está demostrado**, con dos capturas de pantalla completas tomadas
/// en builds distintos y a los 4 y a los 10 segundos de abrir:
///
/// - La cabecera "Templates" se dibuja y **debajo no hay ninguna fila**,
///   mientras la sección siguiente —"Issued this month"— sí trae las suyas.
/// - No es lentitud: en las corridas malas no aparecen en 20 s.
/// - **No es el dato.** Instrumentando `CartasViewModel.cargar()` con `NSLog`,
///   `plantillas` vale 16 SIEMPRE, también en las corridas malas.
///
/// **Lo que NO está demostrado, y por eso no se ha "arreglado" nada:** ni la
/// causa ni la frecuencia. El fallo es sensible al tiempo y se esconde en
/// cuanto se instrumenta —con el `NSLog` dentro salieron 11 corridas de 11
/// buenas—, así que cualquier medida de "antes y después" hay que leerla con
/// mucho cuidado. Tres hipótesis probadas y las tres DESCARTADAS, cada una con
/// sus veinte vueltas contra un control de 3 de 20:
///
/// 1. *La `Section` nace vacía y `List` no sabe insertarle filas después* →
///    envolverla en `if !vm.plantillas.isEmpty`: **2 de 20**. Y además no
///    puede ser: en la corrida mala `plantillas` vale 16, así que la condición
///    es cierta y la sección se emite igual.
/// 2. *La asignación cae dentro del primer ciclo de dibujo* → `await
///    Task.yield()` al entrar en `cargar()`: **2 de 20**.
/// 3. *Es la sección vacía la que rompe el diff* → ver la 1.
///
/// **La siguiente pista que vale la pena seguir** es la que queda viva: en
/// `cargar()` hay DOS asignaciones publicadas por separado —`emitidas` y luego
/// `plantillas`— con un `await` entre medias. Si la vista evalúa su cuerpo en
/// ese hueco, la observación de `plantillas` de ese cuerpo en vuelo se puede
/// perder. Se calcularían las dos y se asignarían juntas, sin `await` entre
/// ellas. **No se probó por falta de una medida fiable**, que es justo lo que
/// hay que montar primero.
///
/// **Aviso sobre esta prueba, que costó una vuelta:** el testigo de "ya estoy
/// en Cartas" NO puede ser una fila de la lista. Cuando todo va bien, las 16
/// plantillas empujan "Issued this month" fuera de pantalla, así que usarlo de
/// testigo marca como fallo justo las corridas BUENAS. Se usa la cabecera
/// "Templates", que está en los dos casos. Es la lección del §5: una prueba que
/// no encuentra algo solo vale si sabes que sabría encontrarlo.
final class PlantillasDeCartaUITests: XCTestCase {

    func testLaSeccionDePlantillasSeLlenaSiempre() {
        var sinPlantillas = 0
        let vueltas = 20

        for vuelta in 1...vueltas {
            let app = XCUIApplication()
            app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
            app.launch()
            sleep(2)
            app.tabBars.buttons["Secretary"].tap()
            sleep(2)

            // La fila del hub queda bajo el pliegue: hay que bajar a buscarla.
            let fila = NSPredicate(format: "label BEGINSWITH 'Letters & transfers'")
            for _ in 0..<5 {
                let e = app.buttons.matching(fila).firstMatch
                if e.waitForExistence(timeout: 2) && e.isHittable { e.tap(); break }
                app.swipeUp(velocity: .slow); sleep(1)
            }

            guard app.staticTexts["Templates"].waitForExistence(timeout: 8) else {
                XCTFail("vuelta \(vuelta): no se llegó a Cartas")
                app.terminate(); continue
            }

            var visto = false
            for _ in 0..<10 where !visto {
                if app.staticTexts["Recommendation letter"].exists { visto = true; break }
                Thread.sleep(forTimeInterval: 0.8)
            }
            if !visto {
                sinPlantillas += 1
                print("vuelta \(vuelta): cabecera «Templates» SIN filas debajo")
                print("   textos: \(app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ‖ "))")
                fflush(stdout)
            }
            app.terminate()
        }

        print("RESULTADO: \(sinPlantillas) de \(vueltas) se quedaron sin plantillas")
        fflush(stdout)
        XCTAssertEqual(sinPlantillas, 0,
                       "La sección «Plantillas» se quedó vacía \(sinPlantillas) de \(vueltas) veces")
    }
}
