import SwiftUI

/// **De qué aparato se trata**, para el rastro de auditoría. Iba escrito como
/// "iPad" en los dos sitios que lo escriben, así que capturar en un iPhone
/// dejaba un rastro que señalaba a otro dispositivo — y un rastro de auditoría
/// que miente sobre el aparato no sirve para lo que existe.
enum Dispositivo {
    static var nombre: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}

import SwiftUI
import UIKit

/// Convierte una vista SwiftUI en un PDF tamaño carta y devuelve su URL temporal.
/// Se usa para "Vista previa PDF" y "Compartir" de los reportes. Cuando entre el
/// motor, la vista imprimible se alimenta de los mismos datos: esto no cambia.
enum PDFExport {
    /// Ancho de página carta en puntos (8.5" × 72).
    static let anchoCarta: CGFloat = 612
    /// Alto de página carta (11" × 72). **Antes no existía**: el PDF se
    /// generaba como UNA página con la altura del contenido, así que un
    /// documento de tres pantallas salía como una tira de papel de metro y
    /// medio. En pantalla no se nota; al imprimirlo, sí.
    static let altoCarta: CGFloat = 792

    @MainActor
    static func render(_ contenido: some View, nombre: String) -> URL? {
        let renderer = ImageRenderer(content: contenido.frame(width: anchoCarta))
        renderer.proposedSize = .init(width: anchoCarta, height: nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(nombre).pdf")
        var ok = false
        renderer.render { size, dibujar in
            var caja = CGRect(x: 0, y: 0, width: anchoCarta, height: altoCarta)
            guard let ctx = CGContext(url as CFURL, mediaBox: &caja, nil) else { return }
            // **El contenido se reparte en páginas de tamaño carta.** El PDF va
            // en coordenadas con el origen abajo, así que la página 0 es la
            // banda MÁS ALTA del contenido: se desplaza el dibujo entero hacia
            // abajo y cada página enseña su franja. La última puede quedar con
            // blanco al pie, que es lo que hace cualquier documento.
            let paginas = max(1, Int(ceil(size.height / altoCarta)))
            for p in 0..<paginas {
                ctx.beginPDFPage(nil)
                ctx.saveGState()
                ctx.translateBy(x: 0, y: altoCarta * CGFloat(p + 1) - size.height)
                dibujar(ctx)
                ctx.restoreGState()
                ctx.endPDFPage()
            }
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}
