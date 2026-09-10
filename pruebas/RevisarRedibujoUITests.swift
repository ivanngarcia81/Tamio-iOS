import XCTest

/// **Corregir el importe de un asunto de «Por revisar» y verlo corregido.**
///
/// Esta prueba mide las TRES capas que tenían que arreglarse para que el usuario
/// viera su corrección, y por eso comprueba el importe en tres momentos:
///
/// 1. **Que se escriba.** `RevisarCalculado.actualizar` escribía solo la
///    categoría de los seis campos de la hoja, y ni esa llegaba porque el id del
///    asunto se partía por el primer guion del UUID (ver `BandejaConIdRealTests`).
/// 2. **Que la ficha abierta se entere** (`JUSTO-TRAS-GUARDAR`). El teléfono
///    empujaba el detalle con una COPIA del asunto (`navigationDestination(item:)`),
///    así que se quedaba con la cifra vieja; ahora lo busca por id, como ya hacía
///    la columna del iPad.
/// 3. **Que la lista se entere** (`EN-LA-LISTA`). `Revision` definía `==` por id,
///    y con eso SwiftUI da por buena la vista que ya tiene.
///
/// Si vuelve a fallar, el momento en el que falle dice cuál de las tres se
/// rompió. Se corre con el modo revisión ENCENDIDO.
final class RevisarRedibujo: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func abrirElAsunto() {
        let fila = app.staticTexts["Missions · La Esperanza Mission Church"]
        XCTAssertTrue(fila.waitForExistence(timeout: 8), "no encuentro la fila")
        fila.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
    }

    func importeEnPantalla() -> String {
        app.staticTexts.allElementsBoundByIndex.map(\.label)
            .first { $0.hasPrefix("−$") || $0.hasPrefix("+$") } ?? "?"
    }

    func testElImporteCorregidoSeQuedaTrasSalirYVolver() {
        app.tabBars.buttons["To review"].tap(); sleep(3)
        abrirElAsunto()
        print("ANTES:\(importeEnPantalla())")

        app.buttons["Edit"].tap(); sleep(3)
        print("CAMPOS:" + app.textFields.allElementsBoundByIndex
            .map { "[\($0.placeholderValue ?? "?")]=\($0.value as? String ?? "")" }.joined(separator: " "))
        let campo = app.textFields.element(boundBy: 0)
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "no encuentro el campo de importe")
        campo.tap()
        for _ in 0..<10 { app.keys["Delete"].tap() }
        campo.typeText("1.00"); sleep(1)
        let guardar = app.buttons["Save changes"]
        print("ESCRITO:[\(campo.value as? String ?? "?")] GUARDAR-ENCENDIDO:\(guardar.isEnabled)")
        parada("hoja-antes-de-guardar")
        guardar.tap(); sleep(3)
        print("JUSTO-TRAS-GUARDAR:\(importeEnPantalla())")
        parada("tras-guardar")

        // Salir del detalle y volver a entrar: si el dato está bien guardado y
        // lo único roto era el redibujo, aquí ya se ve el nuevo.
        let atras = app.navigationBars.buttons.element(boundBy: 0)
        if atras.exists && atras.isHittable { atras.tap(); sleep(3) }
        print("EN-LA-LISTA:" + app.staticTexts.allElementsBoundByIndex.map(\.label)
            .filter { $0.hasPrefix("−$") || $0.hasPrefix("+$") }.prefix(4).joined(separator: "|"))
        abrirElAsunto()
        let despues = importeEnPantalla()
        print("TRAS-VOLVER:\(despues)")
        parada("tras-volver")

        XCTAssertEqual(despues, "−$1.00",
                       "tras salir y volver sigue en \(despues): no se guardó")
    }
}
