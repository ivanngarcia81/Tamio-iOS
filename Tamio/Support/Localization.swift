import Foundation

/// Localización mínima para el prototipo. La app real es bilingüe ES/EN con
/// paridad de claves verificada por el compilador (`src/i18n/`); cuando el
/// slice crezca esto se sustituye por `Localizable.xcstrings` (String Catalog),
/// que da la misma garantía en Swift. De momento un par ES/EN inline basta para
/// ver el Dashboard en los dos idiomas sin montar toda la infraestructura.
enum L {
    /// true si la app se enseña en español.
    ///
    /// Manda lo elegido en Ajustes → Preferencias; solo si está en
    /// "automático" se mira el sistema. Ese selector llevaba tiempo ahí
    /// —Español / English / Automático— sin estar conectado a nada: se movía y
    /// la app seguía en el idioma del teléfono.
    static var esEspanol: Bool {
        switch PreferenciasApp.idiomaGuardado {
        case .espanol: return true
        case .ingles:  return false
        case .automatico:
            return Locale.current.language.languageCode?.identifier != "en"
        }
    }

    /// `L.t("Saldo en caja", "Cash on hand")`
    static func t(_ es: String, _ en: String) -> String {
        esEspanol ? es : en
    }

    // MARK: - Fechas

    /// **El locale del idioma de la app**, que no tiene por qué ser el del
    /// dispositivo. Hoy `esEspanol` se deduce del sistema y por tanto esto es
    /// siempre `Locale.current` —se conserva la región del usuario: es_MX,
    /// es_ES, en_GB—, pero en cuanto Ajustes ofrezca elegir idioma dejarán de
    /// coincidir. Todo formateador de fechas de la interfaz tiene que seguir a
    /// este; `Locale.current` a secas escribe los meses en el idioma del
    /// teléfono dentro de una pantalla traducida.
    ///
    /// Los formateadores de la capa de datos (ISO, CSV) son otra cosa y siguen
    /// con `en_US_POSIX`: ahí el formato es un contrato, no una preferencia.
    static var locale: Locale {
        let sistema = Locale.current
        let sistemaEsEspanol = sistema.language.languageCode?.identifier != "en"
        guard sistemaEsEspanol != esEspanol else { return sistema }
        return Locale(identifier: esEspanol ? "es" : "en")
    }

    /// El único constructor de `DateFormatter` que deben usar las vistas:
    /// `DateFormatter()` a secas hereda `Locale.current`.
    static func formateador(_ formato: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = formato
        return f
    }

    /// `"Ene"` · `"Jan"` — la etiqueta de mes de las gráficas.
    ///
    /// Recortado a tres letras a propósito: en español ICU abrevia septiembre
    /// como "sept", y la tabla de esta misma clase (y por tanto la gráfica de
    /// asistencia, que va por `L.mes`) dice "Sep". Sin el recorte las dos
    /// gráficas de la app escribirían el mismo mes de dos formas, y en un eje
    /// de barras el ancho desigual se nota.
    static func mesCorto(_ d: Date) -> String {
        let s = formateador("MMM").string(from: d).prefix(3)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// Mes en curso escrito ("Septiembre 2026" · "September 2026"), para los
    /// subtítulos de los hubs. Iba a mano como "Agosto 2026" mientras Inicio
    /// leía la fecha real, así que Tesorería encabezaba un mes y Inicio otro.
    static var mesEnCurso: String {
        let s = formateador("LLLL yyyy").string(from: Date())
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
