import XCTest

/// **La NOVENA presentación de Z2, la que no tenía camino.**
///
/// `PresentacionesAparatoUITests` ejercitó ocho de las nueve. La que faltaba es
/// la hoja de segunda firma (`CorteDetalle:85`), y no por un defecto: su botón
/// (`CorteDetalle:433` y `:439`) solo se pinta si el corte **pidió** doble firma
/// y **todavía no la tiene**, y en el servidor no existía ningún corte así. Los
/// que la pedían ya estaban firmados y los que no, no la pedían.
///
/// **La solución no es sembrar en la base de la iglesia, es usar la app.** El
/// interruptor «Que otra persona cuente este dinero» está en esa misma pantalla
/// (`CorteDetalle:407`) y enciende `dobleFirmaPedida` sobre un corte sin
/// depositar. O sea que el estado que falta se puede crear por el camino del
/// usuario y deshacer por el mismo sitio — que es mejor prueba que un `insert`,
/// porque además ejercita el interruptor.
///
/// **Esto ESCRIBE en la base de la iglesia**, y por eso el apagado va en
/// `tearDown` y no al final del test: si una comprobación falla a mitad, el
/// corte se quedaría pidiendo una firma que nadie pidió. Se apaga pase lo que
/// pase.
///
/// **Y si no hay corte sin depositar, esto se SALTA, no pasa.** Un verde que
/// midió cero es la trampa que ya costó una corrida en esta casa
/// (`FechaSoloFechaTests`, el "5 sin ningún 6"): aquí se dice en voz alta con
/// `XCTSkip`.
final class SegundaFirmaUITests: XCTestCase {

