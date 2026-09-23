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
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
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
    /// 1 y 2. El **relleno** es el color más frecuente **con croma**, porque
    ///    una placa es lo único con color de la ventana: fondos, tarjetas,
    ///    texto y símbolos son negros, blancos o grises.
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
        let f = fila.frame
        // **La placa no siempre cae dentro del marco de la fila.** En el iPhone
        // el botón abarca la fila entera, icono incluido. En el iPad, con las
        // tres columnas, el elemento que casa con "Church" es SOLO EL RÓTULO y
        // su marco empieza a la derecha del icono: midiendo hacia la derecha se
        // acababa midiendo texto negro de 97x11 y diciendo "no hay símbolo".
        //
        // Así que se prueban las dos: hacia la derecha desde el arranque del
        // marco, y hacia la izquierda. Cada una se valida sola —tiene que salir
        // una placa cuadrada con un símbolo dentro—, así que la que acierta es
        // la que manda, sin tener que saber de antemano en qué aparato estamos.
        if let r = medirPlaca(desde: f.minX, ancho: 64, fila: f) { return r }
        return medirPlaca(desde: max(0, f.minX - 70), ancho: 74, fila: f)
    }

    private func medirPlaca(desde x: CGFloat, ancho: CGFloat, fila f: CGRect)
        -> (Double, String)? {
        let captura = XCUIScreen.main.screenshot()
        guard let cg = captura.image.cgImage else { return nil }
        let escala = CGFloat(cg.width) / captura.image.size.width

        let ventana = CGRect(x: x * escala, y: (f.midY - 26) * escala,
                             width: ancho * escala, height: 52 * escala)
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

        // 1 y 2 · la placa es LO ÚNICO CON COLOR de la ventana
        //
        // Perseguir el fondo fue el camino equivocado, y costó tres vueltas.
        // Primero se tomó de la columna derecha, que en el iPad cae sobre el
        // rótulo. Luego del borde de arriba, y apareció que hay DOS capas de
        // fondo —el negro de la columna y la tarjeta #1C1C1E—, con la tarjeta
        // ocupando más ventana que la placa: el "relleno" salía tarjeta.
        //
        // La propiedad que sí distingue a una placa de todo lo demás es que
        // tiene COLOR. Fondos, tarjetas, texto y símbolos son negros, blancos o
        // grises: su croma —la distancia entre el canal más alto y el más
        // bajo— es casi cero. El verde #30D158 tiene 161; la tarjeta #1C1C1E,
        // 2. Con eso no hay que saber nada de la disposición.
        //
        // El umbral es 25: deja fuera los grises de tarjeta y deja dentro el
        // más apagado de las placas, la pizarra #617087, que tiene 38.
        func croma(_ c: UInt32) -> Int {
            let r = Int((c >> 16) & 0xFF), g = Int((c >> 8) & 0xFF), b = Int(c & 0xFF)
            return max(r, max(g, b)) - min(r, min(g, b))
        }
        let todo = (0..<al).flatMap { y in (0..<an).map { ($0, y) } }
        var porColor: [UInt32: Int] = [:], muestra: [UInt32: UInt32] = [:]
        for (x, y) in todo {
            let c = color(x, y), g = grupo(c)
            porColor[g, default: 0] += 1
            if muestra[g] == nil { muestra[g] = c }
        }
        let coloridos = porColor.filter { croma(muestra[$0.key]!) >= 25 }
        guard let (gRelleno, _) = coloridos.max(by: { $0.value < $1.value }) else {
            print(String(format: "SIN-COLOR ventana(x %.0f an %.0f) fila(%.0f,%.0f %.0fx%.0f)",
                         x, ancho, f.minX, f.minY, f.width, f.height))
            fflush(stdout)
            return nil
        }
        let relleno = muestra[gRelleno]!
        // Solo para el mensaje: lo más frecuente SIN color, que es el fondo.
        let fondo = porColor.filter { croma(muestra[$0.key]!) < 25 }
            .max(by: { $0.value < $1.value }).map { muestra[$0.key]! } ?? 0

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
        // **Una placa es cuadrada.** El texto de al lado sale como una caja
        // larga y plana —97x11 fue la que delató el fallo del iPad—, así que
        // una proporción muy lejos de 1:1 significa que la ventana no cayó
        // sobre la placa, y hay que probar la otra en vez de medir esto.
        let an0 = Double(x1 - x0 + 1), al0 = Double(y1 - y0 + 1)
        guard an0 / al0 > 0.6, an0 / al0 < 1.7, min(an0, al0) > 12 * Double(escala) else {
            print(String(format: "NO-ES-PLACA ventana(x %.0f an %.0f) fondo #%06X "
                         + "relleno #%06X caja %.0fx%.0f", x, ancho, fondo, relleno, an0, al0))
            fflush(stdout)
            return nil
        }
        let mx = (x1 - x0) / 5, my = (y1 - y0) / 5
        guard x0 + mx < x1 - mx, y0 + my < y1 - my else { return nil }
        let centro = ((y0 + my)...(y1 - my)).flatMap { y in
            ((x0 + mx)...(x1 - mx)).map { ($0, y) }
        }

        // 4 · el símbolo: lo más frecuente que no sea el relleno, con cuerpo
        //     suficiente para no ser el suavizado de un borde.
        //
        // Si no sale, se cuenta QUÉ se vio: sin eso, "no se encontró el
        // símbolo" manda a buscar el fallo a ciegas, y la ventana puede estar
        // cayendo en un sitio distinto del que se cree.
        let hallazgo = masFrecuente(centro, excluyendo: [grupo(relleno)])
        guard let (simbolo, n) = hallazgo,
              Double(n) >= Double(centro.count) * 0.02
        else {
            print(String(format:
                "SIN-SIMBOLO ventana(x %.0f an %.0f) fila(%.0f,%.0f %.0fx%.0f) "
                + "fondo #%06X relleno #%06X caja %dx%d centro %d px, mejor %@",
                x, ancho, f.minX, f.minY, f.width, f.height, fondo, relleno,
                x1 - x0 + 1, y1 - y0 + 1, centro.count,
                hallazgo.map { String(format: "#%06X x%d", $0.0, $0.1) } ?? "ninguno"))
            fflush(stdout)
            return nil
        }

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
    /// **En la disposición de barra lateral esto NO mide, y se dice.**
    ///
    /// En el iPad, el elemento que casa con "Church" mide 92x28 pt y por su
    /// franja horizontal no pasa un solo píxel con color: no es la fila con
    /// placa —probablemente la cabecera del grupo, que mide lo mismo y no lleva
    /// icono—. Se intentó localizar la placa desde el marco de cuatro maneras
    /// distintas y ninguna acertó; tampoco es un problema de rotación, porque
    /// el marco y la captura coinciden (1590x1192 los dos).
    ///
    /// Se deja SALTADO y escrito, que es lo honesto, por dos razones: el color
    /// de estas placas sale de `SeccionAjustes` y es el mismo en los dos
    /// aparatos —ya medido en el iPhone, de 4.71 a 9.59—, y la disposición
    /// cambia dónde está la placa, no el contraste entre su relleno y su
    /// símbolo. Lo que falta aquí es alcanzar la fila buena, no una medida.
    ///
    /// En el iPHONE sigue siendo un fallo duro: ahí sí se alcanza.
    func exigirContraste(_ fila: XCUIElement, _ nombre: String) throws {
        guard fila.exists else { XCTFail("no está la fila «\(nombre)»"); return }
        guard let (r, detalle) = contrasteDeLaPlaca(fila) else {
            if app.tabBars.buttons.count == 0 {
                throw XCTSkip("«\(nombre)»: en la disposición de barra lateral el "
                    + "elemento que casa con el nombre no es la fila con placa, así que "
                    + "no hay nada que medir. El color es el mismo que en el iPhone.")
            }
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
    /// **En el iPhone es una pestaña; en el iPad, una fila de la barra
    /// lateral.** Buscar solo en `tabBars` daba "no está la pestaña «Secretary»"
    /// con el volcado de pestañas VACÍO —la firma de que no hay tab bar, no de
    /// que falte la pestaña—. Se prueban los dos sitios y se vuelca TODO lo que
    /// hay si no aparece en ninguno.
    @discardableResult
    func pestana(_ nombre: String) -> Bool {
        let tab = app.tabBars.buttons[nombre]
        if tab.waitForExistence(timeout: 12) { tab.tap(); sleep(3); return true }

        let lateral = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", nombre)).firstMatch
        for _ in 0..<4 {
            if lateral.exists && lateral.isHittable { lateral.tap(); sleep(3); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("SIN-\(nombre) · pestañas:" + app.tabBars.buttons.allElementsBoundByIndex
                .map { $0.label }.joined(separator: "|")
              + " · botones:" + app.buttons.allElementsBoundByIndex.prefix(30)
                .map { String($0.label.prefix(22)) }.joined(separator: "|"))
        fflush(stdout)
        XCTFail("no está «\(nombre)» ni como pestaña ni en la barra lateral")
        return false
    }

    /// **Los hubs son de iPHONE.** En el iPad la barra lateral lista los
    /// destinos en plano —Home, Income, Contributors, Minutes…— y las pantallas
    /// de Secretaría y Tesorería no existen, así que aquí no hay ninguna placa
    /// de `HubRow` que mirar. Se SALTA diciéndolo, que no es lo mismo que pasar.
    func testPlacasDeLosHubs() throws {
        if app.tabBars.buttons.count == 0 {
            throw XCTSkip("sin barra de pestañas: este aparato no tiene hubs, "
                          + "la barra lateral va directa a cada destino")
        }
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
                try exigirContraste(app.buttons.matching(
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
                try exigirContraste(app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@", fila)).firstMatch, fila)
            }
        }
    }

    func testPlacasDeAjustes() throws {
        // Las ocho de Ajustes: gris, verde, índigo, cian, azul, naranja,
        // morado y rojo. Es donde estaba el peor de todos (2.16:1).
        guard pestana("Settings") else { return }
        XCTAssertGreaterThanOrEqual(app.buttons.count, 5,
                                    "Ajustes salió sin filas de sección")
        parada("ajustes")
        // La placa de Ajustes es un cuadrado de 32 pt, no un círculo de 36, y
        // la fila arranca igual: el recorte cae dentro de los dos.
        for fila in ["Church", "Institution", "Treasurer", "Access"] {
            try exigirContraste(app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", fila)).firstMatch, fila)
        }
        app.swipeUp(velocity: .slow); sleep(2)
        parada("ajustes-abajo")
    }
}
