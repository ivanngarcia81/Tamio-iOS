import XCTest

/// **El recorrido de la pasada de interfaz del iPad.** Visita las quince
/// secciones de la sidebar, y en cada una:
///
/// 1. vuelca los rótulos con su marco y **avisa de lo que se sale** del ancho
///    de la ventana;
/// 2. vuelca los botones y **avisa de los que no llegan a 44×44 pt**, que es
///    el mínimo tocable;
/// 3. se para e imprime una `MARCA:` para que el shell dispare
///    `xcrun simctl io <udid> screenshot` — el adjunto de XCUITest en apaisado
///    sale rotado y recortado (§0.0), así que las capturas se toman desde fuera.
///
/// La postura llega por `POSTURA` en el entorno y solo sirve para nombrar las
/// capturas: la orientación, el idioma, la apariencia y el tamaño de letra los
/// pone el shell antes de arrancar.
final class RecorridoIPadUITests: XCTestCase {

    var app: XCUIApplication!
    var postura: String { ProcessInfo.processInfo.environment["POSTURA"] ?? "base" }

    /// Las quince del `switch` de `RootView.pantallaDeSeccion`, en los dos
    /// idiomas: la app puede estar en cualquiera de los dos según el recorrido.
    let secciones: [(String, [String])] = [
        ("inicio",     ["Inicio", "Home"]),
        ("ingresos",   ["Ingresos", "Income"]),
        ("gastos",     ["Gastos", "Expenses"]),
        ("aportantes", ["Aportantes", "Contributors"]),
        ("reportes",   ["Reportes", "Reports"]),
        ("depositos",  ["Depósitos", "Deposits"]),
        ("porRevisar", ["Por revisar", "To review"]),
        ("membresia",  ["Membresía", "Membership"]),
        ("actas",      ["Actas", "Minutes"]),
        ("servicios",  ["Registro de servicios", "Service log"]),
        ("cartas",     ["Cartas y traslados", "Letters & transfers"]),
        ("informes",   ["Informes de membresía", "Membership reports"]),
        ("agenda",     ["Agenda", "Calendar"]),
        ("registro",   ["Registro", "Log"]),
        ("config",     ["Configuración", "Settings"]),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        // **La orientación se pone con XCUITest, no con `simctl`**: el
        // simulador no gira desde el shell (§0.0).
        switch env["ORIENT"] ?? "apaisado" {
        case "vertical": XCUIDevice.shared.orientation = .portrait
        default:         XCUIDevice.shared.orientation = .landscapeLeft
        }
        app = XCUIApplication()
        var args = ["-prefs.bienvenidaVista", "1"]
        // El idioma va por argumento de lanzamiento y no tocando el ajuste
        // global del simulador: así una postura no contamina a la siguiente.
        if let idioma = env["IDIOMA"] {
            args += ["-AppleLanguages", "(\(idioma))", "-AppleLocale",
                     idioma == "es" ? "es_MX" : "en_US"]
        }
        app.launchArguments = args
        app.launch()
    }

    private func parada(_ nombre: String) {
        print("MARCA: \(postura)__\(nombre)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }

    /// Abre la sidebar si viene colapsada (vertical y estrecho).
    private func abrirSidebarSiHaceFalta() {
        let boton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Sidebar' OR label CONTAINS 'barra lateral'")).firstMatch
        if boton.exists && boton.isHittable {
            // Si ya se ve una fila de sección, no hace falta.
            let yaSeVe = app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH 'Reportes' OR label BEGINSWITH 'Reports'")).firstMatch
            if !yaSeVe.exists || !yaSeVe.isHittable { boton.tap(); sleep(1) }
        }
    }

    private func volcar(_ titulo: String) {
        let ancho = app.frame.width
        let alto = app.frame.height
        print("===== VOLCADO \(postura) · \(titulo) · ventana \(Int(ancho))x\(Int(alto))")
        var desbordes = 0, pequenos = 0
        for t in app.staticTexts.allElementsBoundByIndex.prefix(120) {
            guard t.exists else { continue }
            let f = t.frame
            guard f.width > 0, f.height > 0 else { continue }
            if f.maxX > ancho + 0.5 || f.minX < -0.5 {
                desbordes += 1
                print(String(format: "  DESBORDA  %@  x=%.0f w=%.0f (ancho=%.0f)",
                             String(t.label.prefix(50)), f.minX, f.width, ancho))
            }
        }
        for b in app.buttons.allElementsBoundByIndex.prefix(120) {
            guard b.exists, b.isHittable else { continue }
            let f = b.frame
            guard f.width > 0, f.height > 0 else { continue }
            if f.height < 43.5 || f.width < 43.5 {
                pequenos += 1
                print(String(format: "  PEQUEÑO   %@  %.0fx%.0f",
                             String(b.label.prefix(50)), f.width, f.height))
            }
            if f.maxX > ancho + 0.5 {
                print(String(format: "  BOTÓN-FUERA %@  x=%.0f w=%.0f",
                             String(b.label.prefix(50)), f.minX, f.width))
            }
        }
        print("===== FIN \(titulo) · desbordes=\(desbordes) pequeños=\(pequenos)")
        fflush(stdout)
    }

    func testRecorridoDeLasQuince() throws {
        for (clave, nombres) in secciones {
            abrirSidebarSiHaceFalta()
            var tocada = false
            for n in nombres {
                let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", n)).firstMatch
                if b.exists && b.isHittable { b.tap(); tocada = true; break }
            }
            if !tocada {
                print("  SALTADA \(clave): el rol no la ve o no aparece")
                continue
            }
            sleep(2)
            volcar(clave)
            parada(clave)
        }
    }
}
