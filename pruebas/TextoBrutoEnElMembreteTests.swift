import XCTest
import PDFKit
@testable import Tamio

/// **Qué hace un nombre de iglesia de 500 caracteres en los documentos que se
/// entregan.** Sustituye al intento por interfaz.
///
/// `pruebas/TextoBrutoUITests.swift` iba por la pantalla y su propia cabecera
/// avisaba de que no medía nada: `app.keys["delete"]` no vaciaba el campo y
/// tras «Save» la navegación no salía de Ajustes, así que no se llegaba nunca
/// al membrete. Y el encargo pedía mirar los membretes **impresos**, no en
/// pantalla, que es donde un rótulo que no cabe se nota.
///
/// **Por qué esto no toca la configuración de la iglesia.** Las seis hojas
/// reciben `iglesia:` por parámetro —su omisión es
/// `ConfiguracionIglesiaViewModel.compartido.config`—, así que se les pasa una
/// copia adulterada y la config real no se toca. Escribirla habría subido un
/// nombre de 500 caracteres al servidor, que lo comparte la app web.
///
/// **Qué se mide: PÁGINAS, no bytes.** `PDFExport` no recorta, **pagina**:
/// `paginas = ceil((size.height - blancoDePie) / altoCarta)`
/// (`Support/PDFExport.swift:55`). Así que un membrete que no cabe no sale con
/// «…», sale empujando el documento, y el corte cae donde caiga —la traslación
/// es por altura de página, no por línea—. Un acta de una página que pasa a
/// tres por el nombre es el hallazgo; los bytes no lo dicen.
@MainActor
final class TextoBrutoEnElMembreteTests: XCTestCase {

    /// 500 caracteres. Palabras de verdad y no una letra repetida: una `a` ×500
    /// es UNA palabra que no se puede partir, y mediría el caso degenerado en
    /// vez del que ocurre.
    private var nombreLarguisimo: String {
        let trozo = "Iglesia Cristiana Evangélica Pentecostés Monte de Sion "
        return String(String(repeating: trozo, count: 12).prefix(500))
    }

    /// Emoji compuesto, comillas y coma. Ya se midió que entran tal cual en el
    /// CAMPO (`TextoBrutoUITests`); lo que faltaba es qué hace con ellos el PDF.
    private let nombreConBasura = #"Iglesia "El Redil", Monte de Sión 🎉👨‍👩‍👧‍👦"#

    private func iglesia(nombre: String) -> ConfiguracionIglesia {
        var c = ConfiguracionIglesia()
        c.nombre = nombre
        c.ciudad = "Monterrey"
        c.pastorNombre = "Samuel Ruvalcaba"
        c.secretarioNombre = "Lucía Márquez"
        return c
    }

    private var destino: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Devuelve el número de páginas, y deja el PDF en `Documents/` para poder
    /// SACARLO del aparato y mirarlo — que es lo único que dice si además de
    /// caber, se lee.
    private func paginas(_ url: URL?, como nombre: String) throws -> Int {
        let url = try XCTUnwrap(url, "PDFExport devolvió nil: no se generó \(nombre)")
        let datos = try Data(contentsOf: url)
        let fin = destino.appendingPathComponent("qa-bruto-\(nombre).pdf")
        try? FileManager.default.removeItem(at: fin)
        try? datos.write(to: fin)
        let doc = try XCTUnwrap(PDFDocument(url: url), "PDFKit no pudo abrir \(nombre)")
        print("QA-BRUTO:\(nombre):paginas=\(doc.pageCount):bytes=\(datos.count)")
        return doc.pageCount
    }

    private func acta() -> Acta {
        var a = Acta(id: "a1", folio: "2026-08", tipo: .lideres,
                     fecha: "2026-08-21", estado: .aprobada,
                     items: [AcuerdoActa(id: 1, texto: "Se aprueba el estado financiero de julio.")])
        a.lugar = "el salón anexo"
        a.preside = "Pastor Abel Ramos"
        a.secretario = "María Hernández Ríos"
        a.presentes = ["Pastor Abel Ramos", "María Hernández Ríos"]
        a.quorum = true
        return a
    }

