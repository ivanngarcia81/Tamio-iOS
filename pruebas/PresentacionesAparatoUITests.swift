import XCTest

/// **Z2: las presentaciones de `CorteDetalle` y `ActasView`, abiertas de
/// verdad.** La pasada del 10-sep llegó a las dos listas y no abrió ninguna
/// ficha; esta las abre en el iPhone de Iván, con sus datos.
///
/// **Son NUEVE, no diez.** El encargo contaba cinco en cada una. `CorteDetalle`
/// tiene cinco —`:63` agregar movimientos, `:68` cuenta nueva (una `alert` con
/// `TextField`), `:79` registrar depósito, `:84` fecha, `:85` segunda firma—,
/// pero `ActasView` tiene **cuatro**: un `.sheet(isPresented:)` (`:85`), dos
/// `.sheet(item:)` (`:91`, `:106`) y una `.alert` (`:111`). El encargo decía
/// «dos `.sheet(isPresented:)`, dos `.sheet(item:)` y una `.alert`» y el primer
/// par es uno solo.
///
/// **Nada de esto escribe.** Se abre, se mira y se cancela. Lo único que se
/// toca de verdad es el lienzo de la firma, y ahí tampoco se guarda: lo que se
/// comprueba es que «Guardar» se ENCIENDA, no que grabe.
final class PresentacionesAparatoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1", "-AppleLanguages", "(es)"]
        app.launch(); sleep(3)
    }

    // MARK: - Andamio

    private func volcado(_ titulo: String, captura: Bool = false) {
        let bot = app.buttons.allElementsBoundByIndex.prefix(30)
            .compactMap { $0.exists && !$0.label.isEmpty ? $0.label : nil }
        // **Los textos también, y no solo los botones.** El primer intento
        // volcaba botones y en Actas salió `["…", "Nuevo"]` a secas: sin los
        // textos no había forma de saber si la pantalla estaba vacía o si la
        // prueba no había llegado a ella.
        let txt = app.staticTexts.allElementsBoundByIndex.prefix(25)
            .compactMap { $0.exists && !$0.label.isEmpty ? $0.label : nil }
        print(">>> \(titulo)")
        print("    BOTONES: \(bot)")
        print("    TEXTOS:  \(txt)")
        if captura { guarda(titulo) }
        fflush(stdout)
    }

    /// La captura se escribe en el contenedor del RUNNER y se saca con
    /// `devicectl device copy from --domain-identifier
    /// church.tamio.native.PruebasUIAparato.xctrunner`.
    private func guarda(_ nombre: String) {
        let limpio = nombre.replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ":", with: "")
        let img = XCUIScreen.main.screenshot().pngRepresentation
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? img.write(to: dir.appendingPathComponent("qa-pres-\(limpio).png"))
        print("    CAPTURA: qa-pres-\(limpio).png (\(img.count) bytes)")
    }

    /// El botón cuyo rótulo ES una fecha. La fila «Fecha» tiene el rótulo en un
    /// `Text` y la fecha en el `Button` (`CorteDetalle:598`), así que buscar un
    /// botón llamado «Fecha» no encuentra nada — y eso fue lo que la primera
    /// corrida apuntó como «no encontrada».
    /// Arrastra hasta que el elemento se pueda tocar. **XCUITest lista
    /// elementos que están FUERA de pantalla**, así que `exists` no implica
    /// `isHittable`: «10 sept 2026» y «Chase» salían en el volcado y las dos
    /// presentaciones se apuntaron como «sin camino» estando ahí, solo por
    /// debajo del borde. Es la misma familia que el §0.-10 —el marco no es el
    /// área tocable— con una vuelta más: existir no es estar visible.
    @discardableResult
    private func acercar(_ e: XCUIElement) -> Bool {
        guard e.exists else { return false }
        if e.isHittable { return true }
        for _ in 0..<6 {
            app.swipeUp(velocity: .slow); sleep(1)
            if e.isHittable { return true }
        }
        return false
    }

    private func botonDeFecha() -> XCUIElement? {
        let patron = try? NSRegularExpression(
            pattern: "^\\d{1,2} \\p{L}+\\.? \\d{4}$")
        for b in app.buttons.allElementsBoundByIndex.prefix(30) where b.exists {
            let l = b.label
            if l == "Por definir" { return b }
            let r = NSRange(l.startIndex..., in: l)
            if patron?.firstMatch(in: l, range: r) != nil { return b }
        }
        return nil
    }

    /// Abre una fila con arrastre, comparando el rótulo **exacto primero**:
    /// `BEGINSWITH` casa antes con el rótulo más largo que empiece igual y
    /// abriría otra cosa sin decirlo.
    @discardableResult
    private func abrir(_ n: String, enCeldas: Bool = false) -> Bool {
        let exacto = NSPredicate(format: "label == %@", n)
        let prefijo = NSPredicate(format: "label BEGINSWITH %@", n)
        for intento in 0..<5 {
            for p in [exacto, prefijo] {
                let e = enCeldas ? app.cells.matching(p).firstMatch
                                 : app.buttons.matching(p).firstMatch
                if e.waitForExistence(timeout: intento == 0 ? 4 : 1), e.isHittable {
                    e.tap(); sleep(2); return true
                }
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return false
    }

    private func pestana(_ n: String) -> Bool {
        let b = app.tabBars.buttons[n]
        guard b.waitForExistence(timeout: 10), b.isHittable else {
            print("!! no hay pestaña «\(n)»"); return false
        }
        b.tap(); sleep(2); return true
    }

    /// Cierra lo que esté presentado. Se prueban las dos salidas porque no
    /// todas las hojas llevan «Cancelar»: algunas solo se van con el gesto.
    private func cerrar() {
        for r in ["Cancelar", "Cerrar", "Listo"] {
            let b = app.buttons[r]
            if b.exists && b.isHittable { b.tap(); sleep(2); return }
        }
        // Arrastre hacia abajo desde arriba de la hoja.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
           .press(forDuration: 0.15,
                  thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        sleep(2)
    }

    // MARK: - 1 · El lienzo de la firma, con el dedo de verdad

    /// **`PKCanvasView` no es observable, y eso ya dejó «Guardar» apagado con la
    /// firma hecha.** El arreglo está puesto —un contador `trazos` que alimenta
    /// `canvasViewDrawingDidChange`, y `vacio` mira el contador Y los trazos
    /// (`HojaFirma:43`)—, pero nunca se ha ejercitado con un dedo: el simulador
    /// no dibuja y en el iPad no se llegó.
    ///
    /// **Lleva su propio control positivo dentro:** se afirma que «Guardar»
    /// está APAGADO antes de dibujar y ENCENDIDO después. Sin la primera mitad,
    /// un botón que estuviera siempre encendido pasaría la prueba.
    ///
    /// No guarda: al final se cancela.
    func testDibujarEnElLienzoEnciendeGuardar() throws {
        XCTAssertTrue(pestana("Ajustes"), "no hay pestaña Ajustes")
        XCTAssertTrue(abrir("Tesorero y pastor"), "no se llega a Tesorero y pastor")
        volcado("Tesorero y pastor")

        // La fila de firma es un `HStack` con `.onTapGesture`, NO un `Button`,
        // así que no está entre `app.buttons`. Se busca por su texto.
        let fila = app.staticTexts.matching(
            NSPredicate(format: "label == 'Sin firma' OR label == 'Firma'")).firstMatch
        guard fila.waitForExistence(timeout: 8) else {
            volcado("sin fila de firma")
            return XCTFail("no encontré la fila de firma")
        }
        fila.tap(); sleep(3)
        volcado("HojaFirma")

        let guardar = app.buttons["Guardar"]
        guard guardar.waitForExistence(timeout: 8) else {
            return XCTFail("la hoja de firma no abrió: no hay botón Guardar")
        }

        // --- control positivo: apagado con el lienzo en blanco
        XCTAssertFalse(guardar.isEnabled, """
            «Guardar» ya estaba ENCENDIDO con el lienzo en blanco, así que \
            encenderse después no demostraría nada. O la hoja abrió con una \
            firma ya hecha —y entonces hay que borrarla antes— o `vacio` \
            (`HojaFirma:43`) no está mirando el lienzo.
            """)
        print("QA-FIRMA: Guardar apagado con el lienzo en blanco")

        // --- el trazo: tres segmentos despacio, como un dedo
        let centro = app.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.45))
        for (dx, dy) in [(0.55, 0.52), (0.45, 0.38), (0.68, 0.48)] {
            centro.press(forDuration: 0.12,
                         thenDragTo: app.coordinate(
                            withNormalizedOffset: CGVector(dx: dx, dy: dy)))
            usleep(300_000)
        }
        sleep(2)

        XCTAssertTrue(guardar.isEnabled, """
            Se dibujó en el lienzo y «Guardar» sigue APAGADO. Es la regresión \
            de `PKCanvasView` que `HojaFirma:31-43` dice haber arreglado con el \
            contador `trazos`: o el delegado no llega, o el arrastre de \
            XCUITest no cuenta como trazo —y entonces lo que falla es la \
            prueba, que hay que comprobar mirando la captura—.
            """)
        print("QA-FIRMA: Guardar ENCENDIDO tras dibujar")

        // Y «Borrar» tiene que volver a apagarlo: es la otra mitad de `vacio`.
        let borrar = app.buttons["Borrar"]
        if borrar.exists && borrar.isHittable {
            borrar.tap(); sleep(2)
            XCTAssertFalse(guardar.isEnabled,
                           "«Borrar» dejó «Guardar» encendido con el lienzo vacío")
            print("QA-FIRMA: Borrar lo vuelve a apagar")
        }
        cerrar()
    }

    // MARK: - 2 · Las cinco de CorteDetalle

    private func irAUnCorte() -> Bool {
        guard pestana("Tesorería") else { return false }
        guard abrir("Depósitos") else { print("!! no hay Depósitos"); return false }
        volcado("Depósitos")
        // El primer corte de la lista. Su rótulo lleva datos, así que se toca
        // la primera celda tocable en vez de buscarlo por nombre.
        let celda = app.cells.allElementsBoundByIndex.first { $0.isHittable }
        guard let celda else { print("!! no hay ningún corte en la lista"); return false }
        celda.tap(); sleep(3)
        volcado("CorteDetalle")
        return true
    }

    func testLasCincoPresentacionesDeCorteDetalle() throws {
        try XCTSkipUnless(irAUnCorte(), "no se pudo abrir ningún corte")

        var abiertas: [String] = [], sinCamino: [String] = []

        func ejercitar(_ nombre: String, _ abrirla: () -> Bool) {
            guard abrirla() else {
                // **El volcado va en el fallo, que es cuando hace falta.** Sin
                // esto la corrida solo dice «no encontrada», y eso no distingue
                // un botón que no existe de uno que se quedó fuera de pantalla
                // porque `abrir` arrastró buscando otro.
                sinCamino.append(nombre)
                volcado("NO se abrió: \(nombre)", captura: true)
                return
            }
            volcado("abierta: \(nombre)", captura: true)
            abiertas.append(nombre)
            cerrar()
            // **Dos veces seguidas**, que es donde una hoja que no limpia su
            // estado se nota.
            if abrirla() { cerrar() } else {
                XCTFail("«\(nombre)» no se pudo volver a abrir tras cerrarla")
            }
        }

        // **Volver al principio de la ficha entre una y otra.** `abrir`
        // arrastra hacia abajo cuando no encuentra lo que busca, así que la
        // presentación siguiente se buscaba desde donde quedó la anterior y
        // podía estar por encima del borde.
        func alPrincipio() {
            for _ in 0..<4 { app.swipeDown(velocity: .fast) }
            sleep(1)
        }

        // 1 y 3 · botones con rótulo propio (`:63` y `:79`).
        ejercitar("Agregar dinero sin depositar") {
            alPrincipio(); return self.abrir("Agregar dinero sin depositar")
        }
        ejercitar("Marcar depositado") {
            alPrincipio(); return self.abrir("Marcar depositado")
        }

        // 4 · la fecha (`:84`). El botón lleva la FECHA, no la palabra.
        ejercitar("Fecha") {
            alPrincipio()
            guard let b = self.botonDeFecha(), self.acercar(b) else { return false }
            b.tap(); sleep(2); return true
        }

        // 2 · «Otra cuenta…» (`:68`) vive dentro de un `Menu`, así que hay que
        // abrir el menú primero. Cuál es el menú no se puede escribir a mano
        // —su rótulo es el nombre de la cuenta del corte, o sea un dato—, así
        // que se reconoce por lo que revela: se prueban los botones y el menú
        // es el que hace aparecer «Otra cuenta…».
        ejercitar("Otra cuenta…") {
            alPrincipio()
            let conocidos: Set<String> = ["Inicio", "Tesorería", "Por revisar",
                                          "Secretaría", "Ajustes", "Atrás",
                                          "Marcar depositado", "Nuevo corte",
                                          "Cambiar periodo",
                                          "Agregar dinero sin depositar"]
            let candidatos = app.buttons.allElementsBoundByIndex.prefix(30)
                .filter { $0.exists && !$0.label.isEmpty
                          && !conocidos.contains($0.label) }
                .map(\.label)
            for l in candidatos {
                let b = app.buttons[l]
                guard self.acercar(b) else { continue }
                b.tap(); sleep(1)
                let otra = self.app.buttons["Otra cuenta…"]
                if otra.waitForExistence(timeout: 2), otra.isHittable {
                    print("    QA-MENU-CUENTAS: «\(l)»")
                    otra.tap(); sleep(2); return true
                }
                self.cerrar()
            }
            return false
        }

        // 5 · **«Segunda firma» (`:85`) no tiene camino en este aparato, y no
        // es un fallo.** `botonFirmar` se pinta solo si el corte pidió doble
        // firma y todavía no la tiene (`CorteDetalle:433` y `:439`).
        // Comprobado en el servidor el 12-sep, sobre los 5 cortes vivos:
        //
        //   abierto    · pide doble  · ya firmado   1
        //   abierto    · no la pide  · sin firmar   1
        //   depositado · pide doble  · ya firmado   1
        //   depositado · no la pide  · sin firmar   2
        //
        // O sea que **los dos que la piden ya la tienen y los tres que no la
        // tienen no la piden**: no existe ningún corte que pueda enseñar ese
        // botón. Lo apunté antes como «3 sin segunda firma, así que hay
        // camino» mirando solo `segunda_firma_en is null`, y era la columna
        // equivocada — sin la consulta esto se habría escrito como hallazgo.
        //
        // Para ejercitarla hace falta un corte nuevo con doble firma pedida, y
        // eso es escribir en la base de la iglesia: queda para Iván o para una
        // prueba que siembre y limpie.
        var firmaAlcanzada = false
        for i in 0..<6 {
            let atras = app.buttons["Atrás"]
            if atras.exists && atras.isHittable { atras.tap(); sleep(2) }
            let celdas = app.cells.allElementsBoundByIndex.filter(\.isHittable)
            guard i < celdas.count else { break }
            celdas[i].tap(); sleep(3)
            let b = app.buttons["Segunda firma"]
            if b.exists, acercar(b) {
                b.tap(); sleep(2)
                volcado("abierta: Segunda firma (corte \(i))", captura: true)
                abiertas.append("Segunda firma"); cerrar()
                firmaAlcanzada = true; break
            }
        }
        if !firmaAlcanzada {
            print("QA-CORTE-FIRMA: ningún corte enseña «Segunda firma». " +
                  "Esperado con los datos de hoy: los dos que piden doble firma ya la tienen.")
        }

        print("QA-CORTE: abiertas \(abiertas.count) \(abiertas) · sin camino \(sinCamino)")

        // Las CUATRO que dependen del código —no de los datos— tienen que
        // abrirse. La quinta se informa arriba y no se exige.
        XCTAssertTrue(sinCamino.isEmpty, """
            No se llegó a \(sinCamino). Estas cuatro no dependen del estado de \
            los datos, así que una que no se alcance es un hallazgo o un \
            camino mal escrito: mirar `qa-pres-NO-se-abrió-*.png`.
            """)
        XCTAssertGreaterThanOrEqual(abiertas.count, 4,
                                    "se abrieron \(abiertas.count) de las cuatro que no dependen de los datos")
    }

    // MARK: - 3 · Las cuatro de ActasView

    func testLasCuatroPresentacionesDeActasView() throws {
        XCTAssertTrue(pestana("Secretaría"), "no hay pestaña Secretaría")
        volcado("hub Secretaría", captura: true)
        try XCTSkipUnless(abrir("Actas"), "no se llega a Actas")
        volcado("Actas", captura: true)

        // Los rótulos de verdad, leídos del código y no adivinados: «Nuevo»
        // (`ActasView:76`, y no «Nueva acta»), «PDF» (`:220`), «Recopilar
        // firmas» (`:232`, y no «Firmar») y «Cerrar acta» (`:237`).
        var abiertas: [String] = [], sinCamino: [String] = []

        // 1 · «Nuevo» es el `+` de la barra y vive en la LISTA.
        if abrir("Nuevo") {
            volcado("abierta: Nuevo", captura: true)
            abiertas.append("Nuevo"); cerrar()
            if abrir("Nuevo") { cerrar() } else {
                XCTFail("«Nuevo» no se pudo volver a abrir tras cerrarla")
            }
        } else { sinCamino.append("Nuevo") }

        // **Las otras tres están en la FICHA, no en la lista.**
        // `accionesActa` se pinta dentro de `detalle(_:)` (`ActasView:256` y
        // `:259`), que es el destino de navegación de la tarjeta. La primera
        // versión de esta prueba las buscó en la lista y las apuntó como «no
        // encontradas» — que es EXACTAMENTE el error que este encargo le
        // reprocha a la pasada anterior: llegar a la lista y no abrir la ficha.
        // La captura de la lista lo dejó claro: el acta está ahí, con su
        // distintivo «Borrador», y sin ningún botón.
        let tarjeta = app.cells.allElementsBoundByIndex.first { $0.isHittable }
            ?? app.buttons.matching(NSPredicate(format: "label CONTAINS 'meeting' OR label CONTAINS 'Borrador'")).firstMatch
        if tarjeta.exists && tarjeta.isHittable {
            tarjeta.tap(); sleep(3)
            volcado("ficha del acta", captura: true)
        } else {
            volcado("sin tarjeta de acta", captura: true)
            return XCTFail("no se pudo abrir la ficha del acta")
        }

        // «PDF» siempre; «Recopilar firmas» y «Cerrar acta» solo si el acta
        // está en borrador o pendiente. La del aparato está en BORRADOR —lo
        // dice su distintivo y lo confirma el servidor—, así que las tres
        // tienen camino.
        for rotulo in ["PDF", "Recopilar firmas", "Cerrar acta"] {
            guard abrir(rotulo) else { sinCamino.append(rotulo); continue }
            volcado("abierta: \(rotulo)", captura: true)
            abiertas.append(rotulo)
            cerrar()
            if abrir(rotulo) { cerrar() } else {
                XCTFail("«\(rotulo)» no se pudo volver a abrir tras cerrarla")
            }
        }

        print("QA-ACTAS: abiertas \(abiertas.count)/4 \(abiertas) · sin camino \(sinCamino)")
        XCTAssertTrue(sinCamino.isEmpty, """
            No se llegó a \(sinCamino). El aparato tiene UN acta viva en \
            borrador, así que las cuatro tienen camino: si falta alguna es un \
            hallazgo o un camino mal escrito. Mirar las capturas \
            `qa-pres-Actas.png` y `qa-pres-ficha-del-acta.png`.
            """)
    }
}
