import XCTest

/// **¿El día del calendario se toca entero o solo en el número?**
///
/// `AgendaView:277` declara el botón con `.frame(height: 54).frame(maxWidth:
/// .infinity)`, pero **sin `contentShape(Rectangle())`**, y el volcado dice que
/// el elemento mide 16×18 — el tamaño de los dígitos. Si el área tocable se
/// encogió al contenido dibujado, tocar dentro de la celda pero fuera del
/// número no abre nada, y la celda es 27 veces más pequeña de lo que parece.
///
/// **Con control positivo**: primero se toca el número (tiene que abrir), se
/// cierra, y después se toca el hueco de la misma celda.
final class DiaTocableUITests: XCTestCase {

    func testElDiaSeTocaEnteroOSoloEnElNumero() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1", "-AppleLanguages", "(es)"]
        app.launch(); sleep(3)

        let agenda = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Agenda'")).firstMatch
        XCTAssertTrue(agenda.waitForExistence(timeout: 15)); agenda.tap(); sleep(3)

        // Un día del mes con dos dígitos, que son los del calendario.
        let dia = app.buttons.matching(NSPredicate(format: "label == '15'")).firstMatch
        XCTAssertTrue(dia.waitForExistence(timeout: 10), "no aparece el día 15")
        let m = dia.frame
        print("MARCO DEL DÍA 15: \(Int(m.width))x\(Int(m.height)) en (\(Int(m.minX)),\(Int(m.minY)))")

        // CONTROL POSITIVO: tocar el número tiene que abrir el día.
        dia.tap(); sleep(2)
        let abrioEnElNumero = app.navigationBars.count > 0 &&
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'pendiente' OR label CONTAINS 'completo'")).firstMatch.exists
        print("CONTROL · tocando el número abre: \(abrioEnElNumero)")
        // Cerrar lo que se haya abierto.
        for et in ["Cerrar", "Listo", "Hecho"] {
            let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", et)).firstMatch
            if b.exists && b.isHittable { b.tap(); sleep(2); break }
        }

        // LA MEDIDA: tocar 20 pt por ENCIMA del número, dentro de los 54 pt que
        // el botón declara pero fuera de los dígitos.
        let hueco = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: m.midX, dy: m.minY - 18))
        hueco.tap(); sleep(2)
        let abrioEnElHueco = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'pendiente' OR label CONTAINS 'completo'")).firstMatch.exists
        print("MEDIDA · tocando el hueco de la celda abre: \(abrioEnElHueco)")
        print("MARCA: dia__hueco"); fflush(stdout); Thread.sleep(forTimeInterval: 3)

        if abrioEnElNumero && !abrioEnElHueco {
            print("HALLAZGO CONFIRMADO: el día solo se toca en el número")
        } else if abrioEnElNumero && abrioEnElHueco {
            print("NO HAY HALLAZGO: la celda se toca entera; el 16x18 es el marco de accesibilidad, no el área tocable")
        } else {
            print("NO CONCLUYENTE: el control positivo no abrió")
        }
    }
}
