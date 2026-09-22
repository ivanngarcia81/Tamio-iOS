import SwiftUI

/// La franja de 26 pt del pie de la ventana: a la izquierda qué está pasando,
/// a la derecha los atajos que no se ven en ningún otro sitio.
struct BarraEstado: View {
    let estado: String
    /// **El pie no anuncia un atajo que en esta pantalla no hace nada.**
    /// Reportes y Configuración no alimentan el inspector, así que ahí ⌘I no
    /// abre nada y prometerlo en la franja sería mentir en letra pequeña.
    var hayInspector = true

    var body: some View {
        HStack(spacing: 14) {
            Text(estado)
            Spacer(minLength: 0)
            Text(L.t("⌘1–9 secciones", "⌘1–9 sections"))
            if hayInspector { Text(L.t("⌘I inspector", "⌘I inspector")) }
            Text(L.t("⇧⌘L apariencia", "⇧⌘L appearance"))
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 26)
        .background(.quaternary.opacity(0.35))
        .overlay(alignment: .top) { Divider() }
    }
}
