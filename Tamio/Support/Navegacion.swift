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
}
