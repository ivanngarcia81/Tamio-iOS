import SwiftUI

extension Color {
    /// Inicializador por hex (0xRRGGBB).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// **La ley de color del diseño** (nota al pie del handoff del iPad):
/// «Toda la interfaz se apoya en la escala de grises de iPadOS. El color propio
/// de Tamio solo aparece en lo seleccionado y en las cifras.»
///
/// Por eso aquí NO hay acentos decorativos: el verde de Tamio se usa solo para
/// el estado seleccionado (sidebar, segmentado, botón Nuevo) y para las cifras
/// que comunican signo (montos y variaciones). El resto es gris del sistema.
enum Paleta {
    /// El verde propio de Tamio (logo, seleccionado, botón Nuevo, cifras en +).
    static let brand = Color(hex: 0x157A4B)
    /// Cifras negativas y variaciones malas.
    static let negativo = Color(hex: 0xDC2626)
    /// Enlaces de acción ("Ver todos", "Abrir bandeja →", "Ver ficha").
    static let enlace = Color(hex: 0x2563EB)
    /// Avisos suaves ("Sin depositar", pendientes). Naranja.
    static let aviso = Color(hex: 0xEA580C)
    /// Badge de conteo urgente (Por revisar 7, Mensajes 2).
    static let badge = Color(hex: 0xDC2626)

    /// Colores de la dona de INGRESOS por categoría, en orden de tamaño:
    /// Diezmos (verde) · Ofrendas (morado) · Misiones (cian) · Eventos (naranja).
    static let donut: [Color] = [
        Color(hex: 0x157A4B),
        Color(hex: 0x7C3AED),
        Color(hex: 0x06B6D4),
        Color(hex: 0xF97316),
    ]

    /// Color por categoría, para el punto de la lista de movimientos y la
    /// etiqueta del detalle. Espeja los colores de la dona (Diezmos verde,
    /// Ofrendas morado, Misiones cian, Eventos naranja) y añade los de gasto.
    static func categoria(_ nombre: String) -> Color {
        let s = nombre.lowercased()
        if s.contains("diezmo") { return donut[0] }       // verde
        if s.contains("ofrenda") { return donut[1] }      // morado
        if s.contains("mision") { return donut[2] }       // cian
        if s.contains("evento") { return donut[3] }       // naranja
        if s.contains("servicio") { return Color(hex: 0x0EA5E9) }   // azul cielo
        if s.contains("manten") { return Color(hex: 0xF59E0B) }     // ámbar
        return Color(hex: 0x64748B)                        // pizarra (resto)
    }

    /// Puntos de color de la agenda ("Esta semana"), por familia de actividad.
    static let agenda: [Color] = [
        Color(hex: 0x7C3AED), // morado
        Color(hex: 0x157A4B), // verde
        Color(hex: 0xF97316), // naranja
        Color(hex: 0x06B6D4), // cian
    ]
}
