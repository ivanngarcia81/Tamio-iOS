import XCTest

/// **Corregir un asunto de «Por revisar» y comprobar que la corrección se
/// queda.**
///
/// La hoja de edición (`EditarAsuntoView`) ofrece seis campos: concepto,
/// importe, categoría, método, aportante y fecha. `RevisarCalculado.actualizar`
/// (`RevisarRepository.swift:85`) escribe **solo `editCategoria`** en el
/// movimiento. Lo demás se pierde al recalcularse la bandeja.
final class RevisarEdicion: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func testCorregirElImporteDeUnAsunto() {
        app.tabBars.buttons["To review"].tap(); sleep(3)
        print("BANDEJA:" + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        parada("revisar-lista")

        // Abrir el primer asunto: las filas de la lista se tocan por su texto.
        let fila = app.staticTexts["Missions · La Esperanza Mission Church"]
        guard fila.waitForExistence(timeout: 6) else { return XCTFail("no encuentro la fila") }
        fila.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        print("DETALLE:" + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        parada("revisar-detalle")

        let editar = app.buttons["Edit"]
        guard editar.waitForExistence(timeout: 5) else {
            print("BOTONES-DETALLE:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            return XCTFail("no hay botón Edit")
        }
        editar.tap(); sleep(3)
        print("HOJA:" + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        print("CAMPOS:" + app.textFields.allElementsBoundByIndex
            .map { "\($0.placeholderValue ?? "?")=\($0.value as? String ?? "")" }.joined(separator: "|"))
        parada("revisar-hoja")

        // Cambiar el importe a algo inconfundible.
        let campo = app.textFields["0.00"]
        guard campo.exists else { return XCTFail("no hay campo de importe") }
        let antes = campo.value as? String ?? ""
        campo.tap()
        // Vaciar y escribir 1.00
        for _ in 0..<12 { app.keys["Delete"].tap() }
        campo.typeText("1.00")
        sleep(1)
        print("IMPORTE-ANTES:\(antes) IMPORTE-ESCRITO:\(campo.value as? String ?? "")")

        app.buttons["Save changes"].tap(); sleep(3)
        print("TRAS-GUARDAR:" + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        parada("revisar-tras-guardar")

        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(textos.contains { $0.contains("1.00") },
                      "El importe corregido no aparece: la edición no se guardó")
        XCTAssertFalse(textos.contains { $0.contains(antes) && !antes.isEmpty },
                       "Sigue el importe viejo (\(antes)): la corrección se perdió")
    }
}

extension RevisarEdicion {

    /// **El control que hace precisa la queja.** `RevisarCalculado.actualizar`
    /// escribe SOLO `editCategoria`. Si la categoría sí se queda y el importe
    /// no, no es que "editar no funcione": es que cinco de los seis campos de
    /// la hoja se tiran sin decirlo.
    func testLaCategoriaSiSeQueda() {
        app.tabBars.buttons["To review"].tap(); sleep(3)
        let fila = app.staticTexts["Missions · La Esperanza Mission Church"]
        guard fila.waitForExistence(timeout: 6) else { return XCTFail("no encuentro la fila") }
        fila.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        guard app.buttons["Edit"].waitForExistence(timeout: 5) else { return XCTFail("no hay Edit") }
        app.buttons["Edit"].tap(); sleep(3)

        // El selector de categoría: se toca y se elige otra.
        print("HOJA-BOTONES:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        let cat = app.buttons["Category"]
        guard cat.exists else { return XCTFail("no hay selector de categoría") }
        cat.tap(); sleep(2)
        print("MENU-CATEGORIAS:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        let otra = app.buttons["Cleaning"]
        guard otra.exists else { return XCTFail("no está «Cleaning» en el menú") }
        let elegida = "Cleaning"
        otra.tap(); sleep(2)
        print("ELEGIDA:\(elegida)")

        app.buttons["Save changes"].tap(); sleep(3)
        let textos = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("TRAS-GUARDAR-CATEGORIA:" + textos.joined(separator: "|"))
        XCTAssertTrue(textos.contains(elegida),
                      "la categoría «\(elegida)» tampoco se quedó")
    }
}
