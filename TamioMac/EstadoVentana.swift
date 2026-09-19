import Observation
import SwiftUI

/// **Lo que sabe la ventana y no sabe el modelo de datos.**
///
/// Vive aparte de `Navegacion` —que es de las dos plataformas— porque nada de
/// esto existe en el teléfono: un inspector que se abre y se cierra, un campo
/// de filtro en la barra de herramientas, la fila seleccionada de una tabla.
/// Meterlo en `Navegacion` obligaría al iPhone a cargar con estado que nunca
/// va a usar.
@Observable
final class EstadoVentana {

    /// **La sección elegida, y vive aquí y no en la vista.**
    ///
    /// Empezó siendo un `@State` dentro de `VentanaPrincipal`, que es donde
    /// parece que debe estar. No sirve: la barra de menús es una escena
    /// hermana de la ventana, no una vista dentro de ella, así que un menú
    /// —o el ⌘, de Configuración— no puede tocar el estado privado de la
    /// vista. Subiéndolo aquí lo alcanzan los dos.
    var seccion: SeccionMac = .inicio

    /// El panel de la derecha. **Empieza abierto**, como en la maqueta: es
    /// donde se lee el detalle de lo seleccionado, y una ventana que arranca
    /// sin él parece que le falta algo.
    var inspectorAbierto = true

    /// El periodo del que se habla: lo que en la maqueta es el selector de tres
    /// posiciones de la barra de herramientas.
    var periodo: Periodo = .mes

    /// El texto del campo "Filtrar" de la barra de herramientas. Es por sección
    /// a propósito: filtrar Ingresos y saltar a Aportantes no debe arrastrar el
    /// filtro anterior, que es lo que hace que una lista parezca vacía.
    var filtros: [String: String] = [:]

    /// La fila elegida en cada tabla, también por sección y por lo mismo.
    var seleccion: [String: String] = [:]

    /// La densidad de las filas, del menú Ver. Los tres valores y sus alturas
    /// salen de la maqueta.
    var densidad: Densidad = .media

    enum Periodo: String, CaseIterable, Identifiable {
        case semana, mes, ano
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .semana: return L.t("Semana", "Week")
            case .mes:    return L.t("Mes", "Month")
            case .ano:    return L.t("Año", "Year")
            }
        }
    }

    enum Densidad: String, CaseIterable, Identifiable {
        case comoda, media, compacta
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .comoda:   return L.t("Cómoda", "Comfortable")
            case .media:    return L.t("Media", "Medium")
            case .compacta: return L.t("Compacta", "Compact")
            }
        }
        /// Alto de fila en puntos. 28 / 34 / 42, como la maqueta.
        var altoFila: CGFloat {
            switch self {
            case .compacta: return 28
            case .media:    return 34
            case .comoda:   return 42
            }
        }
    }

    /// **El testigo de "vuelve a leer de la base".**
    ///
    /// La sincronización escribe por debajo, sin pasar por ningún ViewModel.
    /// Las pantallas que ya habían cargado no se enteran, así que en un Mac
    /// recién estrenado la tabla se quedaba vacía aunque los datos acabaran de
    /// bajar. Subiendo este número se les pide que relean.
    private(set) var recarga = 0
    func recargar() { recarga += 1 }

    func filtro(_ s: SeccionMac) -> String { filtros[s.rawValue] ?? "" }
    func ponerFiltro(_ texto: String, en s: SeccionMac) { filtros[s.rawValue] = texto }
}
