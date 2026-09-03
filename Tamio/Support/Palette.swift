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
///
/// **Modo claro y oscuro.** Todos los colores viven en `Assets.xcassets` como
/// Color Sets con apariencia Any + Dark; aquí solo se nombran. Antes eran hex
/// fijos y en oscuro quedaban apagados.
///
/// Los rellenos (`…Fill`), atenuados (`…Muted`) y bordes (`…Stroke`) **ya
/// llevan el alpha dentro del Color Set**. No les apliques `.opacity()` encima:
/// un verde al 12% sobre blanco es un verde pálido legible, pero ese mismo 12%
/// sobre negro es prácticamente negro. Por eso el alpha del modo oscuro es casi
/// el doble que el del claro, y por eso tiene que estar en el catálogo y no en
/// la vista. La única excepción legítima es una **sombra**, donde el alpha sí es
/// parte del efecto (ver `ServiciosView`).
enum Paleta {
    /// El verde propio de Tamio (logo, seleccionado, botón Nuevo, cifras en +).
    static let brand = Color("TamioBrand")
    /// Fondo de lo seleccionado: filas, píldoras de filtro, cabecera de nav.
    static let brandFill = Color("TamioBrandFill")
    /// Verde atenuado de las barras secundarias (meses que no son el último).
    static let brandMuted = Color("TamioBrandMuted")
    /// Borde de píldora de filtro activo.
    static let brandStroke = Color("TamioBrandStroke")

    /// Cifras negativas y variaciones malas.
    static let negativo = Color("TamioNegativo")
    /// Fondo de badge/cápsula en rojo.
    static let negativoFill = Color("TamioNegativoFill")

    /// Avisos suaves ("Sin depositar", pendientes). Naranja.
    static let aviso = Color("TamioAviso")
    /// Fondo de cápsula de aviso.
    static let avisoFill = Color("TamioAvisoFill")
    /// Borde de recuadro de aviso.
    static let avisoStroke = Color("TamioAvisoStroke")

    /// Enlaces de acción ("Ver todos", "Abrir bandeja →", "Ver ficha").
    static let enlace = Color("TamioEnlace")
    /// Badge de conteo urgente (Por revisar 7, Mensajes 2).
    static let badge = Color("TamioNegativo")

    // MARK: - Categorías

    /// Los colores de categoría también tienen variante oscura: sobre negro el
    /// morado #7C3AED es el que peor se lee de todos. En Dark cada tono sube un
    /// escalón de luminosidad (`TamioCat1`…`TamioCat6` en el catálogo).
    static let morado   = Color("TamioCat1")
    static let cian     = Color("TamioCat2")
    static let naranja  = Color("TamioCat3")
    static let azulCielo = Color("TamioCat4")
    static let ambar    = Color("TamioCat5")
    static let pizarra  = Color("TamioCat6")

    /// Colores de la dona de INGRESOS por categoría, en orden de tamaño:
    /// Diezmos (verde) · Ofrendas (morado) · Misiones (cian) · Eventos (naranja).
    static let donut: [Color] = [brand, morado, cian, naranja]

    /// Color por categoría, para el punto de la lista de movimientos y la
    /// etiqueta del detalle. Espeja los colores de la dona (Diezmos verde,
    /// Ofrendas morado, Misiones cian, Eventos naranja) y añade los de gasto.
    static func categoria(_ nombre: String) -> Color {
        let s = nombre.lowercased()
        if s.contains("diezmo") { return donut[0] }       // verde
        if s.contains("ofrenda") { return donut[1] }      // morado
        if s.contains("mision") { return donut[2] }       // cian
        if s.contains("evento") { return donut[3] }       // naranja
        if s.contains("servicio") { return azulCielo }
        if s.contains("manten") { return ambar }
        return pizarra                                     // resto
    }

    /// SF Symbol por categoría, para la fila de movimientos. Antes la fila
    /// abría con un punto de 8×8 teñido con `categoria(_:)`: sin leyenda, y con
    /// gris azulado, gris, cian y verde conviviendo, no había forma de deducir
    /// qué significaba cada color, y a ese tamaño varios eran indistinguibles.
    /// Un símbolo se identifica solo.
    static func iconoCategoria(_ nombre: String) -> String {
        let s = nombre.lowercased()
        if s.contains("diezmo") { return "hands.and.sparkles.fill" }
        if s.contains("ofrenda") { return "gift.fill" }
        if s.contains("mision") { return "globe.americas.fill" }
        if s.contains("evento") { return "calendar" }
        if s.contains("servicio") || s.contains("utilidad") { return "bolt.fill" }
        if s.contains("manten") { return "wrench.and.screwdriver.fill" }
        if s.contains("limpieza") { return "sparkles" }
        if s.contains("aliment") { return "fork.knife" }
        if s.contains("suministro") || s.contains("material") { return "shippingbox.fill" }
        if s.contains("transporte") { return "car.fill" }
        if s.contains("tecnolog") { return "desktopcomputer" }
        if s.contains("renta") { return "building.2.fill" }
        if s.contains("compensa") || s.contains("pastor") { return "person.crop.circle.fill" }
        if s.contains("músico") || s.contains("musico") { return "music.note" }
        if s.contains("ayuda") { return "heart.fill" }
        if s.contains("donativ") || s.contains("donaci") { return "hand.raised.fill" }
        if s.contains("seguro") { return "shield.fill" }
        if s.contains("publicidad") { return "megaphone.fill" }
        if s.contains("mobiliario") { return "chair.fill" }
        return "circle.fill"
    }

    /// Puntos de color de la agenda ("Esta semana"), por familia de actividad.
    static let agenda: [Color] = [morado, brand, naranja, cian]
}