    private func carta() -> CartaEnEdicion {
        var c = CartaEnEdicion()
        c.aportante = "Ana Lucía Torres"
        c.iglesiaDestino = "Iglesia Betel"
        c.miembroDesde = "2019"
        c.firma = "Samuel Ruvalcaba"
        return c
    }

    private func renderActa(_ nombre: String, como archivo: String) throws -> Int {
        try paginas(PDFExport.render(ActaHojaPDF(acta: acta(), iglesia: iglesia(nombre: nombre)),
                                     nombre: "bruto-\(archivo)"), como: archivo)
    }

    private func renderCarta(_ nombre: String, como archivo: String) throws -> Int {
        try paginas(PDFExport.render(
            CartaHojaPDF(carta: carta(), tipo: .recomendacion,
                         cuerpo: "Por medio de la presente recomendamos a Ana Lucía Torres.",
                         iglesia: iglesia(nombre: nombre)),
            nombre: "bruto-\(archivo)"), como: archivo)
    }

    private func renderMembrete(_ nombre: String, como archivo: String) throws -> Int {
        try paginas(PDFExport.render(MembreteHojaPDF(iglesia: iglesia(nombre: nombre)),
                                     nombre: "bruto-\(archivo)"), como: archivo)
    }

    // MARK: - El control, primero

    /// **Control positivo.** Con un nombre normal los tres documentos son de una
    /// página. Sin esto, «tres páginas» no se puede atribuir al nombre.
    func testConUnNombreNormalLosTresCabenEnUnaPagina() throws {
        XCTAssertEqual(try renderActa("Iglesia Nueva Vida", como: "acta-normal"), 1)
        XCTAssertEqual(try renderCarta("Iglesia Nueva Vida", como: "carta-normal"), 1)
        XCTAssertEqual(try renderMembrete("Iglesia Nueva Vida", como: "membrete-normal"), 1)
    }

    // MARK: - Los 500 caracteres

    /// El acta repite el nombre DOS veces —el bloque central
    /// (`SecretariaPDF:98`) y el renglón «nombre · Acta folio» (`:170`)—, así
    /// que es la que más superficie le da al nombre.
    func testElActaConQuinientosCaracteres() throws {
        let n = try renderActa(nombreLarguisimo, como: "acta-500")
        XCTAssertEqual(n, 1, """
            El acta pasó de 1 a \(n) páginas solo por el nombre de la iglesia. \
            `PDFExport` pagina por ALTURA y no por línea, así que el corte cae \
            donde caiga: hay que mirar `qa-bruto-acta-500.pdf` para saber qué \
            quedó partido.
            """)
    }

    func testLaCartaConQuinientosCaracteres() throws {
        let n = try renderCarta(nombreLarguisimo, como: "carta-500")
        XCTAssertEqual(n, 1, "la carta pasó de 1 a \(n) páginas por el nombre")
    }

    func testElMembreteConQuinientosCaracteres() throws {
        let n = try renderMembrete(nombreLarguisimo, como: "membrete-500")
        XCTAssertEqual(n, 1, "el membrete pasó de 1 a \(n) páginas por el nombre")
    }

    // MARK: - Emoji, comillas y coma

    /// Que no reviente y que el emoji compuesto no parta. El tamaño no lo dice;
    /// esto deja el archivo para mirarlo, y afirma lo único afirmable sin ojos:
    /// que se generó y tiene una página.
    func testElNombreConEmojiYComillasNoRompeElDocumento() throws {
        XCTAssertEqual(try renderActa(nombreConBasura, como: "acta-emoji"), 1)
        XCTAssertEqual(try renderMembrete(nombreConBasura, como: "membrete-emoji"), 1)
    }

