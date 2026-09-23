import XCTest
import CoreGraphics
@testable import Tamio

/// **Que el PDF de Secretaría exista y tenga páginas.**
///
/// Hasta el 7 de septiembre de 2026 no se generaba ninguno: el botón de
/// compartir de una carta era `// Compartir — placeholder` y el pie del
/// formulario del acta prometía un PDF que no existía. Estas pruebas son la
/// red que impide volver ahí sin enterarse: no miran cómo queda el documento
/// —eso solo lo dice verlo (`pruebas/DocumentosPDFUITests.swift`)— sino que
/// `PDFExport.render` devuelve un archivo con algo dentro.
@MainActor
final class DocumentosPDFTests: XCTestCase {

    private func iglesia() -> ConfiguracionIglesia {
        var c = ConfiguracionIglesia()
        c.nombre = "Iglesia Nueva Vida"
        c.ciudad = "Monterrey"
        c.pastorNombre = "Samuel Ruvalcaba"
        c.secretarioNombre = "Lucía Márquez"
        return c
    }

    private func pesa(_ url: URL?) throws -> Int {
        let url = try XCTUnwrap(url, "### PDFExport devolvió nil: no se generó el archivo")
        let datos = try Data(contentsOf: url)
        return datos.count
    }

    func testLaCartaGeneraUnPDF() throws {
        var carta = CartaEnEdicion()
        carta.aportante = "Ana Lucía Torres"
        carta.iglesiaDestino = "Iglesia Betel"
        carta.miembroDesde = "2019"
        carta.firma = "Samuel Ruvalcaba"

        let url = PDFExport.render(
            CartaHojaPDF(carta: carta, tipo: .recomendacion,
                         cuerpo: "Por medio de la presente recomendamos a Ana Lucía Torres.",
                         iglesia: iglesia()),
            nombre: "prueba-carta")
        XCTAssertGreaterThan(try pesa(url), 1000, "### el PDF salió vacío")
    }

    func testElActaGeneraUnPDF() throws {
        var acta = Acta(id: "a1", folio: "2026-08", tipo: .lideres,
                        fecha: "2026-08-21", estado: .aprobada,
                        items: [AcuerdoActa(id: 1, texto: "Se aprueba el estado financiero de julio.")])
        acta.lugar = "el salón anexo"
        acta.preside = "Pastor Abel Ramos"
        acta.secretario = "María Hernández Ríos"
        acta.presentes = ["Pastor Abel Ramos", "María Hernández Ríos"]
        acta.quorum = true

        let url = PDFExport.render(ActaHojaPDF(acta: acta, iglesia: iglesia()),
                                   nombre: "prueba-acta")
        XCTAssertGreaterThan(try pesa(url), 1000, "### el PDF salió vacío")
    }

    /// El membrete a solas, que es lo que enseña Ajustes · Institución. La fila
    /// llevaba desde siempre en "Próximamente" y no hacía falta inventar nada:
    /// se arma con las mismas piezas que los documentos de verdad.
    func testElMembreteGeneraUnPDF() throws {
        let url = PDFExport.render(MembreteHojaPDF(iglesia: iglesia()), nombre: "prueba-membrete")
        XCTAssertGreaterThan(try pesa(url), 1000, "### el PDF salió vacío")
    }

