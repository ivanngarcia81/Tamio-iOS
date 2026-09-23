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

    /// **La bienvenida a la vista.** Aquí y no en la raíz porque la vuelve a
    /// abrir un menú —Ayuda › Bienvenida a Tamio, como en el handoff—, y la
    /// barra de menús no alcanza el estado privado de una vista. Arranca de la
    /// bandera del aparato, que es la misma del iPhone.
    var viendoBienvenida = !PreferenciasApp.bienvenidaVista

    /// **El testigo del ⌘N: "la pantalla de delante, abre tu alta".**
    ///
    /// Vive aquí por el mismo motivo que `seccion`, y esta vez el motivo es un
    /// fallo medido: el ⌘N estaba declarado en el botón de la cabecera de
    /// Agenda, así que **solo respondía con el foco en el contenido**. Con el
    /// foco en la barra lateral la "n" se la come la selección por teclas de la
    /// lista, y el atajo no hacía nada —que es peor que no tenerlo, porque se
    /// aprende y se usa a ciegas—. Un menú es una escena hermana de la ventana
    /// y no depende de dónde esté el foco; para alcanzarlo desde ahí, el
    /// disparador tiene que estar fuera de la vista.
    ///
    /// **Uno solo para las catorce secciones, y no uno por pantalla.** Solo
    /// existe la pantalla que se está viendo, así que no hay dos que puedan
    /// responder a la vez; quién abre qué lo dice `SeccionMac.altaTitulo`. La
    /// pantalla lo apaga al cerrar su hoja.
    var pidiendoAlta = false

    /// **Lo que "Duplicar ⌘D" copia de un movimiento para la captura rápida.**
    ///
    /// La captura es otra escena (`Window`), así que la tabla no puede
    /// rellenarle los campos directamente: lo deja aquí, que lo comparten las
    /// dos, y la captura lo consume al leerlo. **Solo rellena, no guarda**:
    /// guardar sigue siendo ⌘S, con quien captura mirando.
    struct PlantillaCaptura: Equatable {
        let tipo: TipoMovimiento
        let categoria: String
        let metodo: String
        let monto: Centavos
    }
    var plantillaCaptura: PlantillaCaptura?

    /// El testigo de "Importar personas…", por el mismo motivo que
    /// `pidiendoAlta`: el menú es una escena hermana y no alcanza el estado de
    /// una vista. Lo encienden el menú, la invitación, el estado vacío de
    /// Membresía y Configuración › Datos; lo apaga `ImportarPersonasMac` al
    /// abrir el selector.
    var pidiendoImportarAportantes = false
    /// Lo mismo para «Importar aportes…».
    var pidiendoImportarAportes = false

    /// **«Trae tus datos», la invitación que sigue a la bienvenida.**
    ///
    /// Dos tiempos, y el primero es solo una promesa: `ofrecerTraerDatos` se
    /// enciende al cerrar la bienvenida, pero la invitación no sale hasta que
    /// la primera sincronización termina. Decidirlo antes sería mirar un
    /// padrón vacío porque aún no ha bajado, y ofrecerle importar a una
    /// secretaria cuya iglesia ya está montada —el caso que el handoff pide
    /// expresamente evitar—.
    var ofrecerTraerDatos = false
    /// En DEBUG, `-mostrarTraerDatos YES` la abre al arrancar: la iglesia de
    /// prueba ya tiene padrón y sin esto la invitación no se puede mirar.
    #if DEBUG
    var viendoTraerDatos = UserDefaults.standard.bool(forKey: "mostrarTraerDatos")
    #else
    var viendoTraerDatos = false
    #endif

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
    /// **Cómoda por omisión**, que es la densidad con la que está dibujado el
    /// handoff. Arrancaba en media y las filas salían más apretadas que el
    /// diseño.
    var densidad: Densidad = .comoda

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

    /// El alto de fila que toca ahora mismo.
    var altoDeFila: CGFloat { densidad.altoFila }
    func ponerFiltro(_ texto: String, en s: SeccionMac) { filtros[s.rawValue] = texto }
}
