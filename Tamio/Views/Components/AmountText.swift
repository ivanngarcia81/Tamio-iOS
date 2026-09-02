import SwiftUI

/// Una cifra al estilo del diseño: la parte entera grande y en negro, y los
/// **centavos más pequeños y grises** ("$126,480" + ".25"). Es un detalle del
/// handoff que da jerarquía a los pesos sobre los centavos.
struct AmountText: View {
    let cents: Centavos
    var size: CGFloat = 28
    /// Color de la parte entera. Por defecto el negro/gris del sistema; se pasa
    /// verde o rojo solo cuando la cifra comunica signo (montos de movimientos).
    var color: Color = .primary

    var body: some View {
        let texto = Money.fmt(cents)
        // Money.fmt siempre trae dos decimales tras un punto.
        let partes = texto.split(separator: ".", maxSplits: 1).map(String.init)
        let entero = partes.first ?? texto
        let centavos = partes.count > 1 ? partes[1] : nil

        // Se CONCATENAN los dos Text en uno solo: así `minimumScaleFactor`
        // escala toda la cifra como una unidad y nunca la trunca a "$1…".
        var vista = Text(entero)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color)
        if let centavos {
            vista = vista + Text("." + centavos)
                .font(.system(size: size * 0.62, weight: .semibold, design: .rounded))
                .foregroundStyle(color == .primary ? AnyShapeStyle(.secondary) : AnyShapeStyle(color.opacity(0.7)))
        }
        return vista
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
