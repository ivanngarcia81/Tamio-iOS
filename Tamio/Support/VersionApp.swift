import Foundation

/// **La versión de la app, leída del bundle.**
///
/// Iba escrita a mano: "1.3.5" en tres pantallas y "Compilación del 2026-08-29
/// 18:09 UTC" en el pie de la zona de riesgo. El bundle dice 0.1.0 (1). Eso no
/// es un detalle cosmético: la primera pregunta de cualquier soporte es qué
/// versión tiene instalada, y un número inventado manda a buscar el fallo a
/// otro sitio. Además una fecha de compilación fija envejece sola, y al mes
/// siguiente asegura que la app es más vieja de lo que es.
enum VersionApp {

    /// "0.1.0", de `CFBundleShortVersionString`.
    static var corta: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// El número de compilación, de `CFBundleVersion`.
    static var compilacion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// "0.1.0 (1)". La compilación se enseña junto a la versión porque entre
    /// dos aparatos con la misma versión es lo único que los distingue.
    static var completa: String { "\(corta) (\(compilacion))" }

    /// "Tamio 0.1.0 (1)", para el pie de Ajustes.
    static var pie: String { "Tamio \(completa)" }
}
