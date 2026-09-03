import SwiftUI

/// Coloca sus vistas en fila y las va **bajando de línea** cuando no caben, en
/// vez de recortarlas o hacer scroll horizontal. Ideal para chips de filtro:
/// en un iPad ancho quedan en una línea; en uno angosto se acomodan en dos.
///
/// **Las dos pasadas comparten una sola rutina** (`filas(_:ancho:)`). Antes
/// cada una repetía el cálculo de corte por su cuenta —`sizeThatFits` contra
/// `proposal.width`, `placeSubviews` contra `bounds.maxX`—, así que cuando esos
/// dos anchos no coincidían, la altura medida describía menos líneas de las que
/// se acababan colocando y la última quedaba recortada. Ahora no pueden
/// discrepar: el mismo reparto se mide y se coloca.
///
/// `sizeThatFits` devuelve además el ancho **realmente ocupado**, no el
/// propuesto: antes devolvía siempre el propuesto completo, con lo que el padre
/// no tenía forma de ajustarse a un contenido más angosto.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    /// Una línea del reparto: los índices que le tocan y su alto.
    private struct Fila {
        var indices: [Int] = []
        var ancho: CGFloat = 0      // ancho ocupado, sin spacing sobrante
        var alto: CGFloat = 0
    }

    /// Reparte las vistas en líneas para un ancho dado. Única fuente del corte.
    private func filas(_ subviews: Subviews, ancho: CGFloat) -> [Fila] {
        var resultado: [Fila] = []
        var actual = Fila()
        for (i, sub) in subviews.enumerated() {
            let t = sub.sizeThatFits(.unspecified)
            // Dónde empezaría esta vista en la línea actual.
            let inicio = actual.indices.isEmpty ? 0 : actual.ancho + spacing
            if inicio + t.width > ancho, !actual.indices.isEmpty {
                resultado.append(actual)
                actual = Fila()
            }
            let x = actual.indices.isEmpty ? 0 : actual.ancho + spacing
            actual.indices.append(i)
            actual.ancho = x + t.width
            actual.alto = max(actual.alto, t.height)
        }
        if !actual.indices.isEmpty { resultado.append(actual) }
        return resultado
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let disponible = proposal.width ?? .infinity
        let lineas = filas(subviews, ancho: disponible)
        let ocupado = lineas.map(\.ancho).max() ?? 0
        let alto = lineas.map(\.alto).reduce(0, +)
            + lineSpacing * CGFloat(max(0, lineas.count - 1))
        return CGSize(width: disponible.isFinite ? min(ocupado, disponible) : ocupado,
                      height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        // El reparto se calcula con el ancho real del bounds, y `sizeThatFits`
        // ya midió con el mismo criterio, así que las líneas coinciden.
        var y = bounds.minY
        for fila in filas(subviews, ancho: bounds.width) {
            var x = bounds.minX
            for i in fila.indices {
                let t = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                  proposal: ProposedViewSize(width: t.width, height: t.height))
                x += t.width + spacing
            }
            y += fila.alto + lineSpacing
        }
    }
}
