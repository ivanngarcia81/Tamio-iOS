import XCTest

/// **Dos cosas de la pasada del 7 de septiembre que solo se ven mirando.**
/// Corre con `-modoRevision YES`, que sustituye al parche de la copia.
final class TrasladosYMembreteUITests: XCTestCase {

    /// En el teléfono, los cinco datos de un traslado sin gestos escondidos.
    /// Antes había una tabla de 580 puntos dentro de un scroll horizontal con
    /// `showsIndicators: false`: la fecha y el estado existían, pero fuera de
    /// la pantalla y sin nada que insinuara que se podía arrastrar.
    func testUnTrasladoSeVeEnteroEnElTelefono() {
        let app = XCUIApplication()
        // La maqueta y no la iglesia sincronizada: lo que busca es de la
        // semilla, y lo que escribe se queda en memoria (ver `docs/ROJAS-SEPTIEMBRE.md`).
        app.launchArguments += ["-modoRevision", "YES", "-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 30))
        app.buttons["Secretary"].tap()
        sleep(2)
        app.swipeUp(); sleep(1); app.swipeUp(); sleep(2)
        // BEGINSWITH: la fila del hub es un `NavigationLink` con título y
        // subtítulo, y su rótulo es «Membership reports, Overview, …».
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership reports'")).firstMatch.tap()
        sleep(4)
        for _ in 0..<9 { app.swipeUp() }
        sleep(3)
        // La cabecera de la tabla NO debe estar: en compacto no hay tabla.
        XCTAssertFalse(app.staticTexts["FOLIO"].exists,
                       "### la tabla de columnas fijas volvió al teléfono")
        // Y el folio sí, dentro de la fila.
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'TS-2026-011'")).firstMatch.exists,
            "### el folio del traslado no se ve")
    }

    /// En iPad la tabla se queda: allí las cinco columnas caben.
    func testEnIPadSigueLaTabla() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
        let app = XCUIApplication()
        // La maqueta y no la iglesia sincronizada: lo que busca es de la
        // semilla, y lo que escribe se queda en memoria (ver `docs/ROJAS-SEPTIEMBRE.md`).
        app.launchArguments += ["-modoRevision", "YES", "-bloqueo.biometrico", "NO"]
        app.launch()
        sleep(6)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.031, dy: 0.06)).tap()
        sleep(2)
        // BEGINSWITH: la fila del hub es un `NavigationLink` con título y
        // subtítulo, y su rótulo es «Membership reports, Overview, …».
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership reports'")).firstMatch.tap()
        sleep(4)
        for _ in 0..<10 { app.swipeUp() }
        sleep(3)
        XCTAssertTrue(app.staticTexts["FOLIO"].exists, "### se perdió la tabla en iPad")
    }

    /// La vista previa del membrete, que era un "Próximamente".
    func testElMembreteSeVe() {
        let app = XCUIApplication()
        // La maqueta y no la iglesia sincronizada: lo que busca es de la
        // semilla, y lo que escribe se queda en memoria (ver `docs/ROJAS-SEPTIEMBRE.md`).
        app.launchArguments += ["-modoRevision", "YES", "-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 30))
        app.buttons["Settings"].tap()
        sleep(2)
        app.staticTexts["Institution"].firstMatch.tap()
        sleep(3)
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        sleep(2)
        let boton = app.staticTexts["See how the letterhead looks"].firstMatch
        XCTAssertTrue(boton.waitForExistence(timeout: 8), "### no está el botón del membrete")
        boton.tap()
        sleep(5)
        XCTAssertTrue(app.staticTexts["Letterhead"].exists)
    }
}
