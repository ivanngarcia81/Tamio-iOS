import XCTest
import SwiftUI
@testable import Tamio

/// **Un PDF de verdad: reporte, carta y acta**, con los datos y el membrete de
/// la iglesia que hay en el aparato — no con los de una maqueta.
///
/// `DocumentosPDFTests` ya comprueba que `PDFExport.render` devuelve un archivo
/// con páginas, y eso corre en cualquier sitio. Lo que faltaba del §0.-8 es
/// otra cosa: que con los datos REALES el documento salga y se pueda MIRAR.
/// Por eso cada PDF se copia a `Documents/`, que es de donde `devicectl` puede
/// sacarlo del aparato.
@MainActor
final class PDFDeVerdadTests: XCTestCase {

    private var destino: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Copia el PDF a `Documents/` e informa de su tamaño. Devuelve `false` si
    /// no se generó, sin cortar la prueba: interesa saber cuáles de los TRES
    /// salen, no pararse en el primero que no.
    @discardableResult
    private func guardar(_ url: URL?, como nombre: String) -> Bool {
        guard let url, let datos = try? Data(contentsOf: url) else {
            print("QA-PDF:\(nombre):NO-SE-GENERO")
            return false
        }
        let fin = destino.appendingPathComponent("\(nombre).pdf")
        try? FileManager.default.removeItem(at: fin)
        do { try datos.write(to: fin) } catch {
            print("QA-PDF:\(nombre):NO-SE-PUDO-COPIAR:\(error)")
            return false
        }
        print("QA-PDF:\(nombre):\(datos.count)")
        return true
    }

    /// **Sincronizar ANTES de mirar.** Estas tres pruebas fallaron el
    /// 11-sep-2026 con «no hay ningún acta» y «no hay ningún periodo contable»
    /// sobre un aparato que tenía 7 actas y 40 movimientos en su base local: la
    /// sincronización es asíncrona y arranca con la app, así que medían una base
    /// que todavía no había bajado nada. El fallo era de la prueba, no del
    /// producto — y perseguirlo hasta la consulta costó tres vueltas.
    override func setUp() async throws {
        await MotorSincronizacion.compartido.sincronizar(reintentarLoAtascado: false)
    }

    func testElReporteDelMesConDatosDeVerdad() async throws {
        let repo = repositorioReportes()
        let periodos = await repo.periodos()
        print("QA-PERIODOS:\(periodos.map(\.clave).joined(separator: ","))")
        let clave = try XCTUnwrap(periodos.first?.clave,
                                  "no hay ningún periodo contable en el aparato")

        let calculado = await repo.estadoFinanciero(periodo: clave, categoria: nil)
        let estado = try XCTUnwrap(calculado,
                                   "el estado financiero salió nil con datos reales")
        print("QA-REPORTE-PERIODO:\(clave)")

        let ok = guardar(PDFExport.render(ReporteHojaPDF(e: estado), nombre: "qa-reporte"),
                         como: "qa-reporte")
        XCTAssertTrue(ok, "### el reporte del mes no generó PDF con datos reales")
    }

    func testElActaConDatosDeVerdad() async throws {
        let actas = try await repositorioActas().lista()
        print("QA-ACTAS:\(actas.count)")
        let acta = try XCTUnwrap(actas.first, "no hay ningún acta en el aparato")
        print("QA-ACTA-FOLIO:\(acta.folio)")

        let ok = guardar(PDFExport.render(ActaHojaPDF(acta: acta), nombre: "qa-acta"),
                         como: "qa-acta")
        XCTAssertTrue(ok, "### el acta no generó PDF con datos reales")
    }

    func testLaCartaConElMembreteDeVerdad() throws {
        let iglesia = ConfiguracionIglesiaViewModel.compartido.config
        print("QA-IGLESIA:\(iglesia.nombre)|\(iglesia.ciudad)|pastor=\(iglesia.pastorNombre)")

        var carta = CartaEnEdicion()
        carta.aportante = "Prueba de aparato"
        carta.iglesiaDestino = "Iglesia Betel"
        carta.miembroDesde = "2019"
        carta.firma = iglesia.pastorNombre

        let ok = guardar(
            PDFExport.render(CartaHojaPDF(carta: carta, tipo: .recomendacion,
                                          cuerpo: "Por medio de la presente recomendamos a la persona referida.",
                                          iglesia: iglesia),
                             nombre: "qa-carta"),
            como: "qa-carta")
        XCTAssertTrue(ok, "### la carta no generó PDF con el membrete real")
    }
}
