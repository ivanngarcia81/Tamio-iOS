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
    /// **La primera versión medía otra cosa y pasaba igual.** Recortaba un
    /// cuadrado suponiendo que la placa estaba a 18 pt del arranque de la fila,
    /// y se quedaba con los dos colores más frecuentes. En el iPhone físico esa
    /// suposición no se cumple: el recorte caía sobre la TARJETA, y las trece
    /// medidas salieron "relleno sobre #1C1C1E" —el fondo—, no "relleno sobre
    /// símbolo". Daban de 4.54 a 9.67 y la prueba pasaba tan contenta.
    ///
    /// Lo peor es que la comprobación en rojo también pasó, y por casualidad:
    /// en CLARO la tarjeta es blanca y el símbolo también, así que las dos
    /// lecturas coinciden y el error no asoma. Solo se separó en el aparato,
    /// en oscuro. De ahí la regla: **una medida que solo se ha visto en una
    /// apariencia no está comprobada.**
    ///
    /// Ahora no se supone nada de la geometría. Se busca la placa:
    ///
    /// 1. El **fondo** se lee de la columna derecha de la ventana, a 64 pt del
    ///    arranque de la fila, donde no llega ninguna placa (la mayor mide 36).
    /// 2. El **relleno** es el color más frecuente que no es el fondo.
    /// 3. La **caja** de la placa es el recuadro de los píxeles del relleno, y
    ///    de ella se toma el **60 % central**, que en un círculo cae entero
    ///    dentro. Ahí no hay tarjeta: lo que no es relleno es símbolo.
    /// 4. El **símbolo** es lo más frecuente de ese centro que no es el
    ///    relleno. Si no llega al 2 %, no se ha encontrado y se devuelve
    ///    `nil`: eso es un fallo, no un aprobado.
    ///
    /// El paso 3 es el que cierra el agujero, y por sitio y no por color. La
    /// primera corrección excluía el fondo por su COLOR, y eso volvía a
    /// romperse en claro —tarjeta blanca y símbolo blanco son el mismo color—.
    func contrasteDeLaPlaca(_ fila: XCUIElement) -> (Double, String)? {
        let captura = XCUIScreen.main.screenshot()
        guard let cg = captura.image.cgImage else { return nil }
        let escala = CGFloat(cg.width) / captura.image.size.width

        let f = fila.frame
        let ventana = CGRect(x: f.minX * escala, y: (f.midY - 26) * escala,
                             width: 64 * escala, height: 52 * escala)
        guard ventana.maxX <= CGFloat(cg.width), ventana.maxY <= CGFloat(cg.height),
              let recorte = cg.cropping(to: ventana) else { return nil }

        let an = recorte.width, al = recorte.height
        var bytes = [UInt8](repeating: 0, count: an * al * 4)
        guard let ctx = CGContext(data: &bytes, width: an, height: al,
                                  bitsPerComponent: 8, bytesPerRow: an * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(recorte, in: CGRect(x: 0, y: 0, width: an, height: al))

        func color(_ x: Int, _ y: Int) -> UInt32 {
            let i = (y * an + x) * 4
            return UInt32(bytes[i]) << 16 | UInt32(bytes[i+1]) << 8 | UInt32(bytes[i+2])
        }
        // Se agrupa por tono aproximado —cinco bits por canal— para que el
        // suavizado del borde no cuente como un color distinto cada vez.
        func grupo(_ c: UInt32) -> UInt32 {
            ((c >> 19) & 0x1F) << 10 | ((c >> 11) & 0x1F) << 5 | ((c >> 3) & 0x1F)
        }
        func masFrecuente(_ px: [(Int, Int)], excluyendo: Set<UInt32>) -> (UInt32, Int)? {
            var cuenta: [UInt32: Int] = [:], muestra: [UInt32: UInt32] = [:]
            for (x, y) in px {
                let c = color(x, y), g = grupo(c)
                if excluyendo.contains(g) { continue }
                cuenta[g, default: 0] += 1
                if muestra[g] == nil { muestra[g] = c }
            }
            guard let (g, n) = cuenta.max(by: { $0.value < $1.value }) else { return nil }
            return (muestra[g]!, n)
        }

        // 1 · el fondo, en la columna de más a la derecha
        let columna = (0..<al).map { (an - 1, $0) }
        guard let (fondo, _) = masFrecuente(columna, excluyendo: []) else { return nil }

        // 2 · el relleno de la placa
        let todo = (0..<al).flatMap { y in (0..<an).map { ($0, y) } }
        guard let (relleno, _) = masFrecuente(todo, excluyendo: [grupo(fondo)]) else { return nil }

        // 3 · la caja de la placa, y su parte CENTRAL
        //
        // **La distinción que importa no es de color, es de sitio: dentro o
        // fuera de la placa.** Excluir el fondo por su color funcionaba en
        // oscuro y fallaba en claro, donde la tarjeta es blanca y el símbolo
        // también: al quitar el fondo se quitaba el símbolo, y no quedaba nada
        // que medir. Es el mismo espejismo que escondió el fallo anterior,
        // visto por el otro lado.
        //
        // Así que se recorta al 60 % central del recuadro. En un círculo eso
        // cae entero dentro —la media diagonal, 0.42 del diámetro, es menor
        // que el radio— y en un cuadrado redondeado, con más razón. Ahí no hay
        // un solo píxel de tarjeta, y el símbolo se puede buscar por ser lo
        // único que no es el relleno.
        var x0 = an, x1 = -1, y0 = al, y1 = -1
        for (x, y) in todo where grupo(color(x, y)) == grupo(relleno) {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        }
        guard x1 > x0, y1 > y0 else { return nil }
        let mx = (x1 - x0) / 5, my = (y1 - y0) / 5
        guard x0 + mx < x1 - mx, y0 + my < y1 - my else { return nil }
        let centro = ((y0 + my)...(y1 - my)).flatMap { y in
            ((x0 + mx)...(x1 - mx)).map { ($0, y) }
        }

        // 4 · el símbolo: lo más frecuente que no sea el relleno, con cuerpo
        //     suficiente para no ser el suavizado de un borde.
        guard let (simbolo, n) = masFrecuente(centro, excluyendo: [grupo(relleno)]),
              Double(n) >= Double(centro.count) * 0.02
        else { return nil }

        func luz(_ c: UInt32) -> Double {
            func lineal(_ v: Double) -> Double {
                v <= 0.04045 ? v/12.92 : pow((v + 0.055)/1.055, 2.4)
            }
            let r = Double((c >> 16) & 0xFF)/255, g = Double((c >> 8) & 0xFF)/255
            let b = Double(c & 0xFF)/255
            return 0.2126*lineal(r) + 0.7152*lineal(g) + 0.0722*lineal(b)
        }
        let a = luz(relleno), b = luz(simbolo)
        let ratio = (max(a, b) + 0.05) / (min(a, b) + 0.05)
        return (ratio, String(format: "#%06X sobre #%06X (fondo #%06X)",
                              simbolo, relleno, fondo))
    }

    /// Mide y exige el mínimo de texto. 4.5:1, que es lo que pide WCAG AA.
    func exigirContraste(_ fila: XCUIElement, _ nombre: String) {
        guard fila.exists else { XCTFail("no está la fila «\(nombre)»"); return }
        guard let (r, detalle) = contrasteDeLaPlaca(fila) else {
            XCTFail("no se encontró el símbolo dentro de la placa de «\(nombre)» "
                    + "—o la ventana no cayó sobre la placa—; sin eso no hay nada que medir")
            return
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
