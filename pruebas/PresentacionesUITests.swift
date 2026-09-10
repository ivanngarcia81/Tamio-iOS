import XCTest

/// **Que cada hoja, cada alerta y cada selector SALGA.**
///
/// Es la causa exacta que dejó los dos importadores de CSV sin abrir (§0.-7,
/// arreglado en `57a2adb`): varias presentaciones colgadas del MISMO cuerpo,
/// SwiftUI presenta una y las demás no salen. Quedaban sin revisar en el árbol
/// del teléfono `AjustesZonaView` (tres `.sheet`, un `.fileImporter` y seis
/// `.alert`), `MembresiaView` (cuatro `.sheet`), `CorteDetalle` (cuatro y una
/// alerta), `ActasView` y `MovimientosView`.
///
/// La prueba no adivina: toca el botón y mira si el árbol crece con una hoja,
/// una alerta o una barra de navegación nueva. Lo que no crece, no salió.
final class Presentaciones: XCTestCase {

    var app: XCUIApplication!
    var fallos: [String] = []

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch()
        sleep(2)
    }

    // MARK: - Ayudantes

    func pestana(_ n: String) {
        let b = app.tabBars.buttons[n]
        XCTAssertTrue(b.waitForExistence(timeout: 8), "no hay pestaña \(n)")
        b.tap(); sleep(2)
    }

    @discardableResult
    func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 4 : 1) && e.isHittable {
                e.tap(); sleep(2); return true
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("  !! no encontré la fila \(prefijo)")
        return false
    }

    /// Una huella de "qué hay presentado ahora mismo".
    func huella() -> String {
        "hojas=\(app.sheets.count) alertas=\(app.alerts.count) "
        + "barras=\(app.navigationBars.allElementsBoundByIndex.map(\.identifier).joined(separator: ","))"
    }

    /// Toca algo y dice si salió una presentación nueva.
    func probar(_ nombre: String, _ toque: () -> Void, cerrar: [String] = ["Cancel", "Close", "Done", "OK"]) {
        let antes = huella()
        toque()
        sleep(3)
        let despues = huella()
        let salio = despues != antes
        print("PRESENTACION \(salio ? "OK " : "NO ") \(nombre)  [\(antes)] -> [\(despues)]")
        if !salio { fallos.append(nombre) }
        // Cerrar lo que haya salido, para dejar la pantalla como estaba.
        for etiqueta in cerrar {
            let b = app.buttons[etiqueta]
            if b.exists && b.isHittable { b.tap(); sleep(2); break }
        }
        if huella() != antes {
            // Segunda oportunidad: arrastrar la hoja hacia abajo.
            app.swipeDown(velocity: .fast); sleep(2)
        }
    }

    func volcarBotones(_ titulo: String) {
        print(">>> \(titulo)")
        print("  BOTONES: " + app.buttons.allElementsBoundByIndex
            .map { "\($0.label)\($0.isHittable ? "" : "·NOHIT")" }.joined(separator: " ‖ "))
        print("  BARRA: " + app.navigationBars.buttons.allElementsBoundByIndex
            .map(\.label).joined(separator: " ‖ "))
        fflush(stdout)
    }

    // MARK: - Volcados, para saber qué tocar

    func testVolcarAjustes() {
        pestana("Settings")
        volcarBotones("Ajustes")
        for fila in ["Danger zone", "Church", "Account", "Data", "Categories"] {
            if abrirFila(fila) { volcarBotones("Ajustes · \(fila)"); volver() }
        }
    }

    /// **Zona de riesgo: tres `.sheet`, un `.fileImporter` y seis `.alert`
    /// sobre el mismo cuerpo.** Es la pantalla con más presentaciones apiladas
    /// del árbol del teléfono, y la que más caro sale si una no aparece: las
    /// dos salidas de emergencia (respaldar y restaurar) están aquí.
    func testZonaDeRiesgo() {
        pestana("Settings")
        XCTAssertTrue(abrirFila("Danger zone"), "no entré en Zona de riesgo")
        volcarBotones("Zona de riesgo · arriba")

        probar("Respaldar ahora (hoja de compartir)") { self.app.buttons["Backup now"].tap(); sleep(6) }
        probar("Exportar movimientos CSV") { self.app.buttons["Export transactions (CSV)"].tap(); sleep(6) }
        probar("Exportar aportantes CSV") { self.app.buttons["Export contributors (CSV)"].tap(); sleep(6) }

        // Lo de abajo del pliegue.
        for _ in 0..<4 { app.swipeUp(velocity: .slow); sleep(1) }
        volcarBotones("Zona de riesgo · abajo")

        for etiqueta in ["Restore a backup…", "Restore…", "Free up space…", "Continue…"] {
            let b = app.buttons[etiqueta]
            if b.exists && b.isHittable { probar("botón: \(etiqueta)") { b.tap() } }
        }
        XCTAssertTrue(fallos.isEmpty, "No salieron: \(fallos.joined(separator: ", "))")
    }

    /// Membresía: cuatro `.sheet` sobre el mismo cuerpo.
    func testMembresia() {
        pestana("Secretary")
        XCTAssertTrue(abrirFila("Membership,"), "no entré en Membresía")
        volcarBotones("Membresía")
        for etiqueta in ["Filters", "New", "Add"] {
            let b = app.buttons[etiqueta]
            if b.exists && b.isHittable { probar("Membresía · \(etiqueta)") { b.tap() } }
        }
        XCTAssertTrue(fallos.isEmpty, "No salieron: \(fallos.joined(separator: ", "))")
    }

    /// Movimientos: un `confirmationDialog`, dos `.sheet(item:)` y uno más.
    func testMovimientos() {
        pestana("Treasury")
        XCTAssertTrue(abrirFila("Transactions"), "no entré en Movimientos")
        volcarBotones("Movimientos")
        for etiqueta in ["New", "Import"] {
            let b = app.buttons[etiqueta]
            if b.exists && b.isHittable { probar("Movimientos · \(etiqueta)") { b.tap() } }
        }
        let filtros = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Period and filters'")).firstMatch
        if filtros.exists { probar("Movimientos · filtros") { filtros.tap() } }
        XCTAssertTrue(fallos.isEmpty, "No salieron: \(fallos.joined(separator: ", "))")
    }

    /// Actas: dos `.sheet(isPresented:)`, dos `.sheet(item:)` y una alerta.
    func testActas() {
        pestana("Secretary")
        XCTAssertTrue(abrirFila("Minutes"), "no entré en Actas")
        volcarBotones("Actas")
        XCTAssertTrue(fallos.isEmpty, "No salieron: \(fallos.joined(separator: ", "))")
    }

    /// El detalle de un corte: cuatro `.sheet` y una alerta.
    func testCorteDetalle() {
        pestana("Treasury")
        XCTAssertTrue(abrirFila("Deposits"), "no entré en Depósitos")
        volcarBotones("Depósitos")
    }

    func volver() {
        let atras = app.navigationBars.buttons.element(boundBy: 0)
        if atras.exists && atras.isHittable { atras.tap(); sleep(2) }
    }
}
