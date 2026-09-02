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

    var color: Color {
        switch self {
        case .archivado: return .secondary
        default: return Paleta.aviso
        }
    }
}

/// Qué hace un botón del detalle.
enum AccionKind { case aprobar, editar, devolver, resolver, pedir }

/// Un botón de acción del detalle ("Aprobar", "Editar", "Adjuntar comprobante"…).
struct AccionRevision: Identifiable {
    var id: String { label }
    let label: String
    let kind: AccionKind
    var prominente: Bool = false
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
    let id: Int
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
