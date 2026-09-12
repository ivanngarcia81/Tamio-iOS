import XCTest
import UIKit

/// **Lo que solo se puede medir en el iPad de verdad.**
///
/// Corre con el modo revisión ENCENDIDO a propósito: la prueba del repintado
/// tiene que CAMBIAR valores, y en el aparato los datos son los de la iglesia.
/// Con el modo encendido se toca la maqueta y no se siembra nada real.
///
/// Las capturas se escriben en `Documents/` y se sacan con
/// `devicectl device copy from`: el adjunto de XCUITest en apaisado sale
/// rotado y recortado (§0.0), y en un aparato no hay `simctl io`.
final class InterfazAparatoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        // **El apaisado solo en iPad.** El teléfono es solo vertical a propósito
        // (`project.yml:69`): en apaisado pasaría a clase regular y se dibujaría
        // como un iPad, que no es la app del teléfono. Forzarlo aquí no rotaba
        // nada y dejaba la prueba creyendo que medía otra postura.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1", "-AppleLanguages", "(es)"]
        app.launch(); sleep(3)
    }

    private func guarda(_ nombre: String) {
        let img = XCUIScreen.main.screenshot().pngRepresentation
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("qa-\(nombre).png")
        try? img.write(to: url)
        print("CAPTURA: qa-\(nombre).png (\(img.count) bytes)")
        fflush(stdout)
    }

    /// **iPhone y iPad no navegan igual, y esta prueba solo sabía del iPad.**
    ///
    /// Escrita el 11-sep para el iPad, donde las quince secciones son botones de
    /// la sidebar y `vaA("Membresía")` los encuentra en el primer nivel. En el
    /// teléfono hay cinco pestañas —Inicio, Tesorería, Por revisar, Secretaría,
    /// Ajustes— y las secciones cuelgan de un hub dentro de cada una. Corrida
    /// tal cual en el iPhone el 12-sep: **13 de las 15 secciones SALTADAS y la
    /// prueba en verde**, porque el barrido hacía `continue` y no afirmaba nada.
    /// Es el mismo silencio que un `-only-testing` que no casa con ninguna
    /// clase.
    ///
    /// Qué pestaña abre cada sección en el teléfono. Es una conjetura hasta que
    /// una corrida la confirme: cuando una sección no aparece, `vaA` vuelca los
    /// rótulos del hub para que la corrida siguiente no adivine.
    private static let pestanaDe: [String: String] = [
        "Inicio": "Inicio",
        // **El teléfono no separa Ingresos de Gastos**: su hub de Tesorería
        // tiene UNA sección, «Movimientos». La separación es de la sidebar del
        // iPad. Volcado del hub, 12-sep: Movimientos, Aportantes, Depósitos,
        // Reportes.
        "Movimientos": "Tesorería", "Aportantes": "Tesorería",
        "Reportes": "Tesorería", "Depósitos": "Tesorería",
        "Por revisar": "Por revisar",
        "Membresía": "Secretaría", "Actas": "Secretaría",
        "Registro de servicios": "Secretaría", "Cartas y traslados": "Secretaría",
        "Informes de membresía": "Secretaría", "Agenda": "Secretaría",
        // «Registro» cuelga de Secretaría, no de Ajustes: su fila está en
        // `IPhoneSecretariaView:136`. Es el hub más cargado del teléfono —siete
        // secciones— y por eso el arrastre de `abrirFila` hace falta aquí.
        "Registro": "Secretaría",
        // **Y no hay ninguna sección «Configuración»**: en el teléfono Ajustes
        // es una pestaña con OCHO subpantallas, y «Configuración» es el nombre
        // que le da la sidebar del iPad a la pantalla entera. O sea que aquí
        // hay MÁS que barrer que en el iPad, no menos — y son justo las que la
        // pasada del 11-sep no tocó, porque cayó toda en `ConfiguracionView`
        // (el Ajustes del iPad) y no en `IPhoneAjustesView`.
        //
        // «Cuenta» se queda fuera a propósito: su fila es
        // «IG, Ivan Garcia, Cuenta · correo», así que no casa por prefijo y
        // lleva el correo de Iván en la etiqueta.
        "Iglesia": "Ajustes", "Institución": "Ajustes",
        "Tesorero y pastor": "Ajustes", "Acceso y áreas": "Ajustes",
        "Categorías": "Ajustes", "Preferencias": "Ajustes",
        "Zona de riesgo": "Ajustes",
    ]

    private var esTelefono: Bool { app.tabBars.buttons.count > 0 }

    /// Abre una fila del hub, con arrastre: en el teléfono la lista no cabe.
    /// El rótulo se compara **exacto primero**: `BEGINSWITH "Registro"` casa
    /// antes con «Registro de servicios» y abriría la sección equivocada sin
    /// decir nada.
    @discardableResult
    private func abrirFila(_ n: String) -> Bool {
        let exacto = NSPredicate(format: "label == %@", n)
        let porPrefijo = NSPredicate(format: "label BEGINSWITH %@", n)
        for intento in 0..<5 {
            for p in [exacto, porPrefijo] {
                let e = app.buttons.matching(p).firstMatch
                if e.waitForExistence(timeout: intento == 0 ? 4 : 1), e.isHittable {
                    e.tap(); sleep(2); return true
                }
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return false
    }

    private func vaA(_ n: String) -> Bool {
        // iPad: la sidebar tiene las quince en el primer nivel.
        if !esTelefono { return abrirFila(n) }

        // Teléfono: primero la pestaña, luego la fila del hub.
        guard let pestana = Self.pestanaDe[n] else {
            print("QA-SINMAPA: «\(n)» no está en el mapa de pestañas"); return false
        }
        let b = app.tabBars.buttons[pestana]
        guard b.waitForExistence(timeout: 10), b.isHittable else {
            print("QA-SINPESTAÑA: no hay pestaña «\(pestana)»"); return false
        }
        b.tap(); sleep(2)
        if pestana == n { return true }           // la pestaña ES la sección
        if abrirFila(n) { return true }

        // No adivinar a la vuelta siguiente: dejar escrito qué había de verdad.
        let rotulos = app.buttons.allElementsBoundByIndex.prefix(40)
            .compactMap { $0.exists ? $0.label : nil }.filter { !$0.isEmpty }
        print("QA-HUB «\(pestana)» no tenía «\(n)». Rótulos: \(rotulos)")
        return false
    }

    // MARK: - 1 · El repintado, que en el simulador NO se reproduce

    /// §4: los controles de una vista empujada con `NavigationLink` dentro de un
    /// `Form` no se repintan cuando cambia el `@State` del padre. Iván lo
    /// encontró DOS veces en su iPhone —el estado civil y los chips— y no se
    /// reproduce en el Mac. Aquí se comprueba que los arreglos aguantan.
    ///
    /// **Con control positivo**: primero se lee el estado, se toca, y se
    /// compara SIN salir de la página. Si el valor solo cambia al salir y
    /// volver, el arreglo no sirve.
    func testLosControlesEmpujadosSeRepintan() throws {
        XCTAssertTrue(vaA("Membresía"), "no se llega a Membresía")
        // Abrir la primera ficha de la lista.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.30)).tap(); sleep(2)
        guarda("miembro-ficha")

        // **Las cuatro páginas empujadas viven en la hoja de EDITAR**, no en la
        // ficha de lectura: la ficha enseña expediente, familia y movimientos,
        // y los `NavigationLink` están dentro del formulario.
        guard vaA("Editar") else {
            print("NO SE LLEGÓ al botón Editar"); guarda("miembro-sin-editar"); return
        }
        sleep(2)
        guarda("miembro-editar")

        // Entrar en "Servicio y habilidades", que es donde viven los chips.
        guard vaA("Servicio y habilidades") else {
            print("NO SE LLEGÓ a Servicio y habilidades"); guarda("miembro-sin-pagina"); return
        }
        sleep(2)
        guarda("chips-antes")

        // Tocar un chip y mirar SI SE PINTA sin salir de la página.
        let chip = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Alabanza' OR label CONTAINS 'Ujier' OR label CONTAINS 'Música'")).firstMatch
        if chip.waitForExistence(timeout: 8) {
            let antes = chip.isSelected
            chip.tap(); sleep(2)
            let despues = app.buttons.matching(NSPredicate(format: "label == %@", chip.label)).firstMatch.isSelected
            print("CHIP «\(chip.label)» · isSelected antes=\(antes) después=\(despues)")
            guarda("chips-despues")
        } else {
            print("no se encontró un chip conocido; rótulos: \(app.buttons.allElementsBoundByIndex.prefix(25).map { $0.label })")
            guarda("chips-sin-encontrar")
        }

        // Y un interruptor de los que van por `vivo(_:)`.
        let sw = app.switches.firstMatch
        if sw.exists {
            let antes = sw.value as? String
            sw.tap(); sleep(2)
            let despues = app.switches.firstMatch.value as? String
            print("INTERRUPTOR · antes=\(antes ?? "?") después=\(despues ?? "?")")
            guarda("interruptor-despues")
        }
    }

    // MARK: - 2 · El texto que quedó sin ver

    func testElFiltroDelPadronDiceTitle() throws {
        XCTAssertTrue(vaA("Informes de membresía"), "no se llega a Informes")
        sleep(2)
        guarda("informes")
        for n in ["Filtros", "Filtrar"] { if vaA(n) { break } }
        sleep(2)
        guarda("informes-filtros")
        let t = app.staticTexts.allElementsBoundByIndex.compactMap { $0.exists ? $0.label : nil }
        print("¿Cargo? \(t.contains("Cargo"))  ¿Rol? \(t.contains("Rol"))")
        print("rótulos: \(t.prefix(45))")
    }

    // MARK: - 3 · Barrido visual en iOS 27

    func testBarridoVisualEniOS27() throws {
        // **Las secciones son distintas en cada forma, no solo el camino.** La
        // lista del iPad tiene «Ingresos» y «Gastos» por separado y una
        // «Configuración» que en el teléfono no existe; el teléfono tiene
        // «Movimientos» y las ocho subpantallas de Ajustes. Usar la del iPad
        // aquí daba tres saltadas que parecían fallos del producto.
        let deIPad = ["Inicio","Ingresos","Gastos","Aportantes","Reportes","Depósitos",
                      "Por revisar","Membresía","Actas","Registro de servicios",
                      "Cartas y traslados","Informes de membresía","Agenda","Registro",
                      "Configuración"]
        let deTelefono = ["Inicio","Movimientos","Aportantes","Reportes","Depósitos",
                          "Por revisar","Membresía","Actas","Registro de servicios",
                          "Cartas y traslados","Informes de membresía","Agenda","Registro",
                          "Iglesia","Institución","Tesorero y pastor","Acceso y áreas",
                          "Categorías","Preferencias","Zona de riesgo"]
        let secciones = esTelefono ? deTelefono : deIPad
        print("QA-FORMA:\(esTelefono ? "telefono" : "ipad") · \(secciones.count) secciones")
        print("VENTANA: \(app.frame.size)")
        var medidas = 0, saltadas: [String] = []
        for s in secciones {
            guard vaA(s) else { print("SALTADA \(s)"); saltadas.append(s); continue }
            medidas += 1
            sleep(2)
            let ancho = app.frame.width
            var fuera = 0
            for t in app.staticTexts.allElementsBoundByIndex.prefix(110) {
                guard t.exists else { continue }
                let f = t.frame
                guard f.width > 0 else { continue }
                if f.maxX > ancho + 0.5 || f.minX < -0.5 {
                    fuera += 1
                    print("  DESBORDA \(s) · \(t.label.prefix(44)) x=\(Int(f.minX))..\(Int(f.maxX)) (ancho \(Int(ancho)))")
                }
            }
            print("SECCIÓN \(s) · desbordes=\(fuera)")
            guarda("sec-\(s.replacingOccurrences(of: " ", with: "-"))")
        }

        // **Contar lo medido, no fiarse del verde.** Sin esto la prueba hacía
        // `continue` en cada sección que no encontraba y terminaba en verde
        // habiendo mirado 2 de 15 (iPhone, 12-sep). Una prueba que se salta su
        // objeto tiene que fallar, igual que una que lo mira y no le gusta.
        print("QA-BARRIDO: medidas \(medidas)/\(secciones.count) · saltadas \(saltadas)")
        XCTAssertEqual(medidas, secciones.count, """
            El barrido no llegó a \(saltadas.count) de las \(secciones.count) \
            secciones: \(saltadas.joined(separator: ", ")). Mientras falte \
            alguna, "0 desbordes" no significa que no haya desbordes.
            """)
    }
}
