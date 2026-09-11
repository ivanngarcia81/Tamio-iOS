import XCTest

/// **La séptima postura: la ventana estrechada hasta clase compacta.**
///
/// Dos avisos de instrumento que costaron una corrida cada uno:
///
/// 1. **Los marcos de XCUITest van en coordenadas de PANTALLA, no de ventana.**
///    Con la ventana estrechada y colocada a la derecha, comparar `maxX`
///    contra `app.frame.width` da por desbordado todo lo que está dentro: 60
///    falsos positivos. Se compara contra `app.frame.minX/maxX`.
/// 2. **El tamaño de la ventana sobrevive a relanzar la app y a la corrida
///    siguiente** (§0.-7), así que esta prueba termina devolviéndola a pantalla
///    completa desde los controles de ventana de SpringBoard — el asa no
///    ensancha.
final class EstrechoIPadUITests: XCTestCase {

    func testQuienDibujaEnCompactoYQueSeSale() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1", "-AppleLanguages", "(en)"]
        app.launch()
        sleep(3)

        if app.frame.width > 500 {
            let esquina = app.coordinate(withNormalizedOffset: CGVector(dx: 0.999, dy: 0.999))
            let destino = app.coordinate(withNormalizedOffset: CGVector(dx: 0.27, dy: 0.999))
            esquina.press(forDuration: 1.0, thenDragTo: destino)
            sleep(4)
        }

        let izq = app.frame.minX, der = app.frame.maxX
        print("VENTANA de \(Int(izq)) a \(Int(der)) · ancho \(Int(app.frame.width))")
        XCTAssertLessThan(app.frame.width, 500, "no se pudo estrechar la ventana")

        // ¿Quién dibuja? En compacto manda `IPhoneRootView`: pestañas, no sidebar.
        print("EN COMPACTO · pestañas=\(app.tabBars.firstMatch.exists) sidebar=\(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sidebar'")).firstMatch.exists)")

        print("MARCA: estrecho__compacto")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 4.0)

        var desbordes = 0
        for t in app.staticTexts.allElementsBoundByIndex.prefix(150) {
            guard t.exists else { continue }
            let f = t.frame
            guard f.width > 0 else { continue }
            if f.maxX > der + 0.5 || f.minX < izq - 0.5 {
                desbordes += 1
                print(String(format: "  DESBORDA %@ x=%.0f..%.0f (ventana %.0f..%.0f)",
                             String(t.label.prefix(46)), f.minX, f.maxX, izq, der))
            }
        }
        print("DESBORDES REALES: \(desbordes)")

        // Y restaurar, que si no la tanda siguiente arranca en compacto y el
        // recorrido fotografía la forma de teléfono dentro del iPad.
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for etiqueta in ["Window Controls", "Controles de ventana"] {
            let wc = sb.buttons.matching(NSPredicate(format: "label CONTAINS %@", etiqueta)).firstMatch
            if wc.exists && wc.isHittable { wc.tap(); sleep(1); break }
        }
        let zoom = sb.buttons.matching(NSPredicate(format: "label CONTAINS 'Zoom'")).firstMatch
        if zoom.waitForExistence(timeout: 3) { zoom.tap(); sleep(3) }
        print("ANCHO RESTAURADO: \(XCUIApplication().frame.width)")
    }
}
