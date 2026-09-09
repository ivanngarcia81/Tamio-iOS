import XCTest

/// Los dos importadores de CSV —que piden elegir un archivo de verdad— y la
/// cámara del recibo.
///
/// **El CSV se deja de antemano en "On My iPad"**: la app no puede guardarlo
/// ahí sin manos. Se escribe en el contenedor del simulador, en
/// `.../data/Containers/Shared/AppGroup/<el de group.com.apple.FileProvider.LocalStorage>/File Provider Storage/`,
/// con las cabeceras de `ExportadorAportantes.columnasAportantes` y
/// `columnasAportes`.
///
/// **Y el selector corre en OTRO proceso**: ni `DocumentsApp.state` ni el
/// conteo de botones de la app lo ven —con ese detector se da por roto lo que
/// funciona—. Lo delatan sus propios textos: "Recents", "On My iPad".
final class ImportarIPad: HojasIPad {

    /// De punta a punta: el menú abre el selector, el selector entrega un CSV
    /// y el CSV llega al mapeo y de ahí a la previa. Los archivos se dejan de
    /// antemano en "On My iPad": la app no puede guardarlos ahí sin manos.
    private func importar(_ opcion: String, archivo: String, marca: String) {
        seccion("Contributors")
        guard toca("File") else { return XCTFail("no hay menú Archivo") }
        sleep(1)
        guard toca(opcion) else { return XCTFail("no hay \(opcion)") }
        sleep(3)
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(["Recents", "On My iPad"].contains {
            app.staticTexts[$0].exists || sb.staticTexts[$0].exists
        }, "el selector de archivos no abrió")
        for a in [app, sb] {
            let d = a!.staticTexts["On My iPad"].firstMatch
            if d.exists && d.isHittable { d.tap(); sleep(2); break }
        }
        var tocado = false
        for a in [app, sb] {
            let csv = a!.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", archivo)).firstMatch
            guard csv.waitForExistence(timeout: 5) else { continue }
            // En la rejilla el nombre es solo la etiqueta: abre el icono.
            csv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.8)).tap()
            tocado = true; break
        }
        guard tocado else { return XCTFail("el CSV no aparece en el selector") }
        sleep(5)
        let cont = app.buttons["Continue"].firstMatch
        XCTAssertTrue(cont.waitForExistence(timeout: 6), "el CSV no llegó al mapeo de columnas")
        XCTAssertTrue(cont.isEnabled, "el mapeo no reconoció las columnas del CSV")
        cont.tap(); sleep(4)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import '")).firstMatch.exists,
                      "el mapeo no llevó a la previa de importación")
        print("### \(marca) · botones=" + app.buttons.allElementsBoundByIndex.prefix(8)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        print("MARCA:\(marca)"); fflush(stdout); Thread.sleep(forTimeInterval: 2)
        cerrar()
    }

    func testImportarAportantes() {
        importar("Import givers", archivo: "givers-template", marca: "I-04-aportantes")
    }

    func testImportarAportes() {
        importar("Import gifts", archivo: "gifts-template", marca: "I-05-aportes")
    }

    func testCamaraDelRecibo() {
        seccion("Deposits")
        tocaTexto("Sunday, September 6 service")
        guard toca("Mark deposited") else { return }
        sleep(2)
        guard toca("Take a photo") else {
            print("### no hay botón de cámara: hayCamara dice que no")
            return
        }
        sleep(4)
        revisarSuave("I-06-camara")
        // Se cierra con Cancel, que en la cámara del sistema está abajo.
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for a in [app, sb] {
            let c = a!.buttons["Cancel"].firstMatch
            if c.exists && c.isHittable { c.tap(); sleep(2); break }
        }
        print("### tras cerrar la cámara: hoja=\(app.buttons["Cancel"].firstMatch.exists)")
    }
}
