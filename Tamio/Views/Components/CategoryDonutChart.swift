import SwiftUI
import Charts

/// "Ingresos por categoría": dona con el total en el centro y una leyenda con
/// porcentajes a la derecha (Diezmos 52% · Ofrendas 22% · …). Ojo: el diseño
/// muestra INGRESOS, no gastos. `SectorMark` (iOS 17+) hace la dona nativa.
struct CategoryDonutChart: View {
    let categorias: [CategoriaMonto]
    let mesCorto: String   // "agosto" — va bajo el total, en el centro.

    private var total: Centavos { categorias.reduce(0) { $0 + $1.monto } }
    private func color(_ i: Int) -> Color { Paleta.donut[min(i, Paleta.donut.count - 1)] }
    private func pct(_ m: Centavos) -> Int {
        total > 0 ? Int((Double(m) / Double(total) * 100).rounded()) : 0
    }

    /// El centro de la dona: "$48.3k" (miles con un decimal), como el diseño.
    private var centroTexto: String {
        let unidad = Double(total) / 100.0
        if unidad >= 1_000 { return String(format: "$%.1fk", unidad / 1_000) }
        return "$" + String(Int(unidad.rounded()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("Ingresos por categoría", "Income by category"))
                .font(.headline)

            HStack(alignment: .center, spacing: 20) {
                Chart(Array(categorias.enumerated()), id: \.element.id) { i, cat in
                    SectorMark(
                        angle: .value(L.t("Monto", "Amount"), cat.monto),
                        innerRadius: .ratio(0.66),
                        angularInset: 1.5
                    )
                    .foregroundStyle(color(i))
                    .cornerRadius(3)
                }
                .frame(width: 130, height: 130)
                .overlay {
                    VStack(spacing: 0) {
                        Text(centroTexto)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                        Text(mesCorto)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(categorias.enumerated()), id: \.element.id) { i, cat in
                        HStack(spacing: 6) {
                            Circle().fill(color(i)).frame(width: 9, height: 9)
                            Text(cat.nombre).font(.subheadline).lineLimit(1).minimumScaleFactor(0.6)
                            Spacer(minLength: 6)
                            Text("\(pct(cat.monto))%")
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 0.5)
        )
    }
}
