import XCTest

/// **La sincronización se mudó de «Acceso y áreas» a «Zona de riesgo».**
///
/// Estaba entre los permisos y las invitaciones, que no tienen nada que ver con
/// ella: lo que responde esa sección es "¿mis datos están en algún sitio además
/// de este aparato?", que es exactamente la pregunta de los respaldos.
///
/// La prueba comprueba las DOS mitades. Solo mirar el destino dejaría pasar el
/// error más fácil de cometer al mover algo: dejar una copia en el origen.
final class SincronizacionEnZona: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func abrir(_ fila: String) {
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH %@", fila)
        for _ in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.exists && e.isHittable { e.tap(); break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        sleep(3)
    }

    /// Lo que hay en la pantalla, bajando hasta el final: las secciones de abajo
    /// no están en el árbol hasta que se desplaza.
    func todoLoQueDice() -> [String] {
        var visto = Set<String>()
        for _ in 0..<6 {
            app.staticTexts.allElementsBoundByIndex.forEach { visto.insert($0.label) }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return Array(visto)
    }

    func testLaSincronizacionEstaEnZonaDeRiesgo() {
        abrir("Danger zone")
        // **El botón se mira ANTES de recorrer.** `todoLoQueDice` baja hasta el
        // final, y lo que queda arriba sale del árbol: buscándolo después,
        // "Sincronizar ahora" no existe aunque esté puesto. Y que esté ARRIBA es
        // justo lo que se quería.
        XCTAssertTrue(app.buttons["Sync now"].waitForExistence(timeout: 5),
                      "no está el botón de sincronizar, o no está en lo primero que se ve")
        let dice = todoLoQueDice()
        print("ZONA:" + dice.sorted().joined(separator: "|"))
        parada("zona")
        XCTAssertTrue(dice.contains("Sync"), "la sección Sync no llegó a Zona de riesgo")
        XCTAssertTrue(dice.contains("Not uploaded"), "no está «Sin subir»")
    }

    func testYaNoEstaEnAccesoYAreas() {
        abrir("Access & areas")
        let dice = todoLoQueDice()
        print("ACCESO:" + dice.sorted().joined(separator: "|"))
        parada("acceso")
        XCTAssertFalse(dice.contains("Not uploaded"),
                       "la sincronización sigue también en Acceso y áreas: quedó duplicada")
        XCTAssertFalse(app.buttons["Sync now"].exists,
                       "el botón de sincronizar sigue en Acceso y áreas")
    }

    /// Y la fila de Ajustes no puede seguir describiendo una pantalla que
    /// cambió: decía "los cambios aquí no se pueden deshacer", que es falso
    /// para lo primero que ahora se ve.
    func testLaFilaDeAjustesDiceLoQueHayDentro() {
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        var visto = Set<String>()
        for _ in 0..<5 {
            app.staticTexts.allElementsBoundByIndex.forEach { visto.insert($0.label) }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("AJUSTES:" + visto.sorted().joined(separator: "|"))
        XCTAssertTrue(visto.contains { $0.contains("Sync, backups, and data deletion") },
                      "la fila de Ajustes no menciona la sincronización")
    }
}
