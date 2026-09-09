import XCTest

/// **Las hojas, una a una, en iPad.** La pasada de septiembre recorrió las
/// pantallas; las 45 `.sheet` de la app se quedaron casi todas sin abrir.
///
/// Cada parada hace tres cosas: fotografía, vuelca los rótulos con su marco, y
/// **avisa de lo que se sale o se parte** —cualquier elemento que cruce el
/// borde de la ventana, y cualquier rótulo que ocupe más de dos renglones—.
/// Eso es lo que hay que mirar en las capturas.
class HojasIPad: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        devolverVentana()
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    /// Ver `RecorridoIPadUITests`: el tamaño de la ventana sobrevive a todo.
    func devolverVentana() {
        guard app.frame.width < 1000 else { return }
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let ctrl = sb.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Window Controls'")).firstMatch
        if ctrl.waitForExistence(timeout: 5) {
            ctrl.tap(); sleep(2)
            if sb.buttons["Zoom"].exists { sb.buttons["Zoom"].tap(); sleep(3) }
        }
    }

    // MARK: - Ayudantes

    func seccion(_ p: String) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
        if !(e.exists && e.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap()
            sleep(1)
        }
        if e.waitForExistence(timeout: 5) { e.tap(); sleep(2) } else { print("  !! no encontré la sección \(p)") }
    }

    /// Toca un botón, **bajando a buscarlo si está bajo el pliegue**: en la
    /// columna de detalle del iPad los botones del corte quedan fuera de
    /// pantalla y `isHittable` dice que no, aunque existan.
    @discardableResult
    func toca(_ etiqueta: String, _ tipo: XCUIElementQuery? = nil) -> Bool {
        let q = tipo ?? app.buttons
        let e = q.matching(NSPredicate(format: "label BEGINSWITH %@", etiqueta)).firstMatch
        guard e.waitForExistence(timeout: 4) else { print("  !! no encontré '\(etiqueta)'"); return false }
        for _ in 0..<4 {
            if e.isHittable { e.tap(); sleep(2); return true }
            // El desplazamiento va por el LADO DERECHO: en el centro cae la
            // columna de la lista y el detalle no se mueve.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.75))
               .press(forDuration: 0.1,
                      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.35)))
            sleep(1)
        }
        print("  !! '\(etiqueta)' existe pero no se puede tocar")
        return false
    }

    @discardableResult
    func tocaTexto(_ t: String) -> Bool {
        let e = app.staticTexts[t].firstMatch
        guard e.waitForExistence(timeout: 4) else { print("  !! no encontré el texto '\(t)'"); return false }
        e.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2); return true
    }

    /// La parada: captura + volcado + avisos.
    func revisar(_ nombre: String) {
        let w = app.frame.width
        var fuera: [String] = [], partidos: [String] = []
        for e in app.staticTexts.allElementsBoundByIndex where !e.label.isEmpty {
            let f = e.frame
            // Solo el desborde HORIZONTAL: lo que queda por debajo del
            // pliegue es normal, para eso se desplaza la hoja.
            if f.maxX > w + 1 || f.minX < -1 { fuera.append("\(e.label)\(f)") }
            if f.height > 46 { partidos.append("\(e.label)[\(Int(f.height))]") }
        }
        for e in app.buttons.allElementsBoundByIndex where !e.label.isEmpty {
            let f = e.frame
            if f.maxX > w + 1 { fuera.append("BOTÓN \(e.label)\(f)") }
        }
        print(">>> \(nombre)")
        if !fuera.isEmpty { print("### ⚠️ SE SALE: \(fuera.joined(separator: " · "))") }
        if !partidos.isEmpty { print("### ⚠️ ALTO: \(partidos.joined(separator: " · "))") }
        print("### TEXTOS: " + app.staticTexts.allElementsBoundByIndex.prefix(40)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        print("### BOTONES: " + app.buttons.allElementsBoundByIndex.prefix(30)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        fflush(stdout)
        print("MARCA:\(nombre)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
    }

    /// Para las hojas del SISTEMA —la de compartir— que aparecen y se
    /// reordenan mientras se leen: solo captura, sin recorrer el árbol, que si
    /// no XCUITest se queda sin el elemento a media lista.
    func revisarSuave(_ nombre: String) {
        sleep(2)
        print(">>> \(nombre) (hoja del sistema)")
        print("MARCA:\(nombre)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0)
    }

    func cerrar() {
        for n in ["Cancel", "Close", "Done", "Cancelar", "Cerrar"] {
            let b = app.buttons[n].firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(2); return }
        }
        // Una hoja de elección se cierra también arrastrándola hacia abajo o
        // tocando fuera; con el `Done` fuera de pantalla, esto es lo que queda.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        sleep(2)
    }
}

/// Tesorería.
final class HojasTesoreria: HojasIPad {

    func testInicioNuevoMovimiento() {
        seccion("Home")
        toca("New")
        revisar("H-01-inicio-nuevo")
        cerrar()
    }

    func testIngresosEditarYRecurrente() {
        seccion("Income")
        tocaTexto("Mission offering")
        toca("Edit")
        revisar("H-02-editar-movimiento")
        cerrar()
    }

    func testAportantesNuevoYEditar() {
        seccion("Contributors")
        toca("New")
        revisar("H-03-nuevo-aportante")
        cerrar()
        tocaTexto("Ana Lucía Torres Beltrán")
        toca("Edit")
        revisar("H-04-editar-aportante")
        cerrar()
    }

    func testAportantesArchivo() {
        seccion("Contributors")
        toca("File") ; sleep(1)
        print("### MENÚ: " + app.buttons.allElementsBoundByIndex.prefix(20).map(\.label).joined(separator: " | "))
        revisar("H-05-menu-archivo")
        // Exportar CSV abre la hoja de compartir del sistema.
        if toca("Givers (CSV)") { revisarSuave("H-06-compartir-csv"); cerrar() }
    }

    func testFichaAportanteDocumentos() {
        seccion("Contributors")
        tocaTexto("Ana Lucía Torres Beltrán")
        if toca("Documents") {
            sleep(1)
            print("### MENÚ: " + app.buttons.allElementsBoundByIndex.prefix(20).map(\.label).joined(separator: " | "))
            revisar("H-07-menu-documentos")
            if toca("Annual") { revisar("H-08-constancia"); cerrar() }
        }
    }

    func testCorteAgregarRegistrarYFirma() {
        seccion("Deposits")
        tocaTexto("Sunday, September 6 service")
        print("### DETALLE: " + app.buttons.allElementsBoundByIndex.prefix(25)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        if toca("Add undeposited") { revisar("H-09-elegir-movimientos"); cerrar() }
        if toca("Mark deposited") { revisar("H-10-registrar-deposito"); cerrar() }
        if toca("Second signature") { revisar("H-11-segunda-firma"); cerrar() }
        if toca("Change period") { revisar("H-15-cambiar-periodo"); cerrar() }
    }

    func testReportesPDF() {
        seccion("Reports")
        tocaTexto("Financial statement")
        if toca("PDF preview") { revisar("H-12-pdf-estado"); cerrar() }
        tocaTexto("Annual report")
        if toca("PDF preview") { revisar("H-13-pdf-anual"); cerrar() }
    }

    func testRevisarEditar() {
        seccion("To review")
        let filas = app.staticTexts.allElementsBoundByIndex.filter { $0.frame.minX < 400 && $0.frame.width > 100 }
        print("### FILAS: \(filas.prefix(6).map(\.label))")
        if let primera = filas.first { primera.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2) }
        if toca("Edit") { revisar("H-14-editar-asunto"); cerrar() }
    }
}

/// Secretaría.
final class HojasSecretaria: HojasIPad {

    func testMembresiaNuevoEditarYSeguimiento() {
        seccion("Membership")
        if toca("More filters") { revisar("H-20-filtros-padron"); cerrar() }
        if toca("New") { revisar("H-21-nuevo-miembro"); cerrar() }
        tocaTexto("María Hernández Ríos")
        if toca("Edit") { revisar("H-22-editar-miembro"); cerrar() }
        if toca("Follow-up") { revisar("H-23-seguimiento"); cerrar() }
    }

    func testFichaMiembroPariente() {
        seccion("Membership")
        tocaTexto("María Hernández Ríos")
        if toca("Add relative") || toca("Agregar pariente") || toca("Add") {
            revisar("H-24-nuevo-pariente"); cerrar()
        } else {
            print("### BOTONES FICHA: " + app.buttons.allElementsBoundByIndex.prefix(25)
                  .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        }
    }

    func testActas() {
        seccion("Minutes")
        if toca("New") { revisar("H-25-nueva-acta"); cerrar() }
        tocaTexto("Ordinary session")
        print("### BOTONES ACTA: " + app.buttons.allElementsBoundByIndex.prefix(25)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        if toca("Signatures") || toca("Firmas") { revisar("H-26-firmas-acta"); cerrar() }
        if toca("PDF") { revisar("H-27-pdf-acta"); cerrar() }
    }

    func testCartas() {
        seccion("Letters")
        sleep(3)
        if toca("New") { revisar("H-28-nueva-carta"); cerrar() }
        print("### BOTONES CARTAS: " + app.buttons.allElementsBoundByIndex.prefix(25)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        if toca("Preview") || toca("Vista previa") { revisar("H-29-previa-carta"); cerrar() }
    }

    func testServicios() {
        seccion("Service log")
        print("### BOTONES SERVICIOS: " + app.buttons.allElementsBoundByIndex.prefix(25)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        if toca("Actions") || toca("Acciones") {
            sleep(1)
            print("### MENÚ: " + app.buttons.allElementsBoundByIndex.prefix(20)
                  .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
            revisar("H-30-menu-servicios")
            for opcion in ["New service", "Assign", "Take attendance", "Count"] {
                if toca(opcion) {
                    revisar("H-31-\(opcion.replacingOccurrences(of: " ", with: "-"))")
                    cerrar()
                    if toca("Actions") { sleep(1) }
                }
            }
        }
    }

    func testAgendaYRegistro() {
        seccion("Calendar")
        if toca("New") { revisar("H-32-nuevo-evento"); cerrar() }
        seccion("Log")
        if toca("Write a note") { revisar("H-33-nueva-nota"); cerrar() }
    }

    func testInformes() {
        seccion("Membership reports")
        // En Informes el filtro es "Period" y las acciones "More".
        if toca("Period") { revisar("H-34-periodo-informes"); cerrar() }
        if toca("More") { sleep(1); revisar("H-35-menu-informes"); app.tap() }
        if toca("Share") { revisarSuave("H-36-compartir-informe"); cerrar() }
        print("### BOTONES INFORMES: " + app.buttons.allElementsBoundByIndex.prefix(25)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
    }
}

/// Ajustes.
final class HojasAjustes: HojasIPad {

    func testZonaDeRiesgo() {
        seccion("Settings")
        if toca("Danger zone") {
            revisar("H-40-zona-riesgo")
            print("### BOTONES ZONA: " + app.buttons.allElementsBoundByIndex.prefix(25)
                  .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
            for b in ["Backup now", "Export transactions", "Export contributors"] {
                if toca(b) {
                    revisarSuave("H-41-\(b.replacingOccurrences(of: " ", with: "-"))")
                    cerrar()
                }
            }
            // "Elegir un archivo…" abre el selector de Archivos del sistema.
            if toca("Choose a file") { revisarSuave("H-41-elegir-archivo"); cerrar() }
        }
    }

    func testIglesiaYLogo() {
        seccion("Settings")
        if toca("Church") {
            revisar("H-42-iglesia")
            print("### BOTONES IGLESIA: " + app.buttons.allElementsBoundByIndex.prefix(25)
                  .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        }
        if toca("Institution") { revisar("H-43-institucion") }
        if toca("Categories") { revisar("H-44-categorias") }
    }
}