    /// La fecha que encabeza una carta. Estaba escrita a mano en dos sitios
    /// —"20 de agosto de 2026" en la previa del detalle— y calculada como "hoy"
    /// en un tercero; ninguna de las tres era la que la carta dice llevar.
    func testLaFechaDelDocumentoEsLaDeEmision() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 7
        let fecha = Calendar.current.date(from: comps)!
        let texto = Fechas.diaLegibleLargo(fecha)
        XCTAssertTrue(texto.contains("2026"), texto)
        XCTAssertTrue(texto.contains("7"), texto)
        XCTAssertFalse(texto.contains("agosto"), "### \(texto): no es la fecha que se le dio")
    }

    // MARK: - Hoja de culto y corte (23-sep)

    /// Deja una copia del PDF donde diga `TAMIO_PDF_DIR` para poder MIRARLO:
    /// que el archivo pese más de 1 KB no dice si la hoja se ve bien. En el
    /// simulador la ruta es del Mac, así que se abre sin sacar nada del aparato.
    private func guardarCopia(_ url: URL?, _ nombre: String) {
        guard let url, let dir = ProcessInfo.processInfo.environment["TAMIO_PDF_DIR"] else { return }
        let destino = URL(fileURLWithPath: dir).appendingPathComponent(nombre + ".pdf")
        try? FileManager.default.removeItem(at: destino)
        try? FileManager.default.copyItem(at: url, to: destino)
    }

    private func paginas(_ url: URL?) -> Int {
        guard let url, let doc = CGPDFDocument(url as CFURL) else { return 0 }
        return doc.numberOfPages
    }

    private func cultoLleno() -> Servicio {
        var s = Servicio(id: "s1")
        s.fecha = "2026-09-21"
        s.tipo = "dominical"
        s.dirige = "José Villarreal"
        s.predica = "Samuel Ríos"
        s.tituloMensaje = "La luz vino al mundo"
        s.textoBiblico = "Juan 3:16-21"
        s.resumenMensaje = String(repeating: "Nicodemo llega de noche y Jesús le habla de la luz. No se trata de ver más, sino de dejarse ver. ", count: 5)
        s.temaEscuela = "Oración en los salmos de lamento"
        s.maestroEscuela = "Rosa Medina Cantú"
        s.orden = (0..<12).map { i in
            PuntoOrden(id: "o\(i)", posicion: i, hora: String(format: "10:%02d", i * 5),
                       titulo: "Punto del culto número \(i + 1)", encargado: "Encargado \(i + 1)")
        }
        s.puestos = [
            PuestoServicio(id: "p1", puesto: "predicacion", nombre: "Samuel Ríos", miembroId: nil),
            PuestoServicio(id: "p2", puesto: "alabanza", nombre: "Lucía Torres Beltrán", miembroId: nil),
            PuestoServicio(id: "p3", puesto: "oracion", nombre: "", miembroId: nil),
        ]
        s.participaciones = ["Coro de jóvenes", "Pedro Salinas"]
        s.visitantes = (0..<6).map { i in
            VisitanteServicio(nombre: "Visitante \(i + 1)", telefono: "81 0000 000\(i)",
                              correo: "no-debe-salir@correo.mx", invitadoPor: "Ana Gómez Ruiz",
                              primeraVisita: i < 4, notas: nil)
        }
        s.adultos = 142; s.jovenes = 38; s.ninos = 27
        s.eventos = "Se presentó al niño Mateo. Se anunció la reunión de diáconos del lunes."
        return s
    }

    func testLaHojaDeCultoLlenaSaleEnVariasPaginas() throws {
        let hoja = HojaCultoPDF(servicio: cultoLleno(), iglesia: iglesia())
        let url = PDFExport.render(hoja, nombre: "prueba-culto-lleno")
        guardarCopia(url, "culto-lleno")
        XCTAssertGreaterThan(try pesa(url), 1000, "### el PDF salió vacío")
        XCTAssertEqual(paginas(url), hoja.numeroDePaginas,
                       "### el PDF no tiene las páginas que la hoja dice componer: se partió a mitad")
        XCTAssertGreaterThanOrEqual(hoja.numeroDePaginas, 2, "### un dominical lleno cabe en una página: ¿se omitió algo?")
    }

    func testLaHojaDeCultoMinimaCabeEnUnaPagina() throws {
        var s = Servicio(id: "s2")
        s.fecha = "2026-09-24"; s.tipo = "oracion"; s.dirige = "Ana Gómez Ruiz"
        s.adultos = 16; s.jovenes = 5; s.ninos = 2
        var sinLogo = iglesia(); sinLogo.logoPath = ""
        let hoja = HojaCultoPDF(servicio: s, iglesia: sinLogo)
        let url = PDFExport.render(hoja, nombre: "prueba-culto-minimo")
        guardarCopia(url, "culto-minimo")
        XCTAssertEqual(paginas(url), 1, "### una reunión de oración mínima no cabe en una página")
    }

    private func movimiento(_ i: Int, metodo: String = "Efectivo") -> Movimiento {
        Movimiento(id: "m\(i)", tipo: .ingreso, categoria: "diezmo", persona: "Aportante \(i)",
                   folio: "\(1040 + i)", metodo: metodo, monto: 12_345 * (i + 1), hora: "10:00",
                   fecha: Date(), registradoPor: "Iván García", miembro: nil,
                   categoriaCompleta: "diezmo", nota: nil, sinDepositar: true,
                   comprobante: nil, auditoria: [])
    }

    func testElCorteGeneraUnPDFConYSinConteo() throws {
        var corte = Corte(id: "corte-prueba-1", titulo: "Ofrendas del domingo",
                          descripcion: "", estado: .pendiente,
                          movimientos: (0..<5).map { movimiento($0, metodo: $0 == 4 ? "Cheque 8823" : "Efectivo") },
                          registro: RegistroDeposito(cuenta: "BBVA 0123", fecha: "2026-09-21", periodo: "Septiembre 2026"))
        corte.registradoPor = "Iván García"
        let sin = PDFExport.render(CorteHojaPDF(corte: corte, iglesia: iglesia()), nombre: "prueba-corte-sin")
        guardarCopia(sin, "corte-sin-conteo")
        XCTAssertGreaterThan(try pesa(sin), 1000, "### el PDF del corte salió vacío")

        corte.dobleFirmaPedida = true
        corte.segundaFirma = "Carlos Ruiz Peña"
        corte.segundaFirmaRol = "Asistente"
        corte.segundaConteo = 50_000
        let con = PDFExport.render(CorteHojaPDF(corte: corte, iglesia: iglesia()), nombre: "prueba-corte-con")
        guardarCopia(con, "corte-con-conteo")
        XCTAssertGreaterThan(try pesa(con), 1000, "### el PDF del corte con conteo salió vacío")
    }
}
