import XCTest

/// **Las placas de icono, que llevaban el símbolo en blanco pasara lo que
/// pasara.**
///
/// Un círculo o un cuadrado de color con un SF Symbol dentro: las filas de los
/// hubs del iPhone, las ocho secciones de Ajustes, las iniciales de la lista de
/// seguimiento de Membresía. El símbolo era `.foregroundStyle(.white)` fijo, y
/// medido contra su propio fondo daba desde 2.16:1 (el cian del sistema) hasta
/// 5.09:1 (el índigo); el mínimo para texto es 4.5:1.
///
/// **Sí afirma el contraste**, y esa es la gracia: lee los píxeles de la
/// placa del propio pantallazo y exige 4.5:1. Nació sin eso —solo comprobaba
/// que las filas existieran— y así una placa rota pasaba tan verde como una
/// arreglada; se comprobó devolviendo los colores a los de antes y la prueba
/// seguía en verde. Con la medida dentro cae donde tiene que caer.
///
/// Deja además las capturas, que es lo que se mira para juzgar el aspecto: el
/// número dice que se lee, no que esté bien.
///
/// El tema llega por `TEST_RUNNER_TEMA` y va en el nombre de cada `MARCA:`: si
/// la variable no llega, la captura lo delata en vez de mentir.
final class PlacasDeIconoUITests: XCTestCase {

    var app: XCUIApplication!
    var tema: String { ProcessInfo.processInfo.environment["TEMA"] ?? "claro" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", tema]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(3)
    }

    func parada(_ n: String) {
        print("MARCA: \(n)-\(tema)"); fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }

    // MARK: - La medida

    /// **El contraste de una placa, leído de los píxeles de la pantalla.**
    ///
    /// Esto es lo que convierte la prueba en una prueba. Sin ello solo afirmaba
    /// que las filas existen, y una placa con el símbolo en blanco sobre cian
    /// —2.43:1— pasaba igual de verde que una arreglada.
    ///
    /// Se recorta el cuadrado de la placa dentro de la fila, se cuentan los
    /// colores y se toman **los dos más frecuentes**: en un círculo liso con un
    /// SF Symbol sólido encima son el relleno y el símbolo. Los intermedios son
    /// el suavizado del borde y salen con cuentas muy bajas, así que no ganan.
    ///
    /// Devuelve `nil` si no puede leer el mapa de bits, y quien llama lo trata
    /// como fallo: un `nil` que se ignora es una prueba que se salta su objeto.
    func contrasteDeLaPlaca(_ fila: XCUIElement) -> (Double, String)? {
        let img = XCUIScreen.main.screenshot().image
        guard let cg = img.cgImage else { return nil }

        // La escala sale de la imagen, no se supone: 3x en el 17e, 2x en otros.
        let escala = CGFloat(cg.width) / XCUIScreen.main.screenshot().image.size.width
        let f = fila.frame
        // La placa va pegada al borde de arranque de la fila: 36 pt de lado.
        let lado: CGFloat = 36
        let centro = CGPoint(x: f.minX + 18, y: f.midY)
        let r = CGRect(x: (centro.x - lado/3) * escala, y: (centro.y - lado/3) * escala,
                       width: (lado * 2/3) * escala, height: (lado * 2/3) * escala)
        guard let recorte = cg.cropping(to: r) else { return nil }

        let an = recorte.width, al = recorte.height
        var bytes = [UInt8](repeating: 0, count: an * al * 4)
        guard let ctx = CGContext(data: &bytes, width: an, height: al,
                                  bitsPerComponent: 8, bytesPerRow: an * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(recorte, in: CGRect(x: 0, y: 0, width: an, height: al))

        var cuenta: [UInt32: Int] = [:]
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let k = UInt32(bytes[i]) << 16 | UInt32(bytes[i+1]) << 8 | UInt32(bytes[i+2])
            cuenta[k, default: 0] += 1
        }
        let top = cuenta.sorted { $0.value > $1.value }.prefix(2)
        guard top.count == 2 else { return nil }

        func luz(_ c: UInt32) -> Double {
            func lineal(_ v: Double) -> Double {
                v <= 0.04045 ? v/12.92 : pow((v + 0.055)/1.055, 2.4)
            }
            let r = Double((c >> 16) & 0xFF)/255, g = Double((c >> 8) & 0xFF)/255
            let b = Double(c & 0xFF)/255
            return 0.2126*lineal(r) + 0.7152*lineal(g) + 0.0722*lineal(b)
        }
        let a = luz(top[0].key), b = luz(top[1].key)
        let ratio = (max(a, b) + 0.05) / (min(a, b) + 0.05)
        let detalle = String(format: "#%06X sobre #%06X", top[1].key, top[0].key)
        return (ratio, detalle)
    }

