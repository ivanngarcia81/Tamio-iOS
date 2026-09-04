import Foundation
import UIKit

/// **Dónde vive el recibo del banco mientras no ha subido.**
///
/// El comprobante de un movimiento se sube directo al bucket y, sin red, la
/// hoja avisa y el usuario reintenta. Para un depósito eso no vale: la foto del
/// recibo se hace EN EL BANCO, que es justo donde peor señal hay, y el papel se
/// tira o se pierde en el camino. Si la subida falla y no hay copia, el recibo
/// desaparece y no se puede volver a tomar.
///
/// Así que el archivo se copia SIEMPRE aquí primero, antes de intentar nada de
/// red. La subida es lo que puede esperar; el papel no vuelve.
enum RecibosLocales {

    /// Carpeta propia dentro de Application Support, fuera de Documents: no es
    /// contenido que el usuario deba ver por iTunes/Archivos, es respaldo de la
    /// app hasta que llega al servidor.
    static var carpeta: URL? {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true) else { return nil }
        let dir = base.appendingPathComponent("recibos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(_ nombre: String) -> URL? {
        carpeta?.appendingPathComponent(nombre)
    }

    /// Copia un archivo elegido en Archivos. Devuelve el nombre con el que
    /// quedó guardado, que es lo que se apunta en el depósito.
    ///
    /// El nombre original no se reutiliza: dos "IMG_0001.jpg" se pisarían, y el
    /// nombre de un archivo ajeno no es de fiar como ruta.
    static func guardar(desde origen: URL) throws -> String {
        // El `fileImporter` devuelve una URL fuera del sandbox de la app; sin
        // pedir acceso explícito, la lectura falla.
        let concedido = origen.startAccessingSecurityScopedResource()
        defer { if concedido { origen.stopAccessingSecurityScopedResource() } }
        let datos = try Data(contentsOf: origen)
        let ext = origen.pathExtension.isEmpty ? "dat" : origen.pathExtension.lowercased()
        return try guardar(datos: datos, extension: ext)
    }

    /// Guarda una foto recién tomada o elegida del carrete. Se pasa a JPEG con
    /// una calidad alta pero no máxima: un recibo es texto sobre papel blanco y
    /// a 0.85 se lee igual ocupando la mitad, que en el estacionamiento del
    /// banco es la diferencia entre subir y no subir.
    static func guardar(imagen: UIImage) throws -> String {
        guard let datos = imagen.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "RecibosLocales", code: 1, userInfo: [
                NSLocalizedDescriptionKey: L.t("No se pudo preparar la imagen.",
                                               "The image could not be prepared."),
            ])
        }
        return try guardar(datos: datos, extension: "jpg")
    }

    static func guardar(datos: Data, extension ext: String) throws -> String {
        guard let carpeta else {
            throw NSError(domain: "RecibosLocales", code: 2, userInfo: [
                NSLocalizedDescriptionKey: L.t("No se pudo abrir la carpeta de recibos.",
                                               "The receipts folder could not be opened."),
            ])
        }
        let nombre = "\(UUID().uuidString).\(ext)"
        try datos.write(to: carpeta.appendingPathComponent(nombre), options: .atomic)
        return nombre
    }

    /// Se borra solo cuando el archivo ya está en el servidor. Antes de eso, la
    /// copia local es la única que hay.
    static func borrar(_ nombre: String) {
        guard let url = url(nombre) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
