import XCTest

/// **El recorrido de la revisión visual del 8 de septiembre.** No afirma nada:
/// navega, imprime lo que hay en pantalla y se PARA en cada parada para que el
/// shell dispare `xcrun simctl io <udid> screenshot`. Es la receta del §3 de
/// `docs/CONTEXTO.md` con las paradas ya escritas, para no volver a escribirlas.
///
/// **Cómo se corre** (con el modo revisión ENCENDIDO en la copia, §2.2):
///
///     xcodebuild ... -only-testing:TamioUITests/RecorridoInterfaz/testMovimientos \
///                 test-without-building 2>&1 | while read l; do
///       case "$l" in *MARCA:*) sleep 1.2
///         xcrun simctl io <udid> screenshot "${l##*MARCA:}.png";; esac
///     done
///
/// Para repetirlo en oscuro o con el texto grande, sin tocar el código:
///
///     xcrun simctl ui <udid> appearance dark
///     xcrun simctl ui <udid> content_size accessibility-medium
///
/// **Tres cosas que cuestan una vuelta si no se saben**, y que son la razón de
/// que los ayudantes de abajo sean como son:
///
/// 1. **Las filas de una `List` no son botones**: son celdas con la etiqueta
///    VACÍA, así que no se localizan por texto. Se tocan por su `staticText`.
/// 2. **La primera celda es la cabecera de sección.** `cells.element(boundBy: 0)`
///    toca el rótulo del grupo, no la primera fila, y la pantalla no cambia.
/// 3. **Las filas de un hub bajo el pliegue no están en el árbol** hasta que se
///    desplaza. Sin bajar buscando, `abrirFila` da un "no existe" que es
///    mentira: así se dieron por recorridas cinco pantallas de Secretaría que
///    no se habían abierto.
final class RecorridoInterfaz: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // El idioma de la INTERFAZ lo manda `prefs.idioma` (§5); `AppleLanguages`
        // mueve el del aparato, que es lo que decide los diálogos del sistema.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch()
        sleep(2)
    }

    // MARK: - Ayudantes

    /// Imprime la marca y se duerme lo justo para que el shell fotografíe.
    func parada(_ nombre: String) {
        print("MARCA:\(nombre)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.2)
    }

    /// El inventario de la pantalla: marco, estado y tocabilidad de cada cosa.
    /// El marco importa —así se distingue la pestaña "Por revisar" del aviso del
    /// Dashboard, que se llaman igual— y `isEnabled` es lo único que demuestra
    /// que un botón está apagado (§2.3: compilar no es verificar).
    func volcado(_ titulo: String) {
        print(">>> \(titulo)")
        print("  BARRA: \(describir(app.navigationBars.buttons))")
        print("  BOTONES: \(describir(app.buttons))")
        print("  TEXTOS: \(describir(app.staticTexts))")
        fflush(stdout)
    }

    private func describir(_ q: XCUIElementQuery) -> String {
        q.allElementsBoundByIndex.map {
            "\($0.label)[\(Int($0.frame.minX)),\(Int($0.frame.minY)) "
            + "\(Int($0.frame.width))x\(Int($0.frame.height))]"
            + ($0.isEnabled ? "" : "·OFF") + ($0.isHittable ? "" : "·NOHIT")
        }.joined(separator: " ‖ ")
    }

    func pestana(_ nombre: String) {
        let b = app.tabBars.buttons[nombre]
        if b.exists { b.tap(); sleep(2) } else { print("  !! no existe la pestaña \(nombre)") }
    }

    /// Abre una fila de hub por el principio de su etiqueta de accesibilidad
    /// —que es `"Transactions, 28 records · 19 undeposited"`, no el título—,
    /// **bajando a buscarla** si no está todavía en el árbol.
    @discardableResult
    func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<5 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 4 : 1) && e.isHittable {
                e.tap(); sleep(2); return true
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("  !! no encontré la fila \(prefijo)")
        return false
    }

    /// Abre una fila de lista tocando su texto por coordenada: ver el punto 1
    /// de la cabecera de esta clase.
    @discardableResult
    func tocarTexto(_ t: String) -> Bool {
        let e = app.staticTexts[t]
        guard e.waitForExistence(timeout: 5) else { print("  !! no encontré el texto \(t)"); return false }
        e.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        sleep(2)
        return true
    }

    func bajar(_ veces: Int, _ base: String) {
        for i in 1...veces { app.swipeUp(velocity: .slow); sleep(1); parada("\(base)-\(i)") }
    }

    // MARK: - Panorama: diez pantallas, para repetir en oscuro y en AX1

    func testPanorama() {
        pestana("Home");      parada("p1-inicio")
        pestana("Treasury");  parada("p2-hub-tesoreria")
        if abrirFila("Transactions") { parada("p3-movimientos"); volver() }
        if abrirFila("Deposits")     { parada("p4-depositos");   volver() }
        pestana("To review"); parada("p5-revisar")
        pestana("Secretary"); parada("p6-hub-secretaria")
        if abrirFila("Membership,")  { parada("p7-membresia"); volver() }
        if abrirFila("Calendar")     { parada("p8-agenda");    volver() }
        if abrirFila("Log,")         { parada("p9-registro");  volver() }
        pestana("Settings");  parada("p10-ajustes")
    }

    func volver() {
        let atras = app.navigationBars.buttons.element(boundBy: 0)
        if atras.exists && atras.isHittable { atras.tap(); sleep(2) }
    }

    // MARK: - Tesorería

    func testHubTesoreria() {
        pestana("Treasury")
        volcado("hub Tesorería")
        for fila in ["Transactions", "Contributors", "Deposits", "Reports"] {
            guard abrirFila(fila) else { continue }
            volcado(fila)
            parada("10-\(fila)")
            bajar(1, "10-\(fila)")
            volver()
        }
    }

    func testDetalleMovimiento() {
        pestana("Treasury"); abrirFila("Transactions")
        guard tocarTexto("Mission offering") else { return }
        volcado("detalle de movimiento"); parada("11-detalle"); bajar(2, "11-detalle")
    }

    func testFiltrosDeMovimientos() {
        pestana("Treasury"); abrirFila("Transactions")
        let filtros = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Period and filters'")).firstMatch
        XCTAssertTrue(filtros.waitForExistence(timeout: 5))
        filtros.tap(); sleep(2)
        volcado("hoja de filtros"); parada("11-filtros"); bajar(3, "11-filtros")
    }

    func testNuevoMovimiento() {
        pestana("Treasury"); abrirFila("Transactions")
        XCTAssertTrue(app.buttons["New"].waitForExistence(timeout: 5))
        app.buttons["New"].tap(); sleep(2)
        volcado("nuevo movimiento"); parada("11-nuevo"); bajar(2, "11-nuevo")
    }

    func testEstadoFinanciero() {
        pestana("Treasury"); abrirFila("Reports")
        guard tocarTexto("Financial statement") else { return }
        volcado("estado financiero"); parada("13-estado"); bajar(4, "13-estado")
    }

    func testInformeAnual() {
        pestana("Treasury"); abrirFila("Reports")
        guard tocarTexto("Annual report") else { return }
        volcado("informe anual"); parada("13-anual"); bajar(3, "13-anual")
    }

    func testBandejaRevisar() {
        pestana("To review")
        volcado("bandeja"); parada("14-bandeja"); bajar(3, "14-bandeja")
    }

    // MARK: - Secretaría

    func testMembresia() {
        pestana("Secretary"); abrirFila("Membership,")
        volcado("membresía"); parada("20-membresia"); bajar(2, "20-membresia")
    }

    func testFichaDeMiembro() {
        pestana("Secretary"); abrirFila("Membership,")
        guard tocarTexto("María Hernández Ríos") else { return }
        volcado("ficha de miembro"); parada("21-miembro"); bajar(3, "21-miembro")
    }

    func testInformesDeMembresia() {
        pestana("Secretary"); abrirFila("Membership reports")
        volcado("informes"); parada("22-informes"); bajar(3, "22-informes")
    }

    func testAgenda() {
        pestana("Secretary"); abrirFila("Calendar")
        volcado("agenda · mes"); parada("23-agenda")
        for vista in ["Week", "List"] where app.buttons[vista].exists {
            app.buttons[vista].tap(); sleep(2)
            volcado("agenda · \(vista)"); parada("23-agenda-\(vista)")
        }
    }

    func testServicios() {
        pestana("Secretary"); abrirFila("Service log")
        volcado("bitácora"); parada("24-servicios"); bajar(2, "24-servicios")
    }

    func testActas() {
        pestana("Secretary"); abrirFila("Minutes,")
        volcado("actas"); parada("25-actas"); bajar(2, "25-actas")
    }

    /// **Ojo con la foto prematura aquí.** La sección "Templates" tarda unos
    /// segundos en llenarse: a los dos parece una sección vacía bajo su
    /// cabecera y a los cinco tiene las dieciséis plantillas. No es un bug.
    func testCartas() {
        pestana("Secretary"); abrirFila("Letters & transfers")
        sleep(4)
        volcado("cartas"); parada("26-cartas"); bajar(2, "26-cartas")
    }

    func testRegistro() {
        pestana("Secretary"); abrirFila("Log,")
        volcado("registro"); parada("27-registro"); bajar(2, "27-registro")
    }

    // MARK: - Ajustes

    func testAjustes() {
        pestana("Settings")
        volcado("ajustes"); parada("30-ajustes"); bajar(4, "30-ajustes")
    }

    func testSeccionesDeAjustes() {
        for fila in ["Church,", "Institution", "Treasurer & pastor",
                     "Access & areas", "Categories", "Preferences"] {
            pestana("Settings")
            guard abrirFila(fila) else { continue }
            let nombre = fila.replacingOccurrences(of: " ", with: "-")
                             .replacingOccurrences(of: ",", with: "")
            volcado(fila); parada("31-\(nombre)"); bajar(1, "31-\(nombre)")
            volver()
        }
    }
}