    /// Mide y exige el mínimo de texto. 4.5:1, que es lo que pide WCAG AA.
    func exigirContraste(_ fila: XCUIElement, _ nombre: String) {
        guard fila.exists else { XCTFail("no está la fila «\(nombre)»"); return }
        guard let (r, detalle) = contrasteDeLaPlaca(fila) else {
            XCTFail("no se pudo leer la placa de «\(nombre)»"); return
        }
        print(String(format: "PLACA %@ · %@ · %.2f:1", nombre, detalle, r)); fflush(stdout)
        XCTAssertGreaterThanOrEqual(r, 4.5,
            String(format: "la placa de «%@» da %.2f:1 (%@); el mínimo es 4.5:1",
                   nombre, r, detalle))
    }

    /// Vuelca lo que hay si la pestaña no aparece: sin eso un "no existe" manda
    /// a buscar el fallo donde no está.
    @discardableResult
    func pestana(_ nombre: String) -> Bool {
        let b = app.tabBars.buttons[nombre]
        guard b.waitForExistence(timeout: 20) else {
            print("PESTAÑAS:" + app.tabBars.buttons.allElementsBoundByIndex
                    .map { $0.label }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está la pestaña «\(nombre)»"); return false
        }
        b.tap(); sleep(3); return true
    }

    func testPlacasDeLosHubs() {
        // Secretaría: Agenda (teal), Actas (morado), Cartas (cian),
        // Registro (pizarra), más las de `Paleta.brand`, `.aviso` y `.enlace`.
        if pestana("Secretary") {
            for fila in ["Agenda", "Minutes", "Letters", "Service log"] {
                let f = app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@", fila)).firstMatch
                if !f.exists { app.swipeUp(velocity: .slow); sleep(1) }
            }
            XCTAssertGreaterThanOrEqual(app.buttons.count, 4,
                                        "el hub de Secretaría salió sin filas")
            parada("hub-secretaria")
            for fila in ["Membership", "Calendar", "Service log", "Minutes", "Letters"] {
                exigirContraste(app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@", fila)).firstMatch, fila)
            }
            app.swipeUp(velocity: .slow); sleep(2)
            parada("hub-secretaria-abajo")
        }

        // Tesorería: Movimientos (esmeralda), Aportantes (teal),
        // Reportes (cielo) y la de `Paleta.aviso`.
        if pestana("Treasury") {
            let mov = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch
            XCTAssertTrue(mov.waitForExistence(timeout: 10),
                          "el hub de Tesorería salió sin «Transactions»")
            parada("hub-tesoreria")
            for fila in ["Transactions", "Contributors", "Deposits", "Reports"] {
                exigirContraste(app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@", fila)).firstMatch, fila)
            }
        }
    }

    func testPlacasDeAjustes() {
        // Las ocho de Ajustes: gris, verde, índigo, cian, azul, naranja,
        // morado y rojo. Es donde estaba el peor de todos (2.16:1).
        guard pestana("Settings") else { return }
        XCTAssertGreaterThanOrEqual(app.buttons.count, 5,
                                    "Ajustes salió sin filas de sección")
        parada("ajustes")
        // La placa de Ajustes es un cuadrado de 32 pt, no un círculo de 36, y
        // la fila arranca igual: el recorte cae dentro de los dos.
        for fila in ["Church", "Institution", "Treasurer", "Access"] {
            exigirContraste(app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", fila)).firstMatch, fila)
        }
        app.swipeUp(velocity: .slow); sleep(2)
        parada("ajustes-abajo")
    }
}
