import XCTest
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
}