    var app: XCUIApplication!
    /// Para el `tearDown`: solo hay que apagar si esta prueba lo encendió.
    private var loEncendiYo = false

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        sleep(3)
    }

    override func tearDown() {
        guard loEncendiYo else { return }
        if let t = interruptor(), t.isHittable {
            t.tap(); sleep(2)
            print("QA-FIRMA: interruptor devuelto a su sitio")
        } else {
            print("QA-FIRMA: ### NO pude apagar el interruptor — revisar el corte a mano")
        }
        loEncendiYo = false
    }

    // MARK: - Utillaje, el mismo de `CortesYDepositosUITests`

    private func describir(_ q: XCUIElementQuery) -> String {
        q.allElementsBoundByIndex.prefix(40).map {
            "\($0.label)[\(Int($0.frame.minY))]"
            + ($0.isEnabled ? "" : "·OFF") + ($0.isHittable ? "" : "·NOHIT")
        }.joined(separator: " ‖ ")
    }

    private func volcado(_ titulo: String) {
        print(">>> \(titulo)")
        print("  BARRA: \(describir(app.navigationBars.buttons))")
        print("  BOTONES: \(describir(app.buttons))")
        print("  INTERRUPTORES: \(describir(app.switches))")
        print("  TEXTOS: \(describir(app.staticTexts))")
        fflush(stdout)
    }

    @discardableResult
    private func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<5 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 5 : 1) && e.isHittable {
                e.tap(); sleep(3); return true
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return false
    }

    /// ¿Estamos en la pantalla de acceso? Sin sesión no hay ni pestañas ni
    /// sidebar, y **el primer intento de esta prueba imprimió `QA-FORMA:ipad`
    /// corriendo en un simulador de iPHONE** — porque «no encuentro la barra de
    /// pestañas» se había escrito como «luego es un iPad». Dos causas distintas
    /// con la misma huella, que es exactamente cómo se lee mal una corrida.
    private var enPantallaDeAcceso: Bool {
        app.secureTextFields.firstMatch.exists
            || app.buttons.matching(
                NSPredicate(format: "label IN {'Sign in','Log in','Entrar','Iniciar sesión'}")
               ).firstMatch.exists
    }

    /// iPhone y iPad no navegan igual. Ver el comentario de
    /// `CortesYDepositosUITests.irADepositos`.
    private func irADepositos() throws -> Bool {
        if enPantallaDeAcceso {
            throw XCTSkip("el aparato NO tiene sesión: esta prueba necesita datos de verdad")
        }
        let pestana = app.tabBars.buttons["Treasury"]
        if pestana.waitForExistence(timeout: 6) {
            print("QA-FORMA:telefono")
            pestana.tap(); sleep(2)
            return abrirFila("Deposits")
        }
        // Solo ahora se puede afirmar la forma: hay sesión y no hay pestañas.
        let fila = app.buttons["Deposits"]
        if fila.waitForExistence(timeout: 6) {
            print("QA-FORMA:ipad")
            if fila.isHittable { fila.tap(); sleep(3); return true }
        }
        print("QA-FORMA:desconocida — ni pestañas ni sidebar, y hay sesión")
        return abrirFila("Deposits")
    }

    /// El interruptor de doble firma, que en SwiftUI sale como `switch` pero
    /// cuya etiqueta es el VStack entero. Se busca por trozo, no por igualdad.
    private func interruptor() -> XCUIElement? {
        let p = NSPredicate(format: "label CONTAINS[c] %@", "count this money")
        for q in [app.switches, app.buttons] {
            let e = q.matching(p).firstMatch
            if e.exists { return e }
        }
        return nil
    }

    private var botonFirma: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@",
                                         "Second signature")).firstMatch
    }

    // MARK: - La prueba

    func testLaHojaDeSegundaFirmaSeAbreSeCancelaYSeReabre() throws {
        // **`guard` y no `XCTSkipUnless`**: el segundo envuelve el salto de
        // dentro y se queda con SU mensaje, así que «no hay sesión» salía
        // rotulado «no se pudo llegar a Depósitos». Un motivo de salto que
        // miente es tan caro como un verde que no mide.
        guard try irADepositos() else {
            throw XCTSkip("hay sesión, pero no se pudo llegar a Depósitos")
        }

        let celdas = app.cells.allElementsBoundByIndex.filter(\.isHittable)
        // La 0 suele ser la cabecera de sección.
        guard let primera = celdas.dropFirst().first else {
            throw XCTSkip("no hay cortes en este aparato: nada que abrir")
        }
        primera.tap(); sleep(3)
        volcado("corte abierto")

        // **El interruptor solo existe si el corte está SIN DEPOSITAR.** Si no
        // está, no hay camino y hay que decirlo, no dar verde.
        guard let t = interruptor() else {
            throw XCTSkip("este corte no ofrece el interruptor: ya está depositado")
        }
        // `exists` no implica `isHittable` — vuelta más del §0.-11.
        if !t.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        try XCTSkipUnless(t.isHittable, "el interruptor existe pero no es tocable")

        // El control NEGATIVO: antes de encenderlo el botón no puede estar.
        XCTAssertFalse(botonFirma.exists,
                       "### el botón de segunda firma ya estaba antes de pedirla")

        t.tap(); sleep(2)
        loEncendiYo = true
        volcado("doble firma pedida")

        XCTAssertTrue(botonFirma.waitForExistence(timeout: 5),
                      "### se pidió la doble firma y el botón de firmar no apareció")
        guard botonFirma.isHittable else {
            return XCTFail("### el botón de segunda firma existe pero no es tocable")
        }

        // Abrir · cancelar · reabrir, que es el patrón de las otras ocho.
        for vuelta in 1...2 {
            let antes = app.staticTexts.allElementsBoundByIndex.map(\.label).joined()
            botonFirma.tap(); sleep(3)
            let despues = app.staticTexts.allElementsBoundByIndex.map(\.label).joined()
            print("QA-FIRMA: vuelta \(vuelta), la pantalla \(antes == despues ? "NO cambió" : "cambió")")
            volcado("hoja de firma, vuelta \(vuelta)")

            XCTAssertNotEqual(antes, despues,
                              "### se tocó «Segunda firma» y la pantalla no cambió — la hoja no abrió")

            let cerrar = app.buttons.matching(
                NSPredicate(format: "label IN {'Cancel','Close','Done'}")).firstMatch
            if cerrar.waitForExistence(timeout: 3) && cerrar.isHittable {
                cerrar.tap()
            } else {
                app.swipeDown(velocity: .fast)   // hoja arrastrable
            }
            sleep(2)
            XCTAssertTrue(botonFirma.waitForExistence(timeout: 5),
                          "### tras cerrar la hoja no se volvió al detalle del corte")
        }
    }
}
