import SwiftUI
import AppKit

/// **Las superficies del Mac, con los valores del handoff.**
///
/// Aquí hubo dos intentos fallidos y conviene dejarlos escritos, porque los
/// dos parecían razonables:
///
/// 1. `.background.secondary` de SwiftUI para las tarjetas. En modo CLARO
///    pinta gris, y el fondo de la ventana es blanco: la tarjeta salía más
///    oscura que su suelo y la jerarquía quedaba del revés.
/// 2. Los colores semánticos del sistema —`controlBackgroundColor` encima,
///    `windowBackgroundColor` debajo—. **En macOS 27 los dos son `#FFFFFF`**,
///    comprobado en el aparato: cambiar uno por otro no cambiaba nada, y por
///    eso la segunda captura se veía igual que la primera.
///
/// La lección es que en este sistema los nombres semánticos ya no separan
/// planos en claro. El handoff no los usa: escribe su paleta, y su jerarquía
/// en claro NO la hace el relleno —sus tarjetas también son blancas— sino un
/// filo de medio punto y una sombra muy corta. En oscuro sí cambia el relleno.
///
/// Se sigue eso, con una diferencia a propósito: el suelo va en `#F6F6F8`
/// —`--surface2` de su propia paleta— en vez de blanco. Con el filo solo, en
/// una pantalla grande y a plena luz, las tarjetas seguían costando de
/// distinguir.
extension Color {
    /// Lo que está ENCIMA. `--surface` del handoff.
    static let tarjeta = Color.dinamico(claro: 0xFFFFFF, oscuro: 0x262629)

    /// El suelo ENTRE tarjetas. `--surface2` en claro, `--content` en oscuro.
    static let suelo = Color.dinamico(claro: 0xF6F6F8, oscuro: 0x1E1E20)

    /// El filo de medio punto. `--sep` del handoff: negro al 10 % en claro,
    /// blanco al 12 % en oscuro.
    static let filo = Color.dinamico(claro: 0x000000, oscuro: 0xFFFFFF)
}

extension View {
    /// **Una tarjeta: relleno, filo y sombra corta.**
    ///
    /// Las tres cosas juntas y en un solo sitio, porque separarlas fue el
    /// error: se cambiaba el relleno creyendo que bastaba, y lo que de verdad
    /// dibuja el borde de una tarjeta en modo claro es el filo.
    func tarjetaMac(_ radio: CGFloat = 14) -> some View {
        self
            .background(Color.tarjeta,
                        in: RoundedRectangle(cornerRadius: radio, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .stroke(Color.filo.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
    }
}

// MARK: - El ancla de «Compartir»

/// **Guarda la `NSView` que hay debajo de un botón «Compartir»** para que
/// `NSSharingServicePicker` sepa de dónde colgar su menú. Es una clase y no un
/// valor porque la vista la crea AppKit después de que SwiftUI arme el cuerpo:
/// el botón lee la referencia cuando se pulsa, no cuando se dibuja.
///
/// Estuvo copiada tres veces, `private` en Reportes, Actas y el corte; al
/// tercer uso tocaba sacarla aquí, y aquí está.
final class AnclaCompartir {
    weak var vista: NSView?
}

/// Una `NSView` vacía del tamaño del botón, puesta en su `.background`. No
/// pinta nada ni recibe clics (`hitTest` devuelve nil), así que el botón sigue
/// siendo el que se pulsa.
struct VistaAncla: NSViewRepresentable {
    let ancla: AnclaCompartir

    func makeNSView(context: Context) -> NSView {
        let v = VistaTransparente()
        ancla.vista = v
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        ancla.vista = nsView
    }

    private final class VistaTransparente: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
