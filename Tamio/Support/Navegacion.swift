import Observation

/// Navegación de nivel superior, compartida por iPad y iPhone.
///
/// Muchas pantallas necesitan mandar al usuario a otra sección ("Ver todos" →
/// Ingresos). En iPhone basta con empujar la vista en el stack de la pestaña,
/// pero en iPad el detalle vive en la columna derecha de un
/// `NavigationSplitView`: ahí no hay pila que empujar, y lo que espera el
/// usuario es que se mueva la selección de la sidebar. Tener el estado aquí
/// permite que cualquier pantalla lo haga sin que se lo pasen por parámetro.
@Observable
final class Navegacion {
    /// Sección elegida en la sidebar del iPad. Los identificadores son los
    /// mismos que enruta `RootView`.
    var seccion = "inicio"
    /// El corte que hay que abrir al llegar a Depósitos. Lo pone "Ir al corte"
    /// de la bandeja: sin esto el botón llevaba a la lista y el tesorero tenía
    /// que buscar a mano cuál de los tres esperaba su firma.
    var corteDestacado: String?
    /// Pestaña elegida en el TabView del iPhone.
    var pestana: Pestana = .inicio

    enum Pestana: Hashable {
        case inicio, tesoreria, revisar, secretaria, ajustes
    }

    // MARK: - Las dos formas de la app, sincronizadas

    /// **A qué pestaña del teléfono pertenece cada sección de la sidebar.**
    ///
    /// La app cambia de forma con el ANCHO DE LA VENTANA, no solo de aparato:
    /// en iPadOS 26 se estrecha con el asa de la esquina y a 375 pt la clase
    /// pasa a compacta y se dibuja el `TabView`. Hasta ahora esas dos formas no
    /// se hablaban —la sidebar mira `seccion` y las pestañas miran `pestana`—,
    /// así que estrechar la ventana desde Ingresos aterrizaba en Inicio: se
    /// perdía dónde estabas por cambiar el tamaño de la ventana.
    static func pestana(de seccion: String) -> Pestana {
        switch seccion {
        case "inicio":              return .inicio
        case "porRevisar":          return .revisar
        case "config":              return .ajustes
        case "membresia", "actas", "servicios", "cartas", "informes",
             "agenda", "registro":  return .secretaria
        default:                    return .tesoreria
        }
    }

    /// Y el camino de vuelta: con qué sección se abre cada pestaña al
    /// ensanchar. Solo se usa cuando la pestaña NO corresponde a la sección
    /// que ya había, para no perder el sitio exacto —quien estaba en Depósitos
    /// y solo cambió el tamaño de la ventana vuelve a Depósitos, no a
    /// Ingresos.
    static func seccion(de pestana: Pestana) -> String {
        switch pestana {
        case .inicio:     return "inicio"
        case .tesoreria:  return "ingresos"
        case .revisar:    return "porRevisar"
        case .secretaria: return "membresia"
        case .ajustes:    return "config"
        }
    }
}
