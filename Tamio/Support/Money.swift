import Foundation

/// El dinero se guarda y se opera en **centavos** (enteros), igual que en la
/// app actual (migración 36, `src/dinero.ts`). Nunca en coma flotante: sumar
/// $0.10 diez veces en `Double` no da $1.00, y en una tesorería eso no se
/// perdona. El formateo a texto es el único lugar donde se divide entre 100.
typealias Centavos = Int

enum Money {
    /// "$1,234.56" — importe con separador de miles y dos decimales. La moneda
    /// (MXN, USD…) se muestra aparte, como en el Dashboard actual, porque va en
    /// un color/tamaño distinto al de la cifra.
    static func fmt(_ cents: Centavos) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let value = Double(cents) / 100.0
        let cuerpo = f.string(from: NSNumber(value: value)) ?? "0.00"
        return "$" + cuerpo
    }

    /// "13k" · "1.4M" — etiqueta corta para los ejes de las gráficas, donde no
    /// cabe el importe entero. Espeja `tickCompacto` de `DashboardCharts.tsx`.
    static func compact(_ cents: Centavos) -> String {
        let n = Double(cents) / 100.0
        let abs = Swift.abs(n)
        if abs >= 1_000_000 {
            return String(format: abs >= 10_000_000 ? "%.0fM" : "%.1fM", n / 1_000_000)
        }
        if abs >= 1_000 {
            return String(format: abs >= 10_000 ? "%.0fk" : "%.1fk", n / 1_000)
        }
        return String(Int(n.rounded()))
    }
}
