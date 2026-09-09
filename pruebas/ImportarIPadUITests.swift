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

    /// **El camino del dinero, de punta a punta.** No basta con que la app
    /// diga que importó: hay que ir a ver qué quedó escrito. El CSV trae
    /// `2026-09-06 · 1500.00` para Ana Lucía, que ya tiene $19,600 en 2026.
    ///
    /// Esta prueba encontró tres cosas y las tres siguen aquí como red:
    /// el aporte SÍ se escribe (lo verde), la ficha abierta no se entera, y la
    /// fecha se corre un día. Las dos últimas van con `XCTExpectFailure`, así
    /// que **se ponen en rojo solas el día que se arreglen**.
    func testElAporteImportadoQuedaComoVenia() {
        seccion("Contributors")
        guard toca("File") else { return XCTFail("no hay menú Archivo") }
        sleep(1)
        guard toca("Import gifts") else { return XCTFail("no hay Import gifts") }
        sleep(3)
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for a in [app, sb] {
            let d = a!.staticTexts["On My iPad"].firstMatch
            if d.exists && d.isHittable { d.tap(); sleep(2); break }
        }
        var tocado = false
        for a in [app, sb] {
            let csv = a!.staticTexts.matching(NSPredicate(format: "label CONTAINS 'gifts-template'")).firstMatch
            guard csv.waitForExistence(timeout: 5) else { continue }
            csv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.8)).tap()
            tocado = true; break
        }
        guard tocado else { return XCTFail("el CSV no aparece en el selector") }
        sleep(5)
        let cont = app.buttons["Continue"].firstMatch
        XCTAssertTrue(cont.waitForExistence(timeout: 6), "el CSV no llegó al mapeo")
        cont.tap(); sleep(4)

        // La previa dice lo que va a escribir. El CSV pone 2026-09-06.
        let previa = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS 'Sep' AND label CONTAINS '2026'")).allElementsBoundByIndex.map(\.label)
        print("### la previa dice: \(previa)")
        // La fila importada es la que trae el concepto crudo del CSV
        // ("diezmo"); las sembradas dicen "Tithe" y están bien fechadas.
        let importada = previa.first { $0.contains("diezmo") } ?? "(no la encontré)"
        XCTExpectFailure("La fecha se corre un día: `Fechas.desdeTexto` parsea la fecha suelta a medianoche UTC y `Fechas.corta` la formatea en la zona del aparato. Alcanza también a lo que baja del web (MotorSincronizacion:2843).") {
            XCTAssertTrue(importada.contains("Sep 6"),
                          "el CSV dice 2026-09-06 y la previa dice '\(importada)'")
        }

        let imp = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import '")).firstMatch
        XCTAssertTrue(imp.exists, "no llegó a la previa de importación")
        imp.tap()

        // ¿Se entera la ficha que está abierta? Medido: no, ni en 14 segundos.
        var totalTrasImportar: [String] = []
        for _ in 1...7 {
            sleep(2)
            totalTrasImportar = app.staticTexts.matching(NSPredicate(
                format: "label CONTAINS '19,600' OR label CONTAINS '21,100'"))
                .allElementsBoundByIndex.map(\.label)
            if totalTrasImportar.contains(where: { $0.contains("21,100") }) { break }
        }
        print("### total tras importar: \(totalTrasImportar)")
        XCTExpectFailure("La ficha abierta no se refresca: `Aportante` define `==` como `l.id == r.id`, así que para SwiftUI la ficha vieja y la nueva son la misma vista y no vuelve a dibujarla. Lo mismo en Movimiento, Acta, Servicio, Corte, Miembro, Apunte y Revision.") {
            XCTAssertTrue(totalTrasImportar.contains { $0.contains("21,100") },
                          "el total siguió en \(totalTrasImportar) tras importar $1,500")
        }

        // Y lo que de verdad importa: que el dato esté escrito. Saliendo y
        // volviendo se relee, y ahí sí tiene que estar.
        tocaTexto("Javier Medina Cruz"); sleep(2)
        tocaTexto("Ana Lucía Torres Beltrán"); sleep(3)
        if toca("Giving") { sleep(2) }
        print("MARCA:I-07-tras-importar"); fflush(stdout); Thread.sleep(forTimeInterval: 2)
        let total = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '21,100'")).firstMatch
        XCTAssertTrue(total.exists, "el aporte importado no quedó escrito: el total no subió a $21,100")
        let fila = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1,500'")).firstMatch
        XCTAssertTrue(fila.exists, "el aporte de $1,500 no aparece en el historial")
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
