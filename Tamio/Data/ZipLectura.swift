import Compression
import Foundation

/// **Abrir el `.zip` del respaldo, sin librerías.**
///
/// El paquete se COMPRIME con `NSFileCoordinator(.forUploading)`, que es el
/// mecanismo del sistema para adjuntar una carpeta en Mail (ver `Respaldo`).
/// Descomprimir no tiene equivalente: en iOS no hay API pública que abra un
/// zip. Las salidas eran tres y ninguna gratis —añadir una dependencia a un
/// `.pbxproj` que se edita a mano (§2.1 del traspaso), cambiar el formato a
/// AppleArchive y perder que el respaldo se abra con doble clic en cualquier
/// ordenador, o leer el zip aquí—, y esta es la que no le quita nada a nadie.
///
/// **Solo lee lo que la app misma escribe**: entradas guardadas o deflate, sin
/// cifrado y sin zip64. No es un lector de zips de propósito general y no
/// pretende serlo; lo que no reconoce, lo dice en vez de devolver basura.
enum ZipLectura {

    enum Fallo: LocalizedError {
        case noEsZip
        case zip64
        case metodo(UInt16)
        case corrupto

        var errorDescription: String? {
            switch self {
            case .noEsZip:
                return L.t("Ese archivo no es un respaldo de Tamio.",
                           "That file isn't a Tamio backup.")
            case .zip64:
                return L.t("El respaldo es demasiado grande para restaurarlo desde el teléfono.",
                           "The backup is too large to restore from the phone.")
            case .metodo:
                return L.t("El respaldo está comprimido de una forma que esta versión no sabe abrir.",
                           "The backup uses a compression this version can't open.")
            case .corrupto:
                return L.t("El archivo de respaldo está incompleto o dañado.",
                           "The backup file is incomplete or damaged.")
            }
        }
    }

