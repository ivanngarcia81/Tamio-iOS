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
    /// el filo izquierdo de las líneas varía —la última, más corta, entra más—,
    /// y alineado a la izquierda es el mismo en todas. Es la misma técnica que
    /// `pruebas/contraste.py`, en el eje horizontal.
    private func filosIzquierdos(_ url: URL) throws -> [Int] {
        let doc = try XCTUnwrap(PDFDocument(url: url))
        let pagina = try XCTUnwrap(doc.page(at: 0))
        let caja = pagina.bounds(for: .mediaBox)
        let escala: CGFloat = 2
        let ancho = Int(caja.width * escala), alto = Int(caja.height * escala)
        var pixeles = [UInt8](repeating: 255, count: ancho * alto)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixeles, width: ancho, height: alto, bitsPerComponent: 8,
            bytesPerRow: ancho, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: ancho, height: alto))
        ctx.scaleBy(x: escala, y: escala)
        pagina.draw(with: .mediaBox, to: ctx)

        // El primer tercio de la hoja es donde vive el membrete.
        var filos: [Int] = []
        for y in 0..<(alto / 3) {
            var primero = -1
            for x in 0..<ancho where pixeles[y * ancho + x] < 128 { primero = x; break }
            if primero >= 0 { filos.append(primero) }
        }
        return filos
    }

    func testElMembreteLargoSaleCENTRADOyNoEnBanderaALaIzquierda() throws {
        let url = try XCTUnwrap(PDFExport.render(
            MembreteHojaPDF(iglesia: iglesia(nombre: nombreLarguisimo)),
            nombre: "bruto-alineacion"))
        let filos = try filosIzquierdos(url)
        try XCTSkipIf(filos.count < 40, "no se dibujó texto suficiente para medir")

        // Con el texto centrado los filos de las distintas líneas NO coinciden.
        let distintos = Set(filos).count
        let minimo = filos.min() ?? 0, maximo = filos.max() ?? 0
        print("QA-ALINEACION: filas con tinta=\(filos.count) · filos distintos=\(distintos) · " +
              "min=\(minimo) max=\(maximo) · dispersión=\(maximo - minimo)")

        XCTAssertGreaterThan(maximo - minimo, 20, """
            El nombre largo sale con el mismo filo izquierdo en todas sus \
            líneas (dispersión \(maximo - minimo) px): está en bandera a la \
            izquierda dentro de un membrete centrado. Falta \
            `.multilineTextAlignment(.center)` en el CONTENEDOR — ponerlo \
            `Text` a `Text` deja fuera el renglón siguiente que se añada.
            """)
    }
}
