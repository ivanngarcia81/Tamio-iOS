import SwiftUI

/// **Las secciones de la app de Mac, en el orden de la maqueta.**
///
/// Los identificadores son LOS MISMOS que usa `Navegacion` en iOS —`"inicio"`,
/// `"porRevisar"`, `"config"`…— y eso no es casualidad: así la selección de
/// esta barra lateral se guarda tal cual en el estado compartido, y lo que ya
/// mueve la navegación desde dentro de una pantalla —el "Ver todos" del
/// Inicio— sigue funcionando sin traducir nada entre plataformas.
///
/// **Faltan cuatro que SÍ existen en iOS**: Registro de servicios, Cartas y
/// traslados, Informes de membresía y el Registro de auditoría. No es un
/// olvido. La maqueta de Mac no las dibuja —solo asoma el registro como un
/// "Audit log ⌥⌘L" en el menú Tesorería— y está sin decidir si se portan
/// desde el iPad o si la primera versión del Mac sale sin ellas. Cuando se
/// decida, entran aquí: añadir un `case` las pone en la barra, en el menú y en
/// el enrutador de golpe.
enum SeccionMac: String, CaseIterable, Identifiable {
    case inicio
    case ingresos, gastos, miembros, reportes, depositos, porRevisar
    case membresia, actas, agenda
    case config

    var id: String { rawValue }

    /// Dónde va cada una dentro de la barra lateral.
    enum Grupo: Int, CaseIterable, Identifiable {
        case portada, tesoreria, secretaria, pie
        var id: Int { rawValue }

        /// Los grupos sin título no dibujan cabecera **ni triángulo de
        /// plegado**: plegar un grupo de un solo elemento no ahorra nada y deja
        /// un control que no hace nada visible.
        var titulo: String? {
            switch self {
            case .portada, .pie: return nil
            case .tesoreria:     return L.t("TESORERÍA", "TREASURY")
            case .secretaria:    return L.t("SECRETARÍA", "SECRETARY")
            }
        }
    }

    var grupo: Grupo {
        switch self {
        case .inicio: return .portada
        case .ingresos, .gastos, .miembros, .reportes, .depositos, .porRevisar:
            return .tesoreria
        case .membresia, .actas, .agenda: return .secretaria
        case .config: return .pie
        }
    }

    /// El rótulo. **Sale de `Sidebar.swift` palabra por palabra**, para que la
    /// misma iglesia con un iPad y un Mac no lea dos nombres para lo mismo.
    var titulo: String {
        switch self {
        case .inicio:     return L.t("Inicio", "Home")
        case .ingresos:   return L.t("Ingresos", "Income")
        case .gastos:     return L.t("Gastos", "Expenses")
        case .miembros:   return L.t("Aportantes", "Contributors")
        case .reportes:   return L.t("Reportes", "Reports")
        case .depositos:  return L.t("Depósitos", "Deposits")
        case .porRevisar: return L.t("Por revisar", "To review")
        case .membresia:  return L.t("Membresía", "Membership")
        case .actas:      return L.t("Actas", "Minutes")
        case .agenda:     return L.t("Agenda", "Calendar")
        case .config:     return L.t("Configuración", "Settings")
        }
    }

    /// Los símbolos son los de `Sidebar.swift`, por el mismo motivo que los
    /// rótulos. Todos existen en macOS 26.
    var icono: String {
        switch self {
        case .inicio:     return "house"
        case .ingresos:   return "arrow.down"
        case .gastos:     return "arrow.up"
        case .miembros:   return "person.2"
        case .reportes:   return "chart.bar"
        case .depositos:  return "building.columns"
        case .porRevisar: return "tray"
        case .membresia:  return "person.text.rectangle"
        case .actas:      return "doc.text"
        case .agenda:     return "calendar"
        case .config:     return "gearshape"
        }
    }

    /// El número de ⌘1…⌘9, cuando lo tiene.
    ///
    /// **Solo nueve, y en el orden de la maqueta.** Agenda se queda sin atajo
    /// —no cabe en un dígito— y Configuración usa ⌘, que es el de todo el
    /// sistema y no se toca.
    var atajo: Character? {
        switch self {
        case .inicio:     return "1"
        case .ingresos:   return "2"
        case .gastos:     return "3"
        case .miembros:   return "4"
        case .reportes:   return "5"
        case .depositos:  return "6"
        case .porRevisar: return "7"
        case .membresia:  return "8"
        case .actas:      return "9"
        case .agenda, .config: return nil
        }
    }

    /// Cómo se escribe el atajo al lado del rótulo, como en la maqueta.
    var atajoEscrito: String {
        if let atajo { return "⌘\(atajo)" }
        return self == .config ? "⌘," : ""
    }

    /// Las de un grupo, en orden de declaración.
    static func del(_ grupo: Grupo) -> [SeccionMac] {
        allCases.filter { $0.grupo == grupo }
    }
}
