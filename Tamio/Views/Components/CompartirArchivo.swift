import SwiftUI
import UIKit

/// Hoja del sistema para mandar un archivo a donde el usuario quiera: correo,
/// Archivos, AirDrop, WhatsApp. Es `UIActivityViewController` envuelto porque
/// `ShareLink` necesita el archivo listo antes de dibujar el botón, y aquí el
/// CSV se genera justo al pulsarlo.
struct CompartirArchivo: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Para poder presentarlo con `.sheet(item:)` pasando la URL directamente.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