    /// **Lo que esta prueba NO cubre**, para que no se dé por cerrado el Z7:
    /// `ReporteHojaPDF`, `ReporteAnualHojaPDF`, `ReporteAportesHojaPDF` y
    /// `ConstanciaHojaPDF` piden `EstadoFinanciero`, `ReporteAnual`, `Aportante`
    /// y `[Aporte]`, que no tienen fixture en `pruebas/`. Los cuatro leen el
    /// nombre por la misma vía —`iglesia.membrete`, que es
    /// `nombre · ubicacionLegible` (`ConfiguracionIglesia:161`)—, así que el
    /// riesgo es el mismo; lo que falta es la medida. La constancia es la que
    /// más importa de las cuatro: es un documento fiscal que se entrega.
    func testLoQueFaltaPorMedirEstaApuntado() throws {
        XCTAssertEqual(ConfiguracionIglesia().membrete, "",
                       "un membrete sin configurar debe ser vacío, no un nombre inventado")
        var c = iglesia(nombre: "Iglesia Nueva Vida")
        c.ciudad = "Monterrey"
        XCTAssertTrue(c.membrete.contains("Iglesia Nueva Vida"),
                      "el membrete de los reportes sale del nombre: misma vía, mismo riesgo")
    }

    // MARK: - La alineación del membrete, medida en los píxeles

    /// **Un `VStack(alignment: .center)` centra las VISTAS, no las LÍNEAS.**
    /// Un `Text` que envuelve ocupa todo el ancho del contenedor y pinta su
    /// texto alineado a la izquierda, así que el nombre salía en bandera
    /// mientras la ciudad —una línea— seguía centrada: dos alineaciones en el
    /// mismo membrete. Con un nombre corto no se ve, porque cabe en una línea.
    ///
    /// Se mide en el PDF renderizado y no leyendo el código: con texto CENTRADO
    /// el filo izquierdo de cada LÍNEA es distinto —cada una entra lo que le
    /// sobra—, y alineado a la izquierda todas empiezan en el mismo píxel.
    ///
    /// **Y esto costó un control positivo, que es la razón de que esté
    /// escrito así.** La primera versión medía la dispersión de los filos de
    /// todas las FILAS del tercio superior de la hoja, y pasaba en verde con el
    /// arreglo puesto Y quitado: en esa banda también están el divisor —que
    /// cruza la página entera— y las cuatro barras grises del hueco del
    /// documento, y esos dos solos daban 562 px de dispersión contra un umbral
    /// de 20. Medía el marco de la hoja y no el texto. Por eso ahora se
    /// recortan las filas por debajo del DIVISOR, se agrupan en líneas, y se
    /// descarta la última —la ciudad, que al ser de una sola línea sale
    /// centrada en los dos casos y metería dispersión falsa—.
    ///
    /// Es la lección del §0.-10 en el eje horizontal: un volcado señala
    /// candidatos, y quien confirma es una medida que se ha visto fallar.
    private struct Membrete {
        /// El filo izquierdo de cada línea del NOMBRE, en píxeles.
        let filosPorLinea: [Int]
        /// Cuántas líneas tiene el nombre.
        var lineas: Int { filosPorLinea.count }
        /// **La racha más larga de líneas que arrancan en el MISMO píxel
        /// (±2).** Es la medida buena, y la dispersión no lo era: un membrete
        /// lleva a la vez texto centrado y elementos alineados al margen —las
        /// barras grises del hueco, el divisor—, así que la dispersión del
        /// conjunto sale alta pase lo que pase. Un párrafo en bandera, en
        /// cambio, deja una racha tan larga como líneas tenga, y eso no lo
        /// imita ningún otro elemento.
        var racha: Int {
            // **El ancla es opcional y no `Int.min`.** Con `Int.min`,
            // `abs(f - ancla)` desborda y Swift lo trata como error fatal: el
            // proceso de pruebas muere y xcodebuild lo cuenta como
            // «Executed 0 tests», que es indistinguible de un `-only-testing`
            // que no casa con nada. Dos vueltas buscándolo en el bitmap.
            var mejor = 0, actual = 0
            var ancla: Int?
            for f in filosPorLinea {
                if let a = ancla, abs(f - a) <= 2 {
                    actual += 1
                } else {
                    ancla = f; actual = 1
                }
                mejor = max(mejor, actual)
            }
            return mejor
        }
    }

