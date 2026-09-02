import SwiftUI

/// Coloca sus vistas en fila y las va **bajando de línea** cuando no caben, en
/// vez de recortarlas o hacer scroll horizontal. Ideal para chips de filtro:
/// en un iPad ancho quedan en una línea; en uno angosto se acomodan en dos.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let ancho = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alto: CGFloat = 0, lineAlto: CGFloat = 0
        for sub in subviews {
            let t = sub.sizeThatFits(.unspecified)
            if x + t.width > ancho, x > 0 {
                x = 0
                y += lineAlto + lineSpacing
                lineAlto = 0
            }
            x += t.width + spacing
            lineAlto = max(lineAlto, t.height)
            alto = y + lineAlto
        }
        return CGSize(width: ancho == .infinity ? x : ancho, height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, lineAlto: CGFloat = 0
        for sub in subviews {
            let t = sub.sizeThatFits(.unspecified)
            if x + t.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineAlto + lineSpacing
                lineAlto = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                      proposal: ProposedViewSize(width: t.width, height: t.height))
            x += t.width + spacing
            lineAlto = max(lineAlto, t.height)
        }
    }
}
