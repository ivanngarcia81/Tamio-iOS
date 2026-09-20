import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Los dos nombres que cambian

/// **Una imagen, se llame como se llame donde corra.**
///
/// Es lo único que UIKit y AppKit no comparten de lo que esta app usa de
/// verdad: el resto del trabajo con imágenes —recortar por el canal alfa,
/// quitarle el fondo a la foto de una firma, componer el PDF— ya está escrito
/// en Core Graphics, que es el mismo marco en los dos sistemas.
///
/// **Por eso hay alias y no dos copias del archivo.** La alternativa era
/// duplicar `FirmasLocales` y `LogoIglesia` con un `#if` alrededor de cada
/// uno, y entonces el recorte de la firma viviría por duplicado: el día que se
/// corrigiera el umbral de tinta en uno, el otro se quedaría atrás. Lo que se
/// duplica aquí abajo son cuatro operaciones de fontanería; la lógica no.
#if canImport(UIKit)
typealias ImagenPlataforma = UIImage
typealias ColorPlataforma = UIColor
#else
typealias ImagenPlataforma = NSImage
typealias ColorPlataforma = NSColor
#endif

// MARK: - Imágenes

extension ImagenPlataforma {

    /// La imagen de Core Graphics que hay debajo.
    ///
    /// En UIKit es una propiedad y en AppKit un método con tres argumentos que
    /// casi siempre van en `nil`. Se unifica como propiedad porque es lo que
    /// son los diez sitios que la usan: un acceso, no una decisión.
    var cgImagen: CGImage? {
        #if canImport(UIKit)
        return cgImage
        #else
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    /// Píxeles por punto.
    ///
    /// `UIImage` la lleva puesta. `NSImage` no tiene tal cosa —una imagen de
    /// AppKit puede traer varias representaciones a distintas resoluciones—,
    /// así que se deduce de la primera: píxeles de ancho entre puntos de ancho.
    /// Es lo que hace falta para que el recorte de una firma mantenga su tamaño
    /// en el papel, que es el único sitio donde esto se nota.
    var escala: CGFloat {
        #if canImport(UIKit)
        return scale
        #else
        guard let rep = representations.first, size.width > 0 else { return 1 }
        return CGFloat(rep.pixelsWide) / size.width
        #endif
    }

    /// PNG. **Conserva la transparencia**, que es justo por lo que las firmas
    /// se guardan así y no en JPEG: una firma con el fondo relleno de blanco es
    /// un rectángulo tapando la raya del documento.
    func datosPNG() -> Data? {
        #if canImport(UIKit)
        return pngData()
        #else
        return representacion(.png, propiedades: [:])
        #endif
    }

    /// JPEG con calidad de 0 a 1.
    func datosJPEG(calidad: CGFloat) -> Data? {
        #if canImport(UIKit)
        return jpegData(compressionQuality: calidad)
        #else
        return representacion(.jpeg, propiedades: [.compressionFactor: calidad])
        #endif
    }

    #if !canImport(UIKit)
    private func representacion(_ tipo: NSBitmapImageRep.FileType,
                                propiedades: [NSBitmapImageRep.PropertyKey: Any]) -> Data? {
        // Se construye el mapa de bits DESDE el `CGImage` y no desde
        // `TIFFRepresentation`, que es el camino corto y el equivocado: ese
        // aplana a la resolución en puntos y una firma hecha en una pantalla
        // Retina salía a la mitad de píxeles, borrosa al imprimirla.
        guard let cg = cgImagen else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = size
        return rep.representation(using: tipo, properties: propiedades)
    }
    #endif

    /// Una imagen nueva a partir de un `CGImage` ya procesado, **conservando la
    /// orientación de la original**.
    ///
    /// Importa solo en iOS: una foto hecha con la cámara llega girada y con la
    /// orientación anotada aparte, así que perderla al recortar deja la firma
    /// de lado. En Mac la foto entra por un archivo y no trae ese dato.
    static func desde(cg: CGImage, comoEn original: ImagenPlataforma) -> ImagenPlataforma {
        #if canImport(UIKit)
        return UIImage(cgImage: cg, scale: original.escala, orientation: original.imageOrientation)
        #else
        return desde(cg: cg, escala: original.escala)
        #endif
    }

    /// Una imagen nueva ya derecha: lo que sale de redibujar píxel a píxel, que
    /// se escribe siempre en la orientación natural.
    static func desde(cg: CGImage, escala: CGFloat) -> ImagenPlataforma {
        let e = escala > 0 ? escala : 1
        #if canImport(UIKit)
        return UIImage(cgImage: cg, scale: e, orientation: .up)
        #else
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / e,
                                                 height: CGFloat(cg.height) / e))
        #endif
    }
}

// MARK: - Colores que cambian con la apariencia

extension Color {

    /// Un color que se resuelve solo según la apariencia del sistema.
    ///
    /// En UIKit se hace con el bloque de `UIColor` y el `userInterfaceStyle`;
    /// en AppKit, con un `NSColor` con nombre que recibe la `NSAppearance` y
    /// tiene que preguntarle cuál de las dos se le parece más —`darkAqua` no
    /// se compara con `==` porque una apariencia real puede ser
    /// `darkAqua.vibrant` o la de alto contraste, y ninguna es igual a la
    /// básica—. `bestMatch(from:)` es lo que resuelve eso bien.
    static func dinamico(claro: UInt32, oscuro: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { t in
            UIColor(Color(hex: t.userInterfaceStyle == .dark ? oscuro : claro))
        })
        #else
        return Color(NSColor(name: nil) { ap in
            let esOscuro = ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: esOscuro ? oscuro : claro))
        })
        #endif
    }

    /// Igual, pero en oscuro deja intacto un color DEL SISTEMA.
    static func dinamico(claro: UInt32, oscuroSistema: ColorPlataforma) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { t in
            t.userInterfaceStyle == .dark ? oscuroSistema : UIColor(Color(hex: claro))
        })
        #else
        return Color(NSColor(name: nil) { ap in
            ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? oscuroSistema : NSColor(Color(hex: claro))
        })
        #endif
    }
}

// MARK: - Colores semánticos del sistema

extension Color {

    /// Texto secundario del sistema.
    ///
    /// Los dos sistemas tienen el mismo rol con distinto nombre. Se envuelve
    /// aquí en vez de escribir `Color(.secondaryLabel)` suelto, que es UIKit y
    /// no compila en el Mac.
    static var etiquetaSecundaria: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondaryLabel)
        #else
        return Color(NSColor.secondaryLabelColor)
        #endif
    }

    /// El gris de debajo de una lista agrupada: lo que se ve ENTRE las
    /// tarjetas y por eso no puede ser blanco.
    ///
    /// En iOS es `systemGroupedBackground`. En macOS el rol equivalente es
    /// `windowBackgroundColor`, que es el gris sobre el que Ajustes del Mac
    /// apoya sus tarjetas — el mismo papel y la misma relación de contraste
    /// contra el blanco de la tarjeta.
    static var fondoAgrupado: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
}

// MARK: - De qué aparato se trata

/// Para el rastro de auditoría. **Un rastro que miente sobre el aparato no
/// sirve para lo que existe**, que es poder decir desde dónde se tocó el libro.
enum Dispositivo {
    static var nombre: String {
        #if os(macOS)
        return "Mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }
}
