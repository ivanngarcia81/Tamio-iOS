import SwiftUI
import Observation

/// **Las preferencias de la app en este aparato.**
///
/// Eran seis `@State` dentro de la pantalla de Ajustes: se movían, se veían
/// moverse, y no hacían nada ni sobrevivían a cerrar la app. Quedan tres, y las
/// tres se aplican de verdad.
///
/// Van en `UserDefaults` y **no** en la iglesia: el tema, el idioma y el tamaño
/// de letra son de quien mira la pantalla, no de la congregación. Dos personas
/// de la misma iglesia pueden querer cosas distintas, y una tesorera que
/// prefiere el modo oscuro no tiene por qué imponérselo al pastor.
///
/// **Las dos que faltan, y por qué no están:**
///
/// - *Color de acento.* La ley de color de `Paleta` dice que el verde de Tamio
///   solo aparece en lo seleccionado y en las cifras; repartir cinco acentos
///   por la app contradice eso, y el selector de cinco círculos prometía teñir
///   "botones y enlaces" que están pintados con `Paleta.brand` en decenas de
///   sitios.
/// - *Sonidos.* No hay ninguno. Un interruptor de sonido y un selector de
///   "juego de sonidos" con tres nombres inventados prometían algo que no
///   existe en ninguna parte del código.
@Observable
final class PreferenciasApp {

    static let compartidas = PreferenciasApp()

    enum Tema: String, CaseIterable {
        case claro, oscuro, automatico

        var etiqueta: String {
            switch self {
            case .claro:      return L.t("Claro", "Light")
            case .oscuro:     return L.t("Oscuro", "Dark")
            case .automatico: return L.t("Automático", "Automatic")
            }
        }

        /// `nil` en automático: sin `preferredColorScheme` la app sigue al
        /// sistema, que es exactamente lo que "automático" significa.
        var esquema: ColorScheme? {
            switch self {
            case .claro:      return .light
            case .oscuro:     return .dark
            case .automatico: return nil
            }
        }
    }

    enum Idioma: String, CaseIterable {
        case espanol, ingles, automatico

        /// Sin `L.t`: el nombre de un idioma se escribe en ESE idioma, o quien
        /// no entiende el actual no sabe cuál elegir para salir de él.
        var etiqueta: String {
            switch self {
            case .espanol:    return "Español"
            case .ingles:     return "English"
            case .automatico: return L.t("Automático", "Automatic")
            }
        }
    }

    /// El tamaño de letra. **"Normal" no fuerza nada**: deja pasar el ajuste de
    /// accesibilidad del sistema, que es lo que hay que respetar cuando nadie
    /// ha pedido otra cosa. Los demás sí lo sustituyen, porque entonces sí lo
    /// ha pedido alguien.
    enum Tamano: String, CaseIterable {
        case pequeno, compacto, normal, grande, muyGrande

        var etiqueta: String {
            switch self {
            case .pequeno:   return L.t("Pequeño", "Small")
            case .compacto:  return L.t("Compacto", "Compact")
            case .normal:    return L.t("Normal", "Normal")
            case .grande:    return L.t("Grande", "Large")
            case .muyGrande: return L.t("Muy grande", "Extra large")
            }
        }

        var dynamicType: DynamicTypeSize? {
            switch self {
            case .pequeno:   return .xSmall
            case .compacto:  return .small
            case .normal:    return nil
            case .grande:    return .xLarge
            case .muyGrande: return .xxxLarge
            }
        }
    }

    var tema: Tema {
        didSet { guardar(tema.rawValue, en: Self.claveTema) }
    }
    var idioma: Idioma {
        didSet { guardar(idioma.rawValue, en: Self.claveIdioma) }
    }
    var tamano: Tamano {
        didSet { guardar(tamano.rawValue, en: Self.claveTamano) }
    }

    private static let claveTema   = "prefs.tema"
    private static let claveIdioma = "prefs.idioma"
    private static let claveTamano = "prefs.tamano"

    private init() {
        let d = UserDefaults.standard
        tema = Tema(rawValue: d.string(forKey: Self.claveTema) ?? "") ?? .automatico
        idioma = Idioma(rawValue: d.string(forKey: Self.claveIdioma) ?? "") ?? .automatico
        tamano = Tamano(rawValue: d.string(forKey: Self.claveTamano) ?? "") ?? .normal
    }

    private func guardar(_ valor: String, en clave: String) {
        UserDefaults.standard.set(valor, forKey: clave)
    }

    /// El idioma elegido, leído sin pasar por el objeto observable.
    ///
    /// `L` es un `enum` de funciones estáticas al que llaman cientos de vistas
    /// y no puede depender de un `@Observable`; esto le da la respuesta desde
    /// `UserDefaults`, que es donde vive. Que la pantalla se redibuje al
    /// cambiarlo lo resuelve la raíz con un `.id`, no esto.
    static var idiomaGuardado: Idioma {
        Idioma(rawValue: UserDefaults.standard.string(forKey: claveIdioma) ?? "") ?? .automatico
    }
}
