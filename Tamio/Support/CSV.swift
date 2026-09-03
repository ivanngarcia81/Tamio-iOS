import Foundation

/// Generación de archivos CSV que Excel abra bien a la primera.
///
/// Suena trivial y no lo es. Dos detalles hunden un CSV en cuanto sale de la
/// app:
///
/// - **El separador depende del idioma del sistema.** Excel en español espera
///   punto y coma; con comas mete toda la fila en una sola columna y el usuario
///   concluye que el archivo está roto. En inglés es al revés.
/// - **Sin BOM, las tildes se rompen.** Excel no supone UTF-8, así que
///   "Márquez" se abre como "MÃ¡rquez".
enum CSV {

    /// En español el punto y coma, porque la coma ya es el separador decimal.
    static var separador: String { L.esEspanol ? ";" : "," }

    /// Encabezado invisible que le dice a Excel que el archivo es UTF-8.
    private static var bom: Data { Data([0xEF, 0xBB, 0xBF]) }

    /// Un campo listo para escribir. Se entrecomilla si hace falta y las
    /// comillas internas se duplican, que es como manda el formato.
    static func campo(_ texto: String) -> String {
        let necesitaComillas = texto.contains(separador)
            || texto.contains("\"") || texto.contains("\n") || texto.contains("\r")
        guard necesitaComillas else { return texto }
        return "\"" + texto.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Importe con el separador decimal del idioma, sin símbolo de moneda ni
    /// separador de miles: un número con puntos de millar no lo lee nadie.
    static func importe(_ centavos: Centavos) -> String {
        let valor = Double(centavos) / 100
        let texto = String(format: "%.2f", valor)
        return L.esEspanol ? texto.replacingOccurrences(of: ".", with: ",") : texto
    }

    /// Fecha en ISO (yyyy-MM-dd). No se localiza a propósito: es un dato para
    /// releer, y "03/09/2026" se interpreta distinto a cada lado del Atlántico.
    static func fecha(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    static func fila(_ campos: [String]) -> String {
        campos.map(campo).joined(separator: separador)
    }

    /// Escribe el archivo y devuelve su URL temporal, lista para compartir.
    static func archivo(nombre: String, encabezados: [String], filas: [[String]]) -> URL? {
        var texto = fila(encabezados) + "\r\n"
        for f in filas { texto += fila(f) + "\r\n" }

        guard var datos = texto.data(using: .utf8) else { return nil }
        datos = bom + datos

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(nombre).csv")
        do {
            try datos.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
