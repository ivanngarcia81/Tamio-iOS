import XCTest
@testable import Tamio

/// **Tres frases de pantalla que decían algo que no habían mirado.**
///
/// Las tres eran del mismo tipo y por eso van juntas: texto escrito a mano
/// donde tenía que haber un dato. El subtítulo de Actas nombraba un acta
/// concreta ("Acta 2026-08 en borrador") hubiera las que hubiera; bajo cada
/// borrador ponía "Guardado hace 2 minutos" tanto si se acababa de teclear como
/// si era de hace tres meses; y Reportes anunciaba "Próximamente · este reporte
/// llega en un próximo slice" en un sitio al que solo se llega mientras las
/// cifras cargan.
final class TextosQueMentianTests: XCTestCase {

    // MARK: - El subtítulo de Actas

    private func acta(_ id: String, folio: String, estado: EstadoActa) -> Acta {
        Acta(id: id, folio: folio, tipo: .lideres, fecha: "2026-08-21",
             estado: estado, items: [])
    }

    @MainActor
    private func vm(_ actas: [Acta]) -> ActasViewModel {
        let v = ActasViewModel()
        v.lista = actas
        return v
    }

    @MainActor
    func testUnBorradorSeNombraPorSuFolio() {
        let v = vm([acta("1", folio: "2026-09", estado: .borrador),
                    acta("2", folio: "2026-08", estado: .aprobada)])
        XCTAssertTrue(v.subtitulo.contains("2026-09"), v.subtitulo)
        XCTAssertFalse(v.subtitulo.contains("2026-08"),
                       "### nombró un acta que no está en borrador: \(v.subtitulo)")
    }

    @MainActor
    func testSinBorradoresSeCuentanLasActas() {
        let v = vm([acta("1", folio: "2026-09", estado: .aprobada),
                    acta("2", folio: "2026-08", estado: .cerrada)])
        XCTAssertTrue(v.subtitulo.contains("2"), v.subtitulo)
        XCTAssertFalse(v.subtitulo.lowercased().contains("borrador"), v.subtitulo)
        XCTAssertFalse(v.subtitulo.lowercased().contains("draft"), v.subtitulo)
    }

    @MainActor
    func testSinActasNoSeInventaNinguna() {
        let v = vm([])
        XCTAssertFalse(v.subtitulo.contains("2026"),
                       "### una iglesia sin actas leía el folio de una: \(v.subtitulo)")
    }

    // MARK: - "Guardado hace…"

    /// Sin fecha guardada no se dice nada: un hueco es más honesto que una hora
    /// inventada.
    func testSinFechaNoDiceNada() {
        XCTAssertNil(acta("1", folio: "2026-09", estado: .borrador).guardadoLegible)
    }

    func testLoRecienteVaEnRelativoYLoViejoConFecha() {
        let iso = ISO8601DateFormatter()
        var reciente = acta("1", folio: "2026-09", estado: .borrador)
        reciente.actualizadoEn = iso.string(from: Date().addingTimeInterval(-5 * 60))
        let textoReciente = try? XCTUnwrap(reciente.guardadoLegible)
        XCTAssertTrue(textoReciente?.contains("5") ?? false, textoReciente ?? "nil")

        var vieja = acta("2", folio: "2026-08", estado: .borrador)
        vieja.actualizadoEn = iso.string(from: Date().addingTimeInterval(-94 * 24 * 3600))
        let textoViejo = vieja.guardadoLegible ?? ""
        // "hace 94 días" no dice nada que la fecha no diga mejor.
        XCTAssertTrue(textoViejo.contains("2026"), textoViejo)
        XCTAssertFalse(textoViejo.contains("min"), textoViejo)
    }
}
