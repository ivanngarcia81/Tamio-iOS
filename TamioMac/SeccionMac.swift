import SwiftUI

/// **Las secciones de la app de Mac, en el orden de la maqueta.**
///
/// Los identificadores son LOS MISMOS que usa `Navegacion` en iOS —`"inicio"`,
/// `"porRevisar"`, `"config"`…— y eso no es casualidad: así la selección de
/// esta barra lateral se guarda tal cual en el estado compartido, y lo que ya
/// mueve la navegación desde dentro de una pantalla —el "Ver todos" del
/// Inicio— sigue funcionando sin traducir nada entre plataformas.
///
/// **Están las quince, incluidas las cuatro que la maqueta no dibuja**:
/// Registro de servicios, Cartas y traslados, Informes de membresía y el
/// Registro. Se decidió el 19-sep REDISEÑARLAS para el Mac en vez de traer las
/// del iPad tal cual: el Mac, el iPad y el iPhone son apps distintas, no copias
/// la una de la otra.
///
/// Rediseñar no es inventar de cero. La maqueta ya define los patrones y cada
/// una cae en uno: Registro y Servicios en la TABLA ordenable de Ingresos;
/// Cartas e Informes en el patrón de Reportes —lista a la izquierda, documento
/// a la derecha—. Lo que cambia es el contenido, no el lenguaje.
enum SeccionMac: String, CaseIterable, Identifiable {
    case inicio
    case ingresos, gastos, miembros, reportes, depositos, porRevisar
    case membresia, actas, servicios, cartas, informes, agenda
    case registro, config

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
        case .membresia, .actas, .servicios, .cartas, .informes, .agenda:
            return .secretaria
        case .registro, .config: return .pie
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
        case .servicios:  return L.t("Registro de servicios", "Service log")
        case .cartas:     return L.t("Cartas y traslados", "Letters & transfers")
        case .informes:   return L.t("Informes de membresía", "Membership reports")
        case .agenda:     return L.t("Agenda", "Calendar")
        case .registro:   return L.t("Registro", "Log")
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
        case .servicios:  return "book"
        case .cartas:     return "envelope"
        case .informes:   return "doc.plaintext"
        case .agenda:     return "calendar"
        case .registro:   return "list.bullet.rectangle"
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
        case .servicios, .cartas, .informes, .agenda, .registro, .config:
            return nil
        }
    }

    /// Cómo se escribe el atajo al lado del rótulo, como en la maqueta.
    var atajoEscrito: String {
        if let atajo { return "⌘\(atajo)" }
        return self == .config ? "⌘," : ""
    }

    /// **Las que enseñan una hoja en vez de una tabla.**
    ///
    /// Cartas e Informes traen el papel a la derecha, y ese papel ES el
    /// detalle: abrirles además el inspector dejaría la hoja en una rendija.
    var esDeDocumento: Bool {
        // Inicio entra aquí aunque no sea una hoja: es un panorama que ya
        // ocupa el ancho entero, y no hay "una fila elegida" que inspeccionar.
        self == .cartas || self == .informes || self == .inicio
    }

    /// Las de un grupo, en orden de declaración.
    static func del(_ grupo: Grupo) -> [SeccionMac] {
        allCases.filter { $0.grupo == grupo }
    }
}
