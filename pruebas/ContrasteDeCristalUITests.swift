import XCTest

/// **Las dos piezas de esta pasada que hay que MEDIR, no solo mirar.**
///
/// - **H6 · el botón de conteo de asistencia** (`ServiciosView.botonConteo`).
///   Era un círculo `Paleta.brand` con el símbolo en blanco y una sombra del
///   propio verde haciendo de halo. Pasa a `.glassProminent` + `.circle`. El
///   requisito es explícito: **que el contraste del símbolo no quede peor que
///   hoy**, así que hay que medirlo con el arreglo y sin él.
///
/// - **H4 · el aviso de deshacer** (`RevisarView.toastView`). Era
///   `.thickMaterial` + filete + sombra; pasa a `.glassEffect(.regular, in:
///   .capsule)`. El texto se queda en `.primary` y hay que verlo **en claro y
///   en oscuro**, que es donde un aviso flotante se pierde.
///
/// No afirma umbrales: navega, deja el elemento en pantalla y se para en una
/// `MARCA:` para que el shell capture. El número lo pone `contraste.py`.
final class ContrasteDeCristalUITests: XCTestCase {

    var app: XCUIApplication!

    func arrancar(tema: String) {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", tema]
        // La maqueta y no la iglesia sincronizada: lo que busca es de la
        // semilla, y lo que escribe se queda en memoria (ver `docs/ROJAS-SEPTIEMBRE.md`).
        app.launchArguments += ["-modoRevision", "YES", "-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.5) }

    /// Toca una fila por prefijo, desplazando si hace falta, y vuelca lo que hay
    /// si no aparece. Sin esto, un "no existe" manda a buscar el fallo donde no
    /// está: pasó cuatro veces el 16-sep.
    @discardableResult
    func tocarFila(_ prefijo: String) -> Bool {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefijo)).firstMatch
        for _ in 0..<6 {
            if e.exists && e.isHittable { e.tap(); sleep(3); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("NO-ESTA \(prefijo) · hay:" + app.buttons.allElementsBoundByIndex.prefix(30)
                .map { String($0.label.prefix(24)) }.joined(separator: "|"))
        fflush(stdout)
        XCTFail("no está «\(prefijo)»")
        return false
    }

    // MARK: - H6 · el botón de conteo

    /// **Va por el iPad, y no es un capricho.** `servicioActivo` es
    /// `compacto ? abierto : vm.seleccion`: en el TELÉFONO hay que abrir el
    /// culto, y abrirlo te lleva a la ficha, así que el menú de la lista —donde
    /// vive "Contar"— deja de estar delante. En el iPad basta con seleccionar
    /// la fila: la columna y su menú siguen a la vista.
    ///
    /// Por eso el primer intento fallaba y, peor, **salía en verde**: tocaba un
    /// "Contar" apagado, no pasaba nada, y la prueba terminaba contenta. De ahí
    /// el `isEnabled` y la comprobación de que la hoja está delante.
    func testH6BotonDeConteo() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad: barra lateral y apaisado")
        XCUIDevice.shared.orientation = .landscapeLeft
        arrancar(tema: "oscuro")

        guard tocarFila("Service log") else { return }

        // Seleccionar un culto de la columna. Sin esto las tres acciones del
        // menú se apagan a propósito.
        let culto = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Sun' OR label CONTAINS 'Prayer' OR label CONTAINS 'service'"))
            .firstMatch
        if culto.waitForExistence(timeout: 8) {
            culto.tap(); sleep(2)
        } else {
            print("COLUMNA:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(24)) }.joined(separator: "|"))
            fflush(stdout)
        }

        let acciones = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Actions' OR label CONTAINS 'Acciones'")).firstMatch
        guard acciones.waitForExistence(timeout: 8) else {
            print("BARRA:" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está el menú de acciones"); return
        }
        acciones.tap(); sleep(1)

        let contar = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Count' OR label BEGINSWITH 'Contar'")).firstMatch
        guard contar.waitForExistence(timeout: 6) else {
            print("MENU:" + app.buttons.allElementsBoundByIndex.prefix(20)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Count» en el menú"); return
        }
        XCTAssertTrue(contar.isEnabled,
                      "«Count» está apagado: no quedó ningún culto seleccionado")
        contar.tap(); sleep(3)

        // Que la hoja esté DELANTE de verdad, no solo que el menú se cerrara.
        let masMenos = app.buttons.matching(
            NSPredicate(format: "identifier == 'plus' OR identifier == 'minus' OR label CONTAINS 'plus' OR label CONTAINS 'minus'"))
            .firstMatch
        if !masMenos.waitForExistence(timeout: 8) {
            print("HOJA:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { "\($0.label.prefix(18))/\($0.identifier.prefix(12))" }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("la hoja de conteo no llegó a abrirse")
            return
        }
        parada("H6-conteo-oscuro")
    }

    // MARK: - H4 · el aviso de deshacer

    func testH4ToastOscuro() { toast(tema: "oscuro") }
    func testH4ToastClaro()  { toast(tema: "claro") }

    func toast(tema: String) {
        arrancar(tema: tema)
        XCTAssertTrue(app.tabBars.buttons["To review"].waitForExistence(timeout: 20))
        app.tabBars.buttons["To review"].tap(); sleep(3)

        // El toast sale al resolver un asunto. Se toma el primer botón de acción
        // de la primera tarjeta; cuál sea da igual, lo que se mide es el aviso.
        let antes = app.buttons.allElementsBoundByIndex.map(\.label)
        print("REVISAR:" + antes.prefix(20).map { String($0.prefix(20)) }.joined(separator: "|"))
        fflush(stdout)

        // Los botones reales de esta pantalla, que los dijo el volcado:
        // "Approve", "Attach and approve", "Return to treasurer", "Link giver".
        // Se compara el rótulo ENTERO: "Approve" a secas choca con el
        // "Approve 1 of 13" del encabezado, que no es una acción.
        let accion = app.buttons.matching(NSPredicate(
            format: "label == 'Return to treasurer' OR label == 'Devolver al tesorero'"))
            .firstMatch
        guard accion.waitForExistence(timeout: 8) else {
            XCTFail("no hay ninguna acción que dispare el aviso"); return
        }
        accion.tap()
        // El aviso se va solo a los 4,5 s: hay que capturarlo antes.
        sleep(1)
        parada("H4-toast-\(tema)")
    }
}
