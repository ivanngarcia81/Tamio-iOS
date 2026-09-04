import Observation
import SwiftUI
import UIKit

/// **Las firmas del tesorero y del pastor, guardadas SOLO en este aparato.**
///
/// Decidido el 2026-09-04, y es la razón de que esto no viva en
/// `ConfiguracionIglesia`: la firma **no se sincroniza**. La app web tomó la
/// misma decisión —`iglesias` en Supabase no tiene ninguna columna de firma— y
/// conviene entender por qué antes de cambiarlo: una firma que viaja a todos
/// los aparatos de la iglesia es un sello que cualquiera puede estampar en
/// cualquier documento, y este es el programa que lleva las cuentas.
///
/// Consecuencia que hay que decir en pantalla, porque si no sorprende: la firma
/// que la tesorera guarde en su iPhone **no saldrá** en los documentos que
/// alguien genere desde el iPad de la oficina.
///
/// Van en Application Support y no en Documents, igual que los recibos: no es
/// contenido que el usuario deba andar viendo por Archivos. Y **sí entran en el
/// respaldo**: la app web anotó justo eso como fallo suyo —la firma quedaba
/// fuera del paquete y restaurar en otra máquina dejaba los documentos sin
/// firmar, sin aviso—.
@Observable
@MainActor
final class FirmasLocales {

    static let compartidas = FirmasLocales()

    enum Firmante: String, CaseIterable, Identifiable {
        var id: String { rawValue }

        case tesorero, pastor

        var archivo: String { "firma-\(rawValue).png" }

        var titulo: String {
            switch self {
            case .tesorero: return L.t("Firma del tesorero", "Treasurer signature")
            case .pastor:   return L.t("Firma del pastor", "Pastor signature")
            }
        }
    }

    /// Las imágenes ya cargadas. Se guardan en memoria porque las lee el bloque
    /// de firmas de CADA página de CADA PDF, y volver al disco cada vez para el
    /// mismo archivo no tiene sentido.
    private(set) var imagenes: [Firmante: UIImage] = [:]

    private init() {
        for f in Firmante.allCases { imagenes[f] = Self.leer(f) }
    }

    // MARK: - Carpeta

    /// Pública porque el respaldo la copia entera.
    static var carpeta: URL? {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true) else { return nil }
        let dir = base.appendingPathComponent("firmas", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func url(_ f: Firmante) -> URL? {
        carpeta?.appendingPathComponent(f.archivo)
    }

    private static func leer(_ f: Firmante) -> UIImage? {
        guard let url = url(f), let datos = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: datos)
    }

    // MARK: - Guardar y borrar

    func imagen(_ f: Firmante) -> UIImage? { imagenes[f] }
    func tiene(_ f: Firmante) -> Bool { imagenes[f] != nil }

    /// Guarda en PNG y no en JPEG, a diferencia de los recibos: **el PNG
    /// conserva la transparencia**. Una firma en JPEG llega con el fondo
    /// relleno de blanco, y encima de la raya del documento eso es un
    /// rectángulo blanco tapando la línea.
    func guardar(_ imagen: UIImage, para f: Firmante) throws {
        guard let datos = imagen.pngData(), let url = Self.url(f) else {
            throw NSError(domain: "FirmasLocales", code: 1, userInfo: [
                NSLocalizedDescriptionKey: L.t("No se pudo preparar la firma.",
                                               "The signature could not be prepared."),
            ])
        }
        try datos.write(to: url, options: .atomic)
        imagenes[f] = imagen
    }

    func borrar(_ f: Firmante) {
        if let url = Self.url(f) { try? FileManager.default.removeItem(at: url) }
        imagenes[f] = nil
    }

    // MARK: - Preparar lo dibujado

    /// Recorta la imagen a lo que de verdad se dibujó y le deja un margen.
    ///
    /// Sin esto, una rúbrica pequeña hecha en una esquina del lienzo sale como
    /// una imagen enorme casi vacía, y al meterla en el hueco del PDF —que se
    /// ajusta al alto disponible— la firma se ve diminuta en medio de la nada.
    static func recortada(_ imagen: UIImage, margen: CGFloat = 12) -> UIImage {
        guard let cg = imagen.cgImage else { return imagen }
        let escala = imagen.scale
        guard let recorte = contenido(cg) else { return imagen }

        let conMargen = recorte.insetBy(dx: -margen * escala, dy: -margen * escala)
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let cortada = cg.cropping(to: conMargen) else { return imagen }
        return UIImage(cgImage: cortada, scale: escala, orientation: imagen.imageOrientation)
    }

    /// El rectángulo que ocupan los píxeles no transparentes. `nil` si está
    /// todo vacío, que es como se distingue "no ha dibujado nada" de "dibujó".
    private static func contenido(_ cg: CGImage) -> CGRect? {
        let ancho = cg.width, alto = cg.height
        guard ancho > 0, alto > 0 else { return nil }
        var pixeles = [UInt8](repeating: 0, count: ancho * alto)
        // Solo el canal alfa: es lo único que hace falta para saber dónde hay
        // trazo, y pedir los cuatro canales cuadruplicaría la memoria de una
        // imagen que en iPad puede ser grande.
        guard let ctx = CGContext(data: &pixeles, width: ancho, height: alto,
                                  bitsPerComponent: 8, bytesPerRow: ancho,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else {
            return nil
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: ancho, height: alto))

        var minX = ancho, minY = alto, maxX = -1, maxY = -1
        for y in 0..<alto {
            let fila = y * ancho
            for x in 0..<ancho where pixeles[fila + x] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Una imagen traída de fuera —una foto de la firma en papel, un PNG— tiene
    /// que quedar como la dibujada: fondo transparente.
    ///
    /// Una foto de papel no trae transparencia ninguna: trae blanco, gris de
    /// sombra y el trazo. Se pasa a escala de grises y lo claro se vuelve
    /// transparente, con el resto conservando su intensidad, así que un trazo
    /// suave sigue siendo suave en vez de convertirse en un borrón negro.
    static func sinFondo(_ imagen: UIImage) -> UIImage {
        guard let cg = imagen.cgImage else { return imagen }
        let ancho = cg.width, alto = cg.height
        var gris = [UInt8](repeating: 0, count: ancho * alto)
        guard let ctxGris = CGContext(data: &gris, width: ancho, height: alto,
                                      bitsPerComponent: 8, bytesPerRow: ancho,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return imagen
        }
        ctxGris.draw(cg, in: CGRect(x: 0, y: 0, width: ancho, height: alto))

        // RGBA negro con alfa = cuánto de oscuro era el píxel. El umbral deja
        // pasar el papel y sus sombras suaves; por debajo de 60 no queda nada.
        var rgba = [UInt8](repeating: 0, count: ancho * alto * 4)
        for i in 0..<(ancho * alto) {
            let claridad = Int(gris[i])
            let tinta = max(0, 200 - claridad) * 255 / 200
            rgba[i * 4 + 3] = UInt8(min(255, tinta))
        }
        guard let ctxColor = CGContext(data: &rgba, width: ancho, height: alto,
                                       bitsPerComponent: 8, bytesPerRow: ancho * 4,
                                       space: CGColorSpaceDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let salida = ctxColor.makeImage() else {
            return imagen
        }
        return recortada(UIImage(cgImage: salida, scale: imagen.scale, orientation: .up))
    }
}

private func CGColorSpaceDeviceRGB() -> CGColorSpace {
    CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
}
