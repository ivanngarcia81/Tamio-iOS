import Foundation

/// **Un solo formato de fecha para las vistas de detalle.** El detalle de
/// aprobación mostraba "Aug 30, 2026" y el de transacción "September 3, 2026,
/// 12:05": el mismo tipo de dato con dos formatos distintos según la pantalla.
/// Aquí vive el único, y sigue al idioma de la APP (`L.locale`), no al del
/// dispositivo: con el iPhone en español y la app en inglés, `Locale.current`
/// escribía los meses en español dentro de una pantalla traducida.
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

    /// El intervalo de un periodo del Dashboard. `hace: 1` devuelve el mismo
    /// periodo inmediatamente anterior, que es contra el que se compara para
    /// dar la variación.
    static func intervalo(_ periodo: Periodo, hace periodos: Int = 0,
                          desde hoy: Date = Date()) -> Range<Date> {
        let cal = Calendar.current
        switch periodo {
        case .mes:
            let inicio = cal.date(byAdding: .month, value: -periodos, to: inicioDeMes(hoy)) ?? hoy
            return inicio ..< (cal.date(byAdding: .month, value: 1, to: inicio) ?? inicio)
        case .trimestre:
            // El trimestre acaba al final del mes en curso, no en el trimestre
            // natural: es "los últimos tres meses", que es lo que se consulta.
            let fin = cal.date(byAdding: .month, value: 1 - periodos * 3,
                               to: inicioDeMes(hoy)) ?? hoy
            return (cal.date(byAdding: .month, value: -3, to: fin) ?? fin) ..< fin
        case .anio:
            let anio = cal.component(.year, from: hoy) - periodos
            let inicio = cal.date(from: DateComponents(year: anio, month: 1, day: 1)) ?? hoy
            let fin = cal.date(from: DateComponents(year: anio + 1, month: 1, day: 1)) ?? hoy
            return inicio ..< fin
        }
    }

    /// Días naturales que faltan para el corte de mes. Hoy el corte es el
    /// último día del mes natural; el día en que Ajustes deje configurar otro
    /// (muchas iglesias cierran el último domingo), este es el único sitio que
    /// hay que tocar.
    static func diasParaCorteDeMes(desde hoy: Date = Date()) -> Int {
        let cal = Calendar.current
        let dia = cal.startOfDay(for: hoy)
        guard let rango = cal.range(of: .day, in: .month, for: dia) else { return 0 }
        return max(0, (rango.upperBound - 1) - cal.component(.day, from: dia))
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

    private static func fmt(_ formato: String) -> DateFormatter { L.formateador(formato) }

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

    // MARK: - Periodo contable

    /// **La clave de un periodo contable: `"2026-08"`.**
    ///
    /// Es un CONTRATO, no un texto para leer: viaja a
    /// `depositos_bancarios.periodo` y es con lo que la app web agrupa el
    /// estado financiero (`substr(fecha, 1, 7)`). Por eso va en
    /// `en_US_POSIX`, como el resto de formateadores de la capa de datos.
    ///
    /// Antes el periodo se guardaba escrito —"Agosto 2026"—, así que un
    /// depósito registrado desde el iPhone no lo encontraba ninguna consulta
    /// de la web, y el mismo depósito quedaba con una clave distinta según el
    /// idioma en que estuviera el teléfono al registrarlo.
    static func clavePeriodo(_ d: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: d)
    }

    /// La clave de vuelta a `Date` (el día 1 de ese mes). `nil` si no es una
    /// clave: sirve para distinguir lo ya migrado de lo que sigue escrito.
    static func fechaDePeriodo(_ clave: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.date(from: clave)
    }

    /// `"2026-08"` → `"Agosto 2026"` · `"August 2026"`. Lo que se ENSEÑA.
    /// Si le llega algo que no es una clave lo devuelve tal cual: los datos
    /// viejos siguen siendo legibles mientras no se migran.
    static func periodoLegible(_ clave: String) -> String {
        guard let d = fechaDePeriodo(clave) else { return clave }
        let s = L.formateador("LLLL yyyy").string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// Traduce un periodo escrito a su clave. Reconoce los dos idiomas por la
    /// misma tabla de meses que lee la semilla, así que "Agosto 2026" y
    /// "August 2026" caen los dos en `"2026-08"`.
    static func claveDePeriodoEscrito(_ texto: String) -> String? {
        if fechaDePeriodo(texto) != nil { return texto }
        let piezas = texto.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        var mes: Int?, anio: Int?
        for pieza in piezas {
            if let m = meses[String(pieza.prefix(3))], mes == nil { mes = m }
            else if let n = Int(pieza), n > 1900 { anio = n }
        }
        guard let mes, let anio else { return nil }
        return String(format: "%04d-%02d", anio, mes)
    }
}
