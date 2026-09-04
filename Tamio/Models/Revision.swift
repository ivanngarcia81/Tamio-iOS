import Foundation
import SwiftUI

/// Tipo de asunto por revisar. Gobierna el glifo, el color y la etiqueta.
enum RevisionTipo: String, CaseIterable, Identifiable {
    case vistoBueno, sinComprobante, duplicado, categoriaVacia
    case sinVincular, recurrenteVencido, faltaFirma, archivado
    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .vistoBueno: return L.t("Espera visto bueno", "Awaiting approval")
        case .sinComprobante: return L.t("Gasto sin comprobante", "Expense without receipt")
        case .duplicado: return L.t("Duplicado probable", "Likely duplicate")
        case .categoriaVacia: return L.t("Categoría vacía", "Empty category")
        case .sinVincular: return L.t("Aportante sin vincular", "Unlinked giver")
        case .recurrenteVencido: return L.t("Recurrente vencido", "Overdue recurring")
        case .faltaFirma: return L.t("Falta la segunda firma", "Second signature missing")
        case .archivado: return L.t("Miembro archivado", "Archived member")
        }
    }

    var etiquetaCorta: String {
        switch self {
        case .vistoBueno:        return L.t("Visto bueno", "Needs approval")
        case .sinComprobante:    return L.t("Sin comprobante", "No receipt")
        case .duplicado:         return L.t("Duplicado", "Duplicate")
        case .categoriaVacia:    return L.t("Sin categoría", "No category")
        case .sinVincular:       return L.t("Sin aportante", "No giver")
        case .recurrenteVencido: return L.t("Recurrente", "Overdue")
        case .faltaFirma:        return L.t("Falta firma", "Missing signature")
        case .archivado:         return L.t("Archivado", "Archived")
        }
    }

    var glifo: String {
        switch self {
        case .vistoBueno, .sinComprobante: return "!"
        case .duplicado: return "D"
        case .categoriaVacia: return "C"
        case .sinVincular: return "M"
        case .recurrenteVencido: return "R"
        case .faltaFirma: return "F"
        case .archivado: return "A"
        }
    }

    var estadoVisual: Paleta.Estado {
        // Todo lo que está en la bandeja espera algo de ti; lo archivado ya no.
        self == .archivado ? .terminal : .pendiente
    }
    var color: Color { estadoVisual.color }
}

/// Qué hace un botón del detalle.
/// Qué hace un botón del detalle. **Cada caso es un comportamiento distinto**:
/// antes `aprobar`, `devolver` y `resolver` acababan los tres en la misma
/// llamada y solo cambiaba el texto del aviso, así que devolver un movimiento
/// al tesorero hacía lo mismo que aprobarlo. Y `pedir` no pedía nada a nadie:
/// enseñaba "Se pidió más información" y ahí acababa.
enum AccionKind {
    /// Da el visto bueno: el movimiento pasa a `aprobado` y cuenta en los
    /// totales. **Solo tiene sentido en un movimiento pendiente**: las demás
    /// alertas no cuelgan del estado sino del dato, así que aprobar no las
    /// apagaría y el usuario pulsaría un botón que no cambia nada.
    case aprobar
    /// Abre la hoja de edición, que es donde se arregla el hueco. El nombre del
    /// botón dice qué se va a hacer allí ("Adjuntar y aprobar", "Vincular
    /// aportante"), no cómo se llama la pantalla que abre.
    case editar
    /// Devuelve al tesorero: pasa a `rechazado` y deja de contar en el mes.
    case devolver
    /// Lleva al corte que espera la segunda firma.
    case irAlCorte
    /// Reactiva a un aportante dado de baja.
    case restaurar
}

/// Un botón de acción del detalle ("Aprobar", "Editar", "Adjuntar comprobante"…).
struct AccionRevision: Identifiable {
    var id: String { label }
    let label: String
    let kind: AccionKind
    var prominente: Bool = false
    /// La acción solo lleva a otra pantalla; no resuelve el pendiente. Se
    /// dibuja distinto: aprobar y navegar no pueden verse igual, y menos
    /// apiladas una tras otra.
    var navegacion: Bool = false
}

/// Resalte de un campo del detalle (verde para montos, rojo para faltantes).
enum ResalteCampo { case ninguno, verde, rojo }

/// Un campo "etiqueta: valor" del detalle del asunto.
struct CampoRevision: Identifiable {
    var id: String { label }
    let label: String
    let valor: String
    var resalte: ResalteCampo = .ninguno
}

/// Un asunto por revisar (bandeja de Tesorería/Secretaría).
struct Revision: Identifiable, Hashable {
    let id: String
    let tipo: RevisionTipo
    let concepto: String        // "Ofrenda del domingo" / nombre del miembro
    let detalleLista: String    // subtítulo en la lista
    var archivado: Bool = false

    // Detalle
    let descripcion: String
    let seccionTitulo: String
    let campos: [CampoRevision]
    var seccionSecundaria: String? = nil        // duplicado: "EL OTRO MOVIMIENTO"
    var camposSecundarios: [CampoRevision] = []
    var notaPie: String? = nil
    let acciones: [AccionRevision]

    // Para la hoja "Editar ingreso/gasto" (solo movimientos)
    var esGasto: Bool = false
    var editImporte: String? = nil       // "8,420.00"
    var editCategoria: String? = nil
    var editMetodo: String? = nil
    var editAportante: String? = nil

    /// Mensaje del toast al resolver con la acción primaria (kind .resolver).
    var toastResuelto: String = ""

    var editable: Bool { editImporte != nil }

    static func == (l: Revision, r: Revision) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
