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
    /// Dirección del dinero. Cuando se da, la cifra sale con signo y con el
    /// color que le corresponde ("+$1,200.00" verde, "−$3,410.50" rojo), la
    /// misma regla que las listas: antes el detalle de un gasto mostraba
    /// "$3,410.50" en negro y el Dashboard ese mismo dato en rojo.
    var ingreso: Bool? = nil

    var body: some View {
        let texto = ingreso.map { Money.firmado(cents, ingreso: $0) } ?? Money.fmt(cents)
        let color = ingreso.map { Money.color(ingreso: $0) } ?? self.color
        // Money.fmt siempre trae dos decimales tras un punto.
        let partes = texto.split(separator: ".", maxSplits: 1).map(String.init)
        let entero = partes.first ?? texto
        let centavos = partes.count > 1 ? partes[1] : nil

        // Los dos Text son UNO solo, compuesto por interpolación: así
        // `minimumScaleFactor` escala toda la cifra como una unidad y nunca la
        // trunca a "$1…". Antes se concatenaban con `+`, que iOS 26 deprecó a
        // favor de esto mismo.
        let parteEntera = Text(entero)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color)
        let vista: Text
        if let centavos {
            let decimales = Text("." + centavos)
                .font(.system(size: size * 0.62, weight: .semibold, design: .rounded))
                .foregroundStyle(color == .primary ? AnyShapeStyle(.secondary) : AnyShapeStyle(color.opacity(0.7)))
            vista = Text("\(parteEntera)\(decimales)")
        } else {
            vista = parteEntera
        }
        return vista
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
