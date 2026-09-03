import Foundation

/// **Un solo formato de fecha para las vistas de detalle.** El detalle de
/// aprobación mostraba "Aug 30, 2026" y el de transacción "September 3, 2026,
/// 12:05": el mismo tipo de dato con dos formatos distintos según la pantalla.
/// Aquí vive el único, y sigue al idioma del sistema (`Locale.current`), como
/// el resto de la app desde que se quitaron los `es_MX` forzados.
enum Fechas {
    /// "3 de septiembre de 2026" · "September 3, 2026".
    static func detalle(_ d: Date) -> String {
        fmt(L.t("d 'de' MMMM 'de' yyyy", "MMMM d, yyyy")).string(from: d)
    }

    /// "3 de septiembre de 2026, 12:05" · "September 3, 2026, 12:05".
    static func detalleConHora(_ d: Date) -> String {
        fmt(L.t("d 'de' MMMM 'de' yyyy, HH:mm", "MMMM d, yyyy, HH:mm")).string(from: d)
    }

    /// "28 ago 2026" · "Aug 28, 2026" — forma corta, para campos y filas.
    static func corta(_ d: Date) -> String {
        fmt(L.t("d MMM yyyy", "MMM d, yyyy")).string(from: d)
    }

    private static func fmt(_ formato: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = formato
        return f
    }

    // MARK: - Lectura de la semilla

    /// Meses abreviados en los dos idiomas, para reconstruir un `Date` a partir
    /// de las cadenas de la semilla ("30 ago 2026", "Aug 30, 2026"). Tabla fija
    /// y no `DateFormatter` por lo mismo que en `L`: en español ICU abrevia
    /// septiembre como "sept" según la versión del sistema.
    private static let meses: [String: Int] = [
        "ene": 1, "jan": 1, "feb": 2, "mar": 3, "abr": 4, "apr": 4,
        "may": 5, "jun": 6, "jul": 7, "ago": 8, "aug": 8,
        "sep": 9, "oct": 10, "nov": 11, "dic": 12, "dec": 12,
    ]

    /// Convierte una fecha de la semilla en `Date`, en cualquiera de los dos
    /// órdenes ("30 ago 2026" o "Aug 30, 2026"). `nil` si no la reconoce.
    static func desdeSemilla(_ texto: String) -> Date? {
        let piezas = texto
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty }
        guard piezas.count >= 3 else { return nil }

        var dia: Int?, mes: Int?, anio: Int?
        for pieza in piezas {
            if let m = meses[String(pieza.prefix(3))], mes == nil {
                mes = m
            } else if let n = Int(pieza) {
                if n > 31 { anio = n } else if dia == nil { dia = n }
            }
        }
        guard let dia, let mes, let anio else { return nil }
        return Calendar.current.date(from: DateComponents(year: anio, month: mes, day: dia))
    }
}
