import Foundation

/// Localización mínima para el prototipo. La app real es bilingüe ES/EN con
/// paridad de claves verificada por el compilador (`src/i18n/`); cuando el
/// slice crezca esto se sustituye por `Localizable.xcstrings` (String Catalog),
/// que da la misma garantía en Swift. De momento un par ES/EN inline basta para
/// ver el Dashboard en los dos idiomas sin montar toda la infraestructura.
enum L {
    /// true si el sistema NO está en inglés → mostramos español (idioma base).
    static var esEspanol: Bool {
        Locale.current.language.languageCode?.identifier != "en"
    }

    /// `L.t("Saldo en caja", "Cash on hand")`
    static func t(_ es: String, _ en: String) -> String {
        esEspanol ? es : en
    }

    /// Mes en curso escrito ("Septiembre 2026" · "September 2026"), para los
    /// subtítulos de los hubs. Iba a mano como "Agosto 2026" mientras Inicio
    /// leía la fecha real, así que Tesorería encabezaba un mes y Inicio otro.
    static var mesEnCurso: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "LLLL yyyy"
        let s = f.string(from: Date())
        return String(s.prefix(1)).uppercased() + String(s.dropFirst())
    }

    // MARK: - Semilla escrita en español

    /// Los datos semilla vienen del handoff con meses, días y fechas ya
    /// escritos en español ("14 mar 2026", "Abr", "DOM"). Con el sistema en
    /// inglés se colaban tal cual dentro de pantallas traducidas. Escribir un
    /// par `L.t` por cada uno serían decenas a mano —y ya se había olvidado
    /// más de uno—, así que se reescriben contra una tabla fija.
    ///
    /// La tabla es deliberada y no un `DateFormatter`: en español ICU abrevia
    /// septiembre como "sept", así que parsear "19 sep 2016" fallaría según la
    /// versión del sistema. Cuando la semilla pase a GRDB esto desaparece:
    /// allí las fechas serán `Date` y las formateará el sistema.

    private static let mesesCortos: [(String, String)] = [
        ("ene", "Jan"), ("feb", "Feb"), ("mar", "Mar"), ("abr", "Apr"),
        ("may", "May"), ("jun", "Jun"), ("jul", "Jul"), ("ago", "Aug"),
        ("sep", "Sep"), ("oct", "Oct"), ("nov", "Nov"), ("dic", "Dec"),
    ]

    private static let mesesLargos: [(String, String)] = [
        ("enero", "January"), ("febrero", "February"), ("marzo", "March"),
        ("abril", "April"), ("mayo", "May"), ("junio", "June"),
        ("julio", "July"), ("agosto", "August"), ("septiembre", "September"),
        ("octubre", "October"), ("noviembre", "November"), ("diciembre", "December"),
    ]

    private static let diasSemana: [(String, String)] = [
        ("dom", "Sun"), ("lun", "Mon"), ("mar", "Tue"), ("mié", "Wed"),
        ("mie", "Wed"), ("jue", "Thu"), ("vie", "Fri"), ("sáb", "Sat"), ("sab", "Sat"),
    ]

    /// Copia la forma de mayúsculas del original: "AGO" → "AUG", "Ago" → "Aug".
    private static func conFormaDe(_ original: String, _ traducido: String) -> String {
        let esMayusculas = original == original.uppercased() && original != original.lowercased()
        return esMayusculas ? traducido.uppercased() : traducido
    }

    private static func buscar(_ palabra: String, en tabla: [(String, String)]) -> String? {
        let clave = palabra.lowercased()
        guard let par = tabla.first(where: { $0.0 == clave }) else { return nil }
        return conFormaDe(palabra, par.1)
    }

    private static func traducirMes(_ palabra: String) -> String? {
        buscar(palabra, en: mesesLargos) ?? buscar(palabra, en: mesesCortos)
    }

    /// `"Abr"` → `"Apr"` · `"Junio"` → `"June"`.
    static func mes(_ es: String) -> String {
        guard !esEspanol else { return es }
        return traducirMes(es) ?? es
    }

    /// `"DOM"` → `"SUN"` · `"Mié"` → `"Wed"`.
    static func diaSemana(_ es: String) -> String {
        guard !esEspanol else { return es }
        return buscar(es, en: diasSemana) ?? es
    }

    /// `"14 mar 2026"` → `"Mar 14, 2026"` · `"16 ago"` → `"Aug 16"` ·
    /// `"Junio 2012"` → `"June 2012"`. Si no reconoce la forma la devuelve
    /// intacta, que es lo correcto para un folio o un monto.
    static func fecha(_ es: String) -> String {
        guard !esEspanol else { return es }
        let p = es.split(separator: " ").map(String.init)
        switch p.count {
        case 1:                                             // "Abr"
            return traducirMes(p[0]) ?? es
        case 2 where Int(p[0]) != nil:                      // "16 ago"
            guard let m = traducirMes(p[1]) else { return es }
            return "\(m) \(p[0])"
        case 2 where Int(p[1]) != nil:                      // "Junio 2012"
            guard let m = traducirMes(p[0]) else { return es }
            return "\(m) \(p[1])"
        case 3 where Int(p[0]) != nil && Int(p[2]) != nil:  // "14 mar 2026"
            guard let m = traducirMes(p[1]) else { return es }
            return "\(m) \(p[0]), \(p[2])"
        default:
            return es
        }
    }
}
