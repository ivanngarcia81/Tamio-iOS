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

    func testH6BotonDeConteo() {
        arrancar(tema: "oscuro")
        XCTAssertTrue(app.tabBars.buttons["Secretary"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        guard tocarFila("Service log") else { return }

        // **Primero se elige un culto.** Las tres acciones del menú —Tomar
        // lista, Contar, Asignar— se apagan a propósito cuando no hay ninguno
        // delante, así que sin esto el menú se abre en gris y la hoja no llega
        // a salir. Lo enseñó la captura del primer intento.
        let culto = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Sun' OR label CONTAINS 'Prayer'")).firstMatch
        if culto.waitForExistence(timeout: 8) { culto.tap(); sleep(2) }

        // Las acciones viven en una sola cápsula de la barra.
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
        // **Que esté no basta: tiene que poder tocarse.** Tocar un elemento
        // deshabilitado NO da error en XCUITest, así que la prueba salía en
        // VERDE sin llegar a la hoja: el menú seguía en gris y la captura era
        // del menú. Segundo caso el mismo día de una prueba que pasa sin
        // verificar; por eso ahora se afirma la habilitación y, después, que la
        // hoja está de verdad delante.
        XCTAssertTrue(contar.isEnabled,
                      "«Count» está apagado: falta elegir un culto antes de abrir el menú")
        contar.tap(); sleep(3)

        let hoja = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'minus' OR label CONTAINS 'plus' OR label CONTAINS 'Save' OR label CONTAINS 'Guardar'")).firstMatch
        if !hoja.waitForExistence(timeout: 8) {
            print("HOJA:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(22)) }.joined(separator: "|"))
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
