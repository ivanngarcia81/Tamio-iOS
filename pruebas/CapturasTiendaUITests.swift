import XCTest

/// **Las capturas de la ficha de App Store.** No es una prueba de QA: no
/// afirma nada y no puede fallar por lo que vea. Navega a las pantallas que
/// venden la app y se para en cada una para que `capturas-tienda.sh` dispare
/// `xcrun simctl io <udid> screenshot`.
///
/// Por qué existe aparte de `RecorridoInterfaz`, que ya recorre lo mismo:
///
/// 1. **Va en español.** El recorrido de QA fuerza el inglés porque ahí lo que
///    se mira es el idioma que menos se usa y más se rompe. La ficha es para
///    México, y una captura en inglés en una ficha en español es un rechazo
///    tonto —2.3.3: las capturas tienen que enseñar la app en el idioma de esa
///    localización—.
/// 2. **El orden importa y el de QA no lo tiene.** App Store enseña las tres
///    primeras en el resultado de búsqueda, sin que nadie entre a la ficha. El
///    orden de abajo está elegido para eso: qué hace, con qué precisión, y para
///    quién.
/// 3. **Se para más rato.** El capturador de fuera mira el log una vez por
///    segundo (`capturar.sh`), así que una parada de 3,2 s puede fotografiar la
///    pantalla anterior si la animación de Liquid Glass aún corre. Aquí las
///    paradas son de 4,5 s: una captura movida de QA se repite, una de la ficha
///    se publica.
///
/// **No se corre a mano.** Necesita el modo revisión encendido y el aviso
/// naranja apagado, y las dos cosas las hace `pruebas/capturas-tienda.sh` sobre
/// una COPIA. Corrido contra el repo tal cual, la app abre en la pantalla de
/// acceso y las diez capturas salen iguales.
final class CapturasTienda: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        // `-prefs.idioma espanol` manda sobre la interfaz; `AppleLanguages`
        // manda sobre los diálogos del sistema y sobre cómo se formatean las
        // fechas y el dinero. Las dos, o el encabezado sale en español y los
        // importes con punto decimal inglés.
        app.launchArguments = [
            "-prefs.idioma", "espanol",
            "-prefs.bienvenidaVista", "1",
            "-AppleLanguages", "(es-MX)",
            "-AppleLocale", "es_MX",
        ]
        app.launch()
        sleep(3)
    }

    // MARK: - Ayudantes

    /// Se para y avisa. El nombre lleva número por delante porque App Store
    /// Connect ordena las capturas por el nombre del archivo al subirlas en
    /// lote, y sin número quedan alfabéticas: "agenda" primero y "inicio" en
    /// medio.
    private func parada(_ nombre: String) {
        print("MARCA: \(nombre)")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 4.5)
    }

    private func pestana(_ nombre: String) {
        let b = app.tabBars.buttons[nombre]
        guard b.waitForExistence(timeout: 6), b.isHittable else {
            print("  !! no existe la pestaña \(nombre)"); return
        }
        b.tap(); sleep(2)
    }

    /// Las filas de hub llevan la etiqueta larga —"Movimientos, 28 registros ·
    /// 19 sin depositar"—, así que se buscan por prefijo. Y **bajando**: bajo
    /// el pliegue no están en el árbol, y un "no existe" ahí es mentira.
    @discardableResult
    private func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<5 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 5 : 1) && e.isHittable {
                e.tap(); sleep(2); return true
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("  !! no encontré la fila \(prefijo)")
        return false
    }

    /// Las filas de una `List` son celdas con la etiqueta vacía: se tocan por
    /// su `staticText` y por coordenada.
    ///
    /// **Y siempre por `firstMatch`, nunca por subíndice.** `app.staticTexts[t]`
    /// con dos filas iguales no devuelve la primera: revienta la consulta con
    /// *"Multiple matching elements found"*, y eso **no lo salva
    /// `continueAfterFailure`** — se lleva la corrida entera por delante. Pasó
    /// con "Ofrenda misionera", que en la semilla sale dos veces: dos capturas
    /// buenas y las ocho siguientes sin hacer. En una lista de datos de ejemplo
    /// el texto repetido es lo normal, así que el subíndice no vale aquí nunca.
    @discardableResult
    private func tocarTexto(_ t: String) -> Bool {
        let e = app.staticTexts.matching(NSPredicate(format: "label == %@", t)).firstMatch
        guard e.waitForExistence(timeout: 6) else { print("  !! no encontré \(t)"); return false }
        e.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        sleep(2)
        return true
    }

    /// Cambia la vista de la Agenda y **comprueba que cambió**.
    ///
    /// La primera versión hacía `tap()` y se fiaba. La captura salió con el mes
    /// puesto —veinte casillas vacías— y nada avisó: `waitForExistence` dijo
    /// que sí, el toque no dio error, y el fallo solo estaba en el PNG. Las
    /// cápsulas llevan `.isSelected` a propósito (`AgendaView.chipVista`), así
    /// que se puede preguntar en vez de suponer; y si aun así no cambia, se
    /// vuelca lo que hay para que la vuelta siguiente empiece sabiendo algo.
    private func elegirVista(_ nombre: String) {
        let b = app.buttons.matching(NSPredicate(format: "label == %@", nombre)).firstMatch
        guard b.waitForExistence(timeout: 5) else { print("  !! no está la vista \(nombre)"); return }
        for intento in 1...3 {
            b.tap()
            sleep(2)
            if b.isSelected { return }
            print("  .. la vista \(nombre) no quedó elegida (intento \(intento))")
        }
        volcado("agenda: no pude cambiar a \(nombre)")
    }

    private func volver() {
        let atras = app.navigationBars.buttons.element(boundBy: 0)
        if atras.exists && atras.isHittable { atras.tap(); sleep(2) }
    }

    /// Qué hay en pantalla cuando algo no aparece. Una corrida de capturas
    /// dura ocho minutos: perderla entera para descubrir que la fila se llama
    /// de otra forma no compensa lo que cuesta imprimir esto.
    private func volcado(_ titulo: String) {
        print(">>> \(titulo)")
        print("  BOTONES: \(app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).joined(separator: " ‖ "))")
        fflush(stdout)
    }

    // MARK: - iPhone · las ocho de la ficha

    func testTelefono() {
        // 1 · Inicio. Es la primera del resultado de búsqueda: la que tiene que
        // decir "esto lleva la contabilidad de una iglesia" sin leer nada.
        pestana("Inicio")
        volcado("inicio")
        parada("01-inicio")

        // 2 · Movimientos. El libro, que es el producto.
        pestana("Tesorería")
        if abrirFila("Movimientos") {
            parada("02-movimientos")

            // 3 · La ficha de un movimiento con su historial. Es lo que
            // distingue esto de una hoja de cálculo: cada peso lleva quién lo
            // capturó y cuándo.
            //
            // **Este movimiento y no otro, y el motivo es la semilla.** Aquí
            // estaba "Ofrenda misionera", que en `MockMovimientosRepository`
            // tiene UNA entrada de auditoría y ningún comprobante: media
            // pantalla en blanco y un recuadro que dice "Sin comprobante", en
            // la captura que tiene que demostrar justo lo contrario. El folio
            // 1043 lleva tres entradas, nota larga y comprobante. Si algún día
            // cambia la semilla, esta captura se queda muda sin avisar.
            if tocarTexto("Diezmo · María Hernández") {
                parada("03-detalle-movimiento")
                volver()
            }
            volver()
        }

        // 4 · Un corte por dentro, no la lista. La lista son tres filas y
        // media pantalla vacía; el corte enseña de qué dinero está hecho, que
        // es lo que hay que contar.
        if abrirFila("Depósitos") {
            if tocarTexto("Culto domingo 6 de septiembre") { parada("04-deposito"); volver() }
            volver()
        }

        // 5 · Reportes · estado financiero.
        if abrirFila("Reportes") {
            if tocarTexto("Estado financiero") { parada("05-estado-financiero"); volver() }
            volver()
        }

        // 6 · Por revisar. La aprobación por rol, que es la razón de que esto
        // no sea la app de un solo aparato.
        pestana("Por revisar")
        parada("06-por-revisar")

        // 7 · Membresía · el padrón.
        pestana("Secretaría")
        if abrirFila("Membresía") {
            parada("07-membresia")
            // 8 · La ficha de un miembro.
            if tocarTexto("María Hernández Ríos") { parada("08-ficha-miembro"); volver() }
            volver()
        }

        // 9 · Agenda **en mes**, y elegido a mano aunque sea lo que ya está
        // puesto: `vistaActual` se conserva entre sesiones, así que heredar la
        // vista es heredar lo que hiciera la corrida anterior.
        //
        // **Se probó «Lista» y salió peor**, que es lo que no se adivina
        // leyendo: enseña los nombres de las actividades, sí, pero seis de las
        // siete del mes ya pasaron y salen TACHADAS y en gris. Una ficha de la
        // tienda con una lista tachada se lee como cosas canceladas. La rejilla
        // del mes es más pobre y no miente.
        if abrirFila("Agenda") {
            elegirVista("Mes")
            parada("09-agenda")
            volver()
        }

        // 10 · Un acta por dentro, por lo mismo que el corte: la lista son
        // cuatro filas, y lo que distingue esto de un cuaderno son los
        // acuerdos y las tres firmas.
        if abrirFila("Actas") {
            if tocarTexto("Acta 2026-08 · Consejo") { parada("10-acta"); volver() }
            volver()
        }
    }

    // MARK: - iPad · la sidebar lleva a todo, así que no hay que volver

    /// En apaisado, que es como se enseña un iPad en la tienda: la captura de
    /// 13" en vertical deja dos franjas blancas a los lados en el carrusel.
    func testIPad() {
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)

        let recorrido: [(String, String)] = [
            ("01-inicio",            "Inicio"),
            ("02-ingresos",          "Ingresos"),
            ("03-depositos",         "Depósitos"),
            ("04-reportes",          "Reportes"),
            ("05-por-revisar",       "Por revisar"),
            ("06-membresia",         "Membresía"),
            ("07-actas",             "Actas"),
            ("08-cartas",            "Cartas y traslados"),
            ("09-agenda",            "Agenda"),
            ("10-registro",          "Registro"),
        ]

        for (marca, seccion) in recorrido {
            abrirSidebarSiHaceFalta()
            let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", seccion)).firstMatch
            guard b.waitForExistence(timeout: 5), b.isHittable else {
                print("  SALTADA \(seccion)"); volcado(seccion); continue
            }
            b.tap(); sleep(3)
            parada(marca)
        }
    }

    private func abrirSidebarSiHaceFalta() {
        let boton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Sidebar' OR label CONTAINS 'barra lateral'")).firstMatch
        guard boton.exists, boton.isHittable else { return }
        let yaSeVe = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reportes'")).firstMatch
        if !yaSeVe.exists || !yaSeVe.isHittable { boton.tap(); sleep(1) }
    }
}
