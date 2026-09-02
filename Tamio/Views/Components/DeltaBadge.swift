import SwiftUI

/// "▲ 4.2% vs julio" — la variación vs. el periodo anterior, con color de signo.
/// `invert` es para los gastos: que suban es malo, así que verde y rojo se
/// cambian. El color es una de las cifras que el diseño SÍ permite colorear.
struct DeltaBadge: View {
    let pct: Double?
    var sufijo: String = ""
    var invert: Bool = false

    var body: some View {
        if let pct {
            let sube = pct >= 0
            let bueno = invert ? !sube : sube
            HStack(spacing: 3) {
                Image(systemName: sube ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(String(format: "%.1f%%", abs(pct) * 100) + (sufijo.isEmpty ? "" : " " + sufijo))
            }
            .foregroundStyle(bueno ? Paleta.brand : Paleta.negativo)
        }
    }
}
