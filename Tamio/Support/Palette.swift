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

    /// Fondo de la barra de navegación. Era `brandFill`, que en oscuro sube al
    /// 22%: la barra quedaba de un verde medio y todo lo que va encima —el
    /// subtítulo gris del sistema y el verde del botón de volver— se apagaba
    /// contra ella. Este baja al 10% en oscuro, así que la barra es casi negra
    /// y los dos vuelven a recortarse. En claro es el mismo verde de siempre.
    static let barra = Color("TamioBarra")

    /// Superficie de una fila-tarjeta. `secondarySystemGroupedBackground` vale
    /// en claro, pero en oscuro (#1C1C1E) es casi el mismo tono que el material
    /// de la columna: en Membresía y Actas las filas solo se distinguían por el
    /// hueco entre ellas. Este sube un escalón en oscuro.
    static let superficieFila = Color("TamioSuperficieFila")

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

    /// Color por categoría, para el ícono de la lista de movimientos y la
    /// etiqueta del detalle. Espeja los colores de la dona (Diezmos verde,
    /// Ofrendas morado, Misiones cian, Eventos naranja) y añade los de gasto.
    ///
    /// Recibe la CLAVE y no la etiqueta: antes comparaba `contains("diezmo")`
    /// contra un texto que en inglés dice "Tithe", así que no acertaba ninguna
    /// rama y toda la lista salía del mismo gris. Ver `CategoriaClave`.
    static func categoria(_ clave: CategoriaClave?) -> Color {
        switch clave {
        case .diezmo:        return donut[0]   // verde
        case .ofrenda:       return donut[1]   // morado
        case .misiones:      return donut[2]   // cian
        case .eventos:       return donut[3]   // naranja
        case .utilidades:    return azulCielo
        case .mantenimiento: return ambar
        // Gris solo para el resto del catálogo y para lo que la iglesia se
        // invente en Ajustes. La ley de color prohíbe repartir acentos
        // decorativos entre veintitrés categorías.
        default:             return pizarra
        }
    }

    /// SF Symbol por categoría, para la fila de movimientos. Antes la fila
    /// abría con un punto de 8×8 teñido con `categoria(_:)`: sin leyenda, y con
    /// gris azulado, gris, cian y verde conviviendo, no había forma de deducir
    /// qué significaba cada color, y a ese tamaño varios eran indistinguibles.
    /// Un símbolo se identifica solo.
    static func iconoCategoria(_ clave: CategoriaClave?) -> String {
        switch clave {
        case .diezmo:        return "hands.and.sparkles.fill"
        case .ofrenda:       return "gift.fill"
        case .misiones:      return "globe.americas.fill"
        case .eventos:       return "calendar"
        case .donativo:      return "hand.raised.fill"
        case .compensacion,
             .pastores:      return "person.crop.circle.fill"
        case .musicos:       return "music.note"
        case .suministros:   return "shippingbox.fill"
        case .mobiliario:    return "chair.fill"
        case .limpieza:      return "sparkles"
        case .utilidades:    return "bolt.fill"
        case .mantenimiento: return "wrench.and.screwdriver.fill"
        case .alimentos:     return "fork.knife"
        case .tecnologia:    return "desktopcomputer"
        case .ayudas,
             .ayudaSocial:   return "heart.fill"
        case .transporte:    return "car.fill"
        case .publicidad:    return "megaphone.fill"
        case .renta:         return "building.2.fill"
        case .seguros:       return "shield.fill"
        case .varios,
             .otro:          return "tray.fill"
        // Una categoría inventada en Ajustes: no hay símbolo que le pegue.
        case nil:            return "circle.fill"
        }
    }

    /// Puntos de color de la agenda ("Esta semana"), por familia de actividad.
    static let agenda: [Color] = [morado, brand, naranja, cian]
}
