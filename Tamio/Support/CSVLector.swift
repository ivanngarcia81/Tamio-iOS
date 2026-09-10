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

        let encabezados = desambiguar(filas.removeFirst().map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        })
        // Una fila con un solo campo vacío es la línea en blanco del final.
        let utiles = filas.filter { !($0.count == 1 && $0[0].isEmpty) }
        guard !utiles.isEmpty else { throw Fallo.vacio }

        return Documento(encabezados: encabezados, filas: utiles)
    }

    /// **Dos columnas que se llaman igual dejan de llamarse igual.**
    ///
    /// Pasa al pegar dos hojas en Excel, y rompía dos cosas a la vez: el
    /// `Picker` del paso de mapeo hace `ForEach(encabezados, id: \.self)`, así
    /// que con nombres repetidos hay ids repetidos y SwiftUI enseña una sola
    /// opción; y `aplicar` resuelve con `firstIndex(of:)`, así que **elija la
    /// que elija el usuario, se llevaba la primera**. Medido con
    /// `nombre,monto,monto` y la fila `Ana,100,999`: pedir "monto" daba 100 y
    /// no había forma de pedir el 999.
    ///
    /// La segunda pasa a ser "monto (2)". No se descarta ninguna: cuál de las
    /// dos vale lo sabe quien exportó el archivo, no nosotros.
    private static func desambiguar(_ encabezados: [String]) -> [String] {
        var vistos: [String: Int] = [:]
        return encabezados.map { nombre in
            let n = (vistos[nombre] ?? 0) + 1
            vistos[nombre] = n
            return n == 1 ? nombre : "\(nombre) (\(n))"
        }
    }

    /// Gana el separador que más aparece en la primera línea. Contar en todo el
    /// archivo daría falsos positivos: un texto libre con muchas comas.
    ///
    /// **Sin mirar dentro de las comillas**, que es lo que fallaba: con
    /// `"nombre, apellido";monto` ganaba la coma y el archivo entero se quedaba
    /// en UNA columna llamada `nombre, apellido;monto`. El archivo era correcto
    /// y la app decía que le faltaban las columnas obligatorias.
    private static func detectarSeparador(_ texto: String) -> Character {
        let primera = texto.prefix { !$0.isNewline }
        var comas = 0, puntoYComa = 0
        var dentroDeComillas = false
        for c in primera {
            if c == "\"" { dentroDeComillas.toggle() }
            else if dentroDeComillas { continue }
            else if c == "," { comas += 1 }
            else if c == ";" { puntoYComa += 1 }
        }
        return puntoYComa > comas ? ";" : ","
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

// MARK: - Decir qué columna es cuál

/// **El paso de mapeo**, reflejado del `services/csvImport.ts` del app web.
///
/// Antes los dos importadores exigían los nombres de columna EXACTOS —`nombre`,
/// `fecha`, `monto`— y avisaban de las que faltaban. Eso funciona con un
/// archivo que salió de la propia exportación de Tamio y falla con cualquier
/// otro: nadie tiene un Excel cuya primera fila diga exactamente eso. El web lo
/// resolvió preguntando, y aquí se hace igual.
///
/// La pieza clave es que el mapeo **devuelve otro `Documento`** cuyas cabeceras
/// ya son las claves internas de la app. Así los importadores no se enteran de
/// que esto existe: siguen pidiendo `doc.valor(fila, "nombre")`.
extension CSVLector {

    /// Un dato que la app necesita, y por qué nombres suele venir.
    struct Campo: Identifiable, Hashable {
        let clave: String
        let rotulo: String
        let obligatorio: Bool
        /// Nombres con los que se reconoce sola. Van SIN acentos y en
        /// minúscula; la comparación normaliza el encabezado igual.
        let alias: [String]

        var id: String { clave }

        init(_ clave: String, _ rotulo: String, obligatorio: Bool = false, alias: [String] = []) {
            self.clave = clave
            self.rotulo = rotulo
            self.obligatorio = obligatorio
            // La propia clave siempre vale como alias: un archivo exportado por
            // Tamio se reconoce entero sin tocar nada, que es como funcionaba
            // esto antes y no debe empeorar.
            self.alias = [clave] + alias
        }
    }

    /// Compara sin acentos, sin mayúsculas y sin separadores, para que
    /// "Teléfono", "telefono" y " TELEFONO " sean la misma columna.
    ///
    /// **Todo lo que no sea letra o número cuenta como separador**, no solo el
    /// espacio: la primera versión solo cambiaba espacios y por eso "E-mail" no
    /// casaba con el alias `e_mail`. Lo encontró una prueba, no una lectura —
    /// un encabezado de Excel trae guiones, puntos y paréntesis a partes
    /// iguales.
    static func normalizar(_ s: String) -> String {
        let plano = s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                              locale: Locale(identifier: "es"))
        let troceado = plano.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return troceado.joined(separator: "_")
    }

    /// **La sugerencia**, que el usuario puede corregir. Una columna del
    /// archivo no se ofrece dos veces: si ya se asignó, se salta.
    static func mapeoSugerido(_ doc: Documento, campos: [Campo]) -> [String: String] {
        var mapeo: [String: String] = [:]
        var usadas = Set<String>()
        for campo in campos {
            let alias = Set(campo.alias.map(normalizar))
            if let hallada = doc.encabezados.first(where: {
                !usadas.contains($0) && alias.contains(normalizar($0))
            }) {
                mapeo[campo.clave] = hallada
                usadas.insert(hallada)
            }
        }
        return mapeo
    }

    /// **Rehace el documento con las claves de la app.** Lo que no se mapeó se
    /// queda como columna vacía, que es exactamente lo que `Documento.valor`
    /// ya sabía tratar: devuelve "" y cada importador aplica su omisión.
    static func aplicar(_ mapeo: [String: String], a doc: Documento, campos: [Campo]) -> Documento {
        let claves = campos.map(\.clave)
        let indices: [Int?] = campos.map { campo in
            guard let col = mapeo[campo.clave] else { return nil }
            return doc.encabezados.firstIndex(of: col)
        }
        let filas = doc.filas.map { fila in
            indices.map { i -> String in
                guard let i, i < fila.count else { return "" }
                return fila[i].trimmingCharacters(in: .whitespaces)
            }
        }
        return Documento(encabezados: claves, filas: filas)
    }

    /// Los obligatorios que siguen sin columna. Es lo que apaga el botón de
    /// continuar, y sustituye al aviso de "falta la columna «nombre»".
    static func faltantes(_ mapeo: [String: String], campos: [Campo]) -> [Campo] {
        campos.filter { $0.obligatorio && mapeo[$0.clave] == nil }
    }
}