    /// Saca el contenido del zip a `destino`. Devuelve las rutas relativas
    /// escritas, que es lo que la restauración necesita para saber qué venía.
    @discardableResult
    static func extraer(_ zip: URL, a destino: URL) throws -> [String] {
        let datos = try Data(contentsOf: zip)
        let fm = FileManager.default
        try fm.createDirectory(at: destino, withIntermediateDirectories: true)

        var escritas: [String] = []
        for entrada in try entradas(datos) {
            // **Ninguna ruta puede salirse de la carpeta de destino.** Un zip
            // puede traer nombres como "../../algo" y ese es el camino clásico
            // para escribir donde no se debe. El archivo lo hemos hecho
            // nosotros, pero quien lo elige en el selector puede haber elegido
            // cualquier cosa.
            let limpia = entrada.nombre
                .split(separator: "/")
                .filter { $0 != ".." && $0 != "." && !$0.isEmpty }
                .joined(separator: "/")
            guard !limpia.isEmpty else { continue }

            let salida = destino.appendingPathComponent(limpia)
            if entrada.nombre.hasSuffix("/") {
                try fm.createDirectory(at: salida, withIntermediateDirectories: true)
                continue
            }
            try fm.createDirectory(at: salida.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try contenido(entrada, en: datos).write(to: salida, options: .atomic)
            escritas.append(limpia)
        }
        return escritas
    }

    // MARK: - El formato

    private struct Entrada {
        let nombre: String
        let metodo: UInt16
        let comprimido: Int
        let original: Int
        let offsetLocal: Int
    }

    /// Las entradas salen del **directorio central**, al final del archivo, y
    /// no de recorrer las cabeceras locales: las locales pueden traer los
    /// tamaños en cero y remitir a un descriptor que va DESPUÉS de los datos
    /// —es lo que hace quien comprime al vuelo, sin saber aún cuánto va a
    /// ocupar—, mientras que el directorio central siempre los tiene.
    private static func entradas(_ d: Data) throws -> [Entrada] {
        guard let fin = finDelDirectorio(d) else { throw Fallo.noEsZip }
        let cuantas = Int(leer16(d, fin + 10))
        var p = Int(leer32(d, fin + 16))

        var salida: [Entrada] = []
        for _ in 0..<cuantas {
            guard p + 46 <= d.count, leer32(d, p) == 0x0201_4b50 else { throw Fallo.corrupto }
            let metodo = leer16(d, p + 10)
            let comprimido = leer32(d, p + 20)
            let original = leer32(d, p + 24)
            let nLargo = Int(leer16(d, p + 28))
            let eLargo = Int(leer16(d, p + 30))
            let cLargo = Int(leer16(d, p + 32))
            let offset = leer32(d, p + 42)
            guard comprimido != 0xFFFF_FFFF, original != 0xFFFF_FFFF,
                  offset != 0xFFFF_FFFF else { throw Fallo.zip64 }

            let inicioNombre = p + 46
            guard inicioNombre + nLargo <= d.count else { throw Fallo.corrupto }
            let nombre = String(decoding: d[inicioNombre..<(inicioNombre + nLargo)], as: UTF8.self)
            salida.append(Entrada(nombre: nombre, metodo: metodo,
                                  comprimido: Int(comprimido), original: Int(original),
                                  offsetLocal: Int(offset)))
            p = inicioNombre + nLargo + eLargo + cLargo
        }
        return salida
    }

    /// El fin del directorio central lleva una firma y una longitud variable de
    /// comentario, así que se busca hacia atrás desde el final.
    private static func finDelDirectorio(_ d: Data) -> Int? {
        guard d.count >= 22 else { return nil }
        var i = d.count - 22
        let minimo = max(0, d.count - 22 - 65_535)
        while i >= minimo {
            if leer32(d, i) == 0x0605_4b50 { return i }
            i -= 1
        }
        return nil
    }

    private static func contenido(_ e: Entrada, en d: Data) throws -> Data {
        let p = e.offsetLocal
        guard p + 30 <= d.count, leer32(d, p) == 0x0403_4b50 else { throw Fallo.corrupto }
        // **La longitud del campo extra se lee de la cabecera LOCAL.** No tiene
        // por qué coincidir con la del directorio central, y usar la otra deja
        // el puntero unos bytes corrido: los datos salen ilegibles sin que nada
        // avise.
        let inicio = p + 30 + Int(leer16(d, p + 26)) + Int(leer16(d, p + 28))
        guard inicio + e.comprimido <= d.count else { throw Fallo.corrupto }
        let crudo = d.subdata(in: inicio..<(inicio + e.comprimido))

        switch e.metodo {
        case 0:
            return crudo
        case 8:
            guard let inflado = inflar(crudo, original: e.original) else { throw Fallo.corrupto }
            return inflado
        default:
            throw Fallo.metodo(e.metodo)
        }
    }

    /// Deflate crudo, que es lo que `COMPRESSION_ZLIB` significa en Apple: sin
    /// la cabecera de zlib, que es justo lo que guarda un zip.
    private static func inflar(_ datos: Data, original: Int) -> Data? {
        guard original > 0 else { return Data() }
        var salida = Data(count: original)
        let escritos = salida.withUnsafeMutableBytes { destino -> Int in
            datos.withUnsafeBytes { origen -> Int in
                guard let d = destino.bindMemory(to: UInt8.self).baseAddress,
                      let o = origen.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, original, o, datos.count, nil, COMPRESSION_ZLIB)
            }
        }
        return escritos == original ? salida : nil
    }

    // MARK: - Enteros little-endian

    private static func leer16(_ d: Data, _ i: Int) -> UInt16 {
        guard i + 2 <= d.count else { return 0 }
        return UInt16(d[d.startIndex + i]) | UInt16(d[d.startIndex + i + 1]) << 8
    }

    private static func leer32(_ d: Data, _ i: Int) -> UInt32 {
        guard i + 4 <= d.count else { return 0 }
        return UInt32(d[d.startIndex + i])
            | UInt32(d[d.startIndex + i + 1]) << 8
            | UInt32(d[d.startIndex + i + 2]) << 16
            | UInt32(d[d.startIndex + i + 3]) << 24
    }
}