    private func medirMembrete(_ url: URL) throws -> Membrete {
        let doc = try XCTUnwrap(PDFDocument(url: url))
        let pagina = try XCTUnwrap(doc.page(at: 0))
        let caja = pagina.bounds(for: .mediaBox)
        let escala: CGFloat = 2
        let ancho = Int(caja.width * escala), alto = Int(caja.height * escala)

        // **La memoria se asigna a mano y no con `&unArray`.** La primera
        // versión hacía `CGContext(data: &pixeles, ...)` sobre un `[UInt8]`, y
        // eso es comportamiento indefinido: Swift no garantiza que ese puntero
        // siga siendo válido después de la llamada, y el contexto escribe en él
        // más tarde, durante `pagina.draw`. Funcionó tres corridas y a la
        // cuarta se llevó el proceso de pruebas por delante —y el síntoma fue
        // «Executed 0 tests» con la prueba marcada como fallida, que no dice
        // nada de una caída—.
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: ancho * alto)
        defer { bytes.deallocate() }
        bytes.initialize(repeating: 255, count: ancho * alto)

        let ctx = try XCTUnwrap(CGContext(
            data: bytes, width: ancho, height: alto, bitsPerComponent: 8,
            bytesPerRow: ancho, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: ancho, height: alto))
        ctx.scaleBy(x: escala, y: escala)
        pagina.draw(with: .mediaBox, to: ctx)
        let pixeles = UnsafeBufferPointer(start: bytes, count: ancho * alto)

        // Por fila: el filo izquierdo de la tinta y cuánta anchura cubre.
        // OJO: el bitmap de CoreGraphics va de ABAJO hacia arriba, así que la
        // fila 0 es el PIE de la hoja. Se recorre al revés.
        func filaDeArriba(_ i: Int) -> Int { alto - 1 - i }
        var filos = [Int](repeating: -1, count: alto)
        for i in 0..<alto {
            let y = filaDeArriba(i)
            var primero = -1
            for x in 0..<ancho where pixeles[y * ancho + x] < 140 { primero = x; break }
            filos[i] = primero
        }

        // Se agrupan TODAS las filas con tinta en líneas y se queda el filo de
        // cada una. No hace falta recortar por el divisor ni descartar la
        // ciudad: la racha aísla el párrafo sola. El primer intento sí
        // recortaba, y la detección del divisor falló —es gris claro y no
        // llegaba al umbral de tinta—, lo que dejó la prueba afirmando
        // `1584 < 1584`.
        var lineas: [Int] = []
        var enLinea = false, filoDeLaLinea = Int.max
        for i in 0..<alto {
            if filos[i] >= 0 {
                enLinea = true
                filoDeLaLinea = min(filoDeLaLinea, filos[i])
            } else if enLinea {
                lineas.append(filoDeLaLinea)
                enLinea = false; filoDeLaLinea = Int.max
            }
        }
        if enLinea { lineas.append(filoDeLaLinea) }
        return Membrete(filosPorLinea: lineas)
    }

    func testElMembreteLargoSaleCENTRADOyNoEnBanderaALaIzquierda() throws {
        let url = try XCTUnwrap(PDFExport.render(
            MembreteHojaPDF(iglesia: iglesia(nombre: nombreLarguisimo)),
            nombre: "bruto-alineacion"))
        let m = try medirMembrete(url)
        print("QA-ALINEACION: lineas=\(m.lineas) · racha=\(m.racha) · " +
              "filos=\(m.filosPorLinea)")

        // Control de la MEDIDA, no del producto: sin varias líneas no hay
        // alineación que medir, y un nombre de 500 caracteres tiene que darlas.
        XCTAssertGreaterThan(m.lineas, 4,
                             "el nombre largo no envolvió: la medida no aplica")

        // **Medido con control positivo, 12-sep, en el iPhone.** Sin el
        // arreglo: racha de 10 sobre 14 líneas, con los filos del nombre
        // clavados en 97-98 px. Con el arreglo puesto la racha baja, porque
        // cada línea centrada entra lo que le sobra. El umbral es 4 y no 2
        // para dejar sitio a que dos líneas del párrafo salgan casi iguales
        // por casualidad.
        XCTAssertLessThan(m.racha, 4, """
            \(m.racha) líneas seguidas del membrete arrancan en el mismo \
            píxel (filos \(m.filosPorLinea)): el nombre sale en bandera a la \
            izquierda aunque su `VStack` sea `.center`. Falta \
            `.multilineTextAlignment(.center)` en el CONTENEDOR — ponerlo \
            `Text` a `Text` deja fuera el renglón siguiente que se añada ahí.
            """)
    }
}
