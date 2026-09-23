import XCTest

/// Los cuatro indicadores de Inicio en una columna estrecha (iPad mini en
/// vertical con la sidebar fijada): ninguna cifra puede partirse.
final class InicioEstrecho: XCTestCase {
    /// **Solo iPad.** Pide barra lateral o apaisado, y el iPhone no tiene
    /// ninguna de las dos (`project.yml`: solo vertical; `RootView`: la barra
    /// lateral solo con `.regular`). Corrida en el teléfono daba rojas que no
    /// decían nada de la app: ver `docs/ROJAS-SEPTIEMBRE.md`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    func testLasCifrasNoSePartenEnLaColumnaEstrecha() {
        let app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        // **La maqueta, no la iglesia sincronizada** (`docs/ROJAS-SEPTIEMBRE.md`):
        // el nombre del saludo es el tesorero de la semilla. Sin esto, en el
        // iPad físico (23-sep) la prueba medía los datos de la iglesia de Iván
        // y daba roja buscando cifras que allí no existen.
        app.launchArguments += ["-modoRevision", "YES"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        let mostrar = app.buttons["Show Sidebar"].firstMatch
        if mostrar.exists { mostrar.tap(); sleep(1) }
        let inicio = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Home'")).firstMatch
        if inicio.exists { inicio.tap(); sleep(3) }
        print("MARCA:I-inicio-estrecho"); fflush(stdout); Thread.sleep(forTimeInterval: 3)

        // El saludo, entero: es lo único personal de la pantalla. **La primera
        // palabra depende de la hora** (`DashboardView.saludo`): «Good morning»
        // solo hasta las 12, así que no se fija.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label MATCHES 'Good (morning|afternoon|evening), Iván'")).firstMatch.exists,
                      "### el saludo salió recortado")
        // Los rótulos enteros, no "Cash on h…".
        for r in ["Cash on hand", "Period income", "Period expenses", "To review"] {
            XCTAssertTrue(app.staticTexts[r].exists, "### falta el rótulo \(r)")
        }
        // Y las cifras en UN renglón: una tarjeta de 96 pt de alto con una
        // cifra partida pasa de 30 pt de texto.
        //
        // **Las cifras no se fijan**: la maqueta las calcula de sus movimientos
        // para el mes en curso (`MockDashboardRepository`), y cambian con la
        // fecha — los «$39,063» de ingresos del 9-sep eran «$53,383.00» el
        // 23-sep. Se miden las tres de las tarjetas, sean las que sean: las
        // cifras enteras con centavos (`$28,633.00`), no las del gráfico
        // (`$53.4k`).
        let cifras = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES '[$][0-9]{1,3}(,[0-9]{3})*[.][0-9]{2}'")).allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(cifras.count, 3, "### faltan cifras: \(cifras.map(\.label))")
        for e in cifras.prefix(3) {
            XCTAssertLessThan(e.frame.height, 45, "### \(e.label) salió en dos renglones: \(e.frame)")
        }
        // El conteo de la bandeja, sacado de la tarjeta («To review, 13, items, …»).
        // «items» la separa de la fila «To review, N» de la barra lateral.
        let tarjeta = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH 'To review, ' AND label CONTAINS 'items'")).firstMatch
        let rotulo = tarjeta.exists ? tarjeta.label : ""
        let n = rotulo.split(separator: ",").dropFirst().first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let bandeja = app.staticTexts[n.isEmpty ? "—" : n].firstMatch
        XCTAssertTrue(!n.isEmpty && bandeja.exists, "### el conteo de la bandeja se partió («\(rotulo)»)")
        if bandeja.exists {
            XCTAssertLessThan(bandeja.frame.height, 50, "### el \(n) salió en dos renglones: \(bandeja.frame)")
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
