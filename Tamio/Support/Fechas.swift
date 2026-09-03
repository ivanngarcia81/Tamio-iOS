import Foundation

/// **Un solo formato de fecha para las vistas de detalle.** El detalle de
/// aprobación mostraba "Aug 30, 2026" y el de transacción "September 3, 2026,
/// 12:05": el mismo tipo de dato con dos formatos distintos según la pantalla.
/// Aquí vive el único, y sigue al idioma del sistema (`Locale.current`), como
/// el resto de la app desde que se quitaron los `es_MX` forzados.
enum Fechas {
    /// "28 ago 2026" · "Aug 28, 2026" — la forma de las filas de campo.
    static func corta(_ d: Date) -> String {
        fmt(L.t("d MMM yyyy", "MMM d, yyyy")).string(from: d)
    }

    /// "28 ago 2026, 12:05" · "Aug 28, 2026, 12:05" — forma corta con hora,
    /// para la fila "Fecha y hora" del detalle de transacción.
    static func cortaConHora(_ d: Date, hora: String) -> String {
        "\(corta(d)), \(hora)"
    }

    /// Primer día del mes de `d`, a medianoche: la clave con la que la lista
    /// de movimientos agrupa y compara meses.
    static func inicioDeMes(_ d: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
    }

    /// "Septiembre" · "September" dentro del año en curso, y "Septiembre 2025"
    /// fuera de él: en un historial de varios años el mes a secas es ambiguo.
    static func mes(_ d: Date) -> String {
        let cal = Calendar.current
        let mismoAnio = cal.component(.year, from: d) == cal.component(.year, from: Date())
        return fmt(mismoAnio ? "LLLL" : "LLLL yyyy").string(from: d).capitalized
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
    /// Interpreta las fechas que devuelve Supabase, que llegan en varios
    /// formatos según la columna: ISO completo, ISO sin zona, o solo el día.
    static func desdeTexto(_ texto: String?) -> Date? {
        guard let texto, !texto.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: texto) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: texto) { return d }
        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: texto) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        for formato in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            df.dateFormat = formato
            if let d = df.date(from: texto) { return d }
        }
        return nil
    }

    /// Fecha escrita por una persona o exportada por otro programa. Se prueba
    /// primero el ISO que genera la app y luego los formatos habituales de
    /// Excel. El día-primero va antes que el mes-primero: la app se usa en
    /// México y España, donde 03/09 es 3 de septiembre.
    static func desdeTextoFlexible(_ texto: String) -> Date? {
        if let d = desdeTexto(texto) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for formato in ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "MM/dd/yyyy", "yyyy/MM/dd"] {
            df.dateFormat = formato
            if let d = df.date(from: texto) { return d }
        }
        return nil
    }

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
