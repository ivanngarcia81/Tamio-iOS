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
}
