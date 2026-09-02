import SwiftUI
import UIKit

/// Convierte una vista SwiftUI en un PDF tamaño carta y devuelve su URL temporal.
/// Se usa para "Vista previa PDF" y "Compartir" de los reportes. Cuando entre el
/// motor, la vista imprimible se alimenta de los mismos datos: esto no cambia.
enum PDFExport {
    /// Ancho de página carta en puntos (8.5" × 72). La altura la fija el contenido.
    static let anchoCarta: CGFloat = 612

    @MainActor
    static func render(_ contenido: some View, nombre: String) -> URL? {
        let renderer = ImageRenderer(content: contenido.frame(width: anchoCarta))
        renderer.proposedSize = .init(width: anchoCarta, height: nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(nombre).pdf")
        var ok = false
        renderer.render { size, dibujar in
            var caja = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let ctx = CGContext(url as CFURL, mediaBox: &caja, nil) else { return }
            ctx.beginPDFPage(nil)
            dibujar(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}
