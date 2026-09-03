import SwiftUI

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

    /// Importe con la dirección del dinero al frente: "+$1,200.00" para un
    /// ingreso, "−$3,410.50" para un gasto. En una tesorería la dirección es lo
    /// primero que se escanea, así que va en TODAS las listas y detalles, no
    /// solo en el Dashboard: la lista de Gastos mostraba "$3,410.50" en negro
    /// mientras Inicio y Por revisar mostraban ese mismo dato en rojo y con
    /// signo. Menos tipográfico (U+2212), como ya usaba la semilla.
    static func firmado(_ cents: Centavos, ingreso: Bool) -> String {
        (ingreso ? "+" : "\u{2212}") + fmt(cents)
    }

    /// El color que acompaña a `firmado`. Verde entra, rojo sale.
    static func color(ingreso: Bool) -> Color {
        ingreso ? Paleta.brand : Paleta.negativo
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

extension Money {
    /// Lee un importe escrito por una persona o exportado por otro programa.
    ///
    /// Hay que aguantar los dos mundos: "1.960,00" (español) y "1,960.00"
    /// (inglés), con o sin separador de miles, con símbolo de moneda o sin él.
    /// La regla es simple: **manda el último separador que aparezca**, porque
    /// el decimal siempre va al final.
    static func desdeTexto(_ texto: String) -> Centavos? {
        var limpio = texto.trimmingCharacters(in: .whitespaces)
        limpio.removeAll { !"0123456789.,-".contains($0) }
        guard !limpio.isEmpty else { return nil }

        let ultimaComa = limpio.lastIndex(of: ",")
        let ultimoPunto = limpio.lastIndex(of: ".")

        var normalizado = limpio
        switch (ultimaComa, ultimoPunto) {
        case let (coma?, punto?):
            // Están los dos: el que va después es el decimal, el otro es miles.
            if coma > punto {
                normalizado = limpio.replacingOccurrences(of: ".", with: "")
                normalizado = normalizado.replacingOccurrences(of: ",", with: ".")
            } else {
                normalizado = limpio.replacingOccurrences(of: ",", with: "")
            }
        case (let coma?, nil):
            // Solo coma: es decimal si deja dos dígitos detrás ("19600,00"),
            // y separador de miles si deja tres ("19,600").
            let detras = limpio.distance(from: limpio.index(after: coma), to: limpio.endIndex)
            normalizado = detras == 3
                ? limpio.replacingOccurrences(of: ",", with: "")
                : limpio.replacingOccurrences(of: ",", with: ".")
        case (nil, let punto?):
            let detras = limpio.distance(from: limpio.index(after: punto), to: limpio.endIndex)
            if detras == 3 { normalizado = limpio.replacingOccurrences(of: ".", with: "") }
        case (nil, nil):
            break
        }

        guard let valor = Double(normalizado) else { return nil }
        return Int((valor * 100).rounded())
    }
}
