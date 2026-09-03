import SwiftUI
import Charts

/// "Ingresos y gastos por mes": barras agrupadas verde/rojo por mes, con la
/// leyenda arriba a la derecha. Gráfica nativa con Swift Charts.
struct MonthlyBarChart: View {
    let tramos: [MesResumen]

    private struct Punto: Identifiable {
        let id = UUID()
        let mes: String
        let serie: String
        let monto: Centavos
    }

    private var ingLabel: String { L.t("Ingresos", "Income") }
    private var gasLabel: String { L.t("Gastos", "Expenses") }

    private var puntos: [Punto] {
        tramos.flatMap { t in
            [Punto(mes: t.etiqueta, serie: ingLabel, monto: t.ingresos),
             Punto(mes: t.etiqueta, serie: gasLabel, monto: t.gastos)]
        }
    }

    private func leyendaPunto(_ texto: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(texto).font(.caption).foregroundStyle(.secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Título a la izquierda y la leyenda a la derecha, EN la cabecera —
            // como el handoff. Así la leyenda no se encima con las barras.
            HStack {
                Text(L.t("Ingresos y gastos por mes", "Income and expenses by month"))
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    leyendaPunto(ingLabel, Paleta.brand)
                    leyendaPunto(gasLabel, Paleta.negativo)
                }
            }

            Chart(puntos) { p in
                BarMark(
                    x: .value(L.t("Mes", "Month"), p.mes),
                    y: .value(L.t("Monto", "Amount"), p.monto)
                )
                .position(by: .value(L.t("Serie", "Series"), p.serie))
                .foregroundStyle(by: .value(L.t("Serie", "Series"), p.serie))
                .cornerRadius(4)
            }
            .chartForegroundStyleScale([
                ingLabel: Paleta.brand,
                gasLabel: Paleta.negativo,
            ])
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let cents = value.as(Int.self) { Text(Money.compact(cents)) }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 200)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 0.5)
        )
    }
}
