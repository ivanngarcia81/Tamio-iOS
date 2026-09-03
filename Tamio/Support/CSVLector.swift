import Foundation

/// Lee un CSV que puede venir de cualquier sitio: de nuestra propia
/// exportación, de Excel, de Google Sheets o de la app anterior de la iglesia.
///
/// No se puede dar nada por supuesto. El separador puede ser coma o punto y
/// coma según con qué idioma lo guardaron; el archivo puede traer BOM o no; los
/// saltos pueden ser CRLF o LF; y un campo entrecomillado puede contener
/// separadores y hasta saltos de línea dentro.
enum CSVLector {

    struct Documento {
        let encabezados: [String]
        let filas: [[String]]

        /// Valor de una columna por nombre. Devuelve cadena vacía si esa
        /// columna no viene en el archivo, que es más útil que reventar: ya se
        /// avisa aparte de las columnas que faltan.
        func valor(_ fila: [String], _ columna: String) -> String {
            guard let i = encabezados.firstIndex(of: columna), i < fila.count else { return "" }
            return fila[i].trimmingCharacters(in: .whitespaces)
        }
    }

    enum Fallo: LocalizedError {
        case noSePudoLeer
        case vacio

        var errorDescription: String? {
            switch self {
            case .noSePudoLeer:
                return L.t("No se pudo leer el archivo. ¿Es un CSV?",
                           "Couldn't read the file. Is it a CSV?")
            case .vacio:
                return L.t("El archivo no tiene filas.", "The file has no rows.")
            }
        }
    }

    static func leer(_ url: URL) throws -> Documento {
        let concedido = url.startAccessingSecurityScopedResource()
        defer { if concedido { url.stopAccessingSecurityScopedResource() } }

        guard let datos = try? Data(contentsOf: url) else { throw Fallo.noSePudoLeer }
        // Se prueba UTF-8 y, si el archivo viene de un Excel viejo, Latin-1:
        // rechazarlo sin más obligaría al usuario a convertirlo por su cuenta.
        guard var texto = String(data: datos, encoding: .utf8)
                ?? String(data: datos, encoding: .isoLatin1) else {
            throw Fallo.noSePudoLeer
        }
        // El BOM se cuela como primer carácter y estropearía el nombre de la
        // primera columna ("\u{FEFF}id" no es "id").
        if texto.hasPrefix("\u{FEFF}") { texto.removeFirst() }

        let separador = detectarSeparador(texto)
        var filas = trocear(texto, separador: separador)
        guard !filas.isEmpty else { throw Fallo.vacio }

        let encabezados = filas.removeFirst().map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        // Una fila con un solo campo vacío es la línea en blanco del final.
        let utiles = filas.filter { !($0.count == 1 && $0[0].isEmpty) }
        guard !utiles.isEmpty else { throw Fallo.vacio }

        return Documento(encabezados: encabezados, filas: utiles)
    }

    /// Gana el separador que más aparece en la primera línea. Contar en todo el
    /// archivo daría falsos positivos: un texto libre con muchas comas.
    private static func detectarSeparador(_ texto: String) -> Character {
        let primera = texto.split(whereSeparator: \.isNewline).first ?? ""
        return primera.filter { $0 == ";" }.count > primera.filter { $0 == "," }.count ? ";" : ","
    }

    /// Recorre carácter a carácter porque `split` no entiende comillas: un
    /// nombre como «Márquez Peña, Lucía» se partiría en dos columnas.
    private static func trocear(_ texto: String, separador: Character) -> [[String]] {
        var filas: [[String]] = []
        var fila: [String] = []
        var campo = ""
        var dentroDeComillas = false
        var i = texto.startIndex

        while i < texto.endIndex {
            let c = texto[i]
            if dentroDeComillas {
                if c == "\"" {
                    let siguiente = texto.index(after: i)
                    if siguiente < texto.endIndex, texto[siguiente] == "\"" {
                        campo.append("\"")   // comilla escapada
                        i = siguiente
                    } else {
                        dentroDeComillas = false
                    }
                } else {
                    campo.append(c)
                }
            } else if c == "\"" {
                dentroDeComillas = true
            } else if c == separador {
                fila.append(campo); campo = ""
            } else if c.isNewline {
                // `isNewline` y no comparar con "\n" y "\r" por separado: en
                // Swift el CRLF de Windows es UN SOLO Character, así que
                // buscarlos sueltos no encuentra nada y el archivo entero se
                // queda en una única fila. Es justo lo que guarda Excel.
                fila.append(campo); campo = ""
                filas.append(fila); fila = []
            } else {
                campo.append(c)
            }
            i = texto.index(after: i)
        }
        if !campo.isEmpty || !fila.isEmpty {
            fila.append(campo)
            filas.append(fila)
        }
        return filas
    }
}
