import Foundation
import SwiftUI

/// Tipo de asunto por revisar. Gobierna el glifo, el color y la etiqueta.
///
/// **Aquí solo hay tipos que la bandeja SABE producir.** Había un octavo,
/// `recurrenteVencido`, con su etiqueta, su forma corta y su inicial "R", que
/// `CalculadoraRevisiones` no generaba nunca: la pantalla prometía un aviso que
/// no podía dar, y el filtro por tipo lo listaba como una opción que siempre
/// devolvía cero. No se puede construir desde aquí — hace falta antes que un
/// movimiento recurrente sepa desde cuándo se repite y cuándo se generó por
/// última vez, y eso vive en `Movimiento.repiteMensual`, donde queda anotado
/// qué falta. Cuando el modelo lo soporte, este caso vuelve.
enum RevisionTipo: String, CaseIterable, Identifiable {
    case vistoBueno, sinComprobante, duplicado, categoriaVacia
    case sinVincular, faltaFirma, archivado
    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .vistoBueno: return L.t("Espera visto bueno", "Awaiting approval")
        case .sinComprobante: return L.t("Gasto sin comprobante", "Expense without receipt")
        case .duplicado: return L.t("Duplicado probable", "Likely duplicate")
        case .categoriaVacia: return L.t("Categoría vacía", "Empty category")
        case .sinVincular: return L.t("Aportante sin vincular", "Unlinked giver")
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
enum AccionKind: Equatable {
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
struct AccionRevision: Identifiable, Equatable {
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
enum ResalteCampo: Equatable { case ninguno, verde, rojo }

/// Un campo "etiqueta: valor" del detalle del asunto.
struct CampoRevision: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let valor: String
    var resalte: ResalteCampo = .ninguno
}

/// Un asunto por revisar (bandeja de Tesorería/Secretaría).
struct Revision: Identifiable {
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
    /// **La nota del movimiento, que es lo que la hoja llama "Concepto".**
    /// Va aparte de `concepto` a propósito: ese es el TITULAR de la lista y sale
    /// compuesto de categoría y persona (`Movimiento.titular`), o sea que no es
    /// un campo que exista para escribirlo. La hoja prellenaba el campo con el
    /// titular, así que guardarlo habría metido "Misiones · Iglesia La
    /// Esperanza" dentro de la nota. La hoja de alta ya mapea su "Concepto" a
    /// `nota`; ahora las dos coinciden.
    var editNota: String? = nil
    /// La fecha del movimiento. La hoja la ofrece con un `DatePicker` y hasta
    /// ahora no se escribía en ninguna parte.
    var editFecha: Date? = nil

    /// Mensaje del toast al resolver con la acción primaria (kind .resolver).
    var toastResuelto: String = ""

    var editable: Bool { editImporte != nil }
}

// MARK: - Igualdad

/// **La igualdad de un asunto es su CONTENIDO, no su id.**
///
/// Aquí había `static func == (l, r) { l.id == r.id }`, y eso hace que SwiftUI
/// dé por buena la vista que ya tiene: dos asuntos con el mismo id y distinto
/// importe son "iguales", así que corregir la cifra escribía el dato y **la
/// pantalla se quedaba con la vieja**. Medido con la app corriendo el 9-sep: el
/// log decía `asuntos(): 106 vale 100` mientras la ficha seguía enseñando
/// −$600.00, y salir del detalle y volver a entrar tampoco lo refrescaba.
///
/// **Solo se toca `Revision`.** El mismo `==` por id está escrito en
/// `Movimiento`, `Aportante`, `Acta`, `Servicio`, `Corte`, `Miembro` y
/// `Apunte`, y cambiarlos todos mueve los `Picker`, los `onChange` y los `Set`
/// de la app entera: eso es una decisión de Iván con una tanda de regresión
/// detrás, y está anotado como tal en `docs/CONTEXTO.md` §0.-7. Aquí se puede
/// hacer suelto porque **`Revision` no está en ningún `Set` ni en ningún
/// `onChange`** —comprobado con grep— y su `Identifiable` sigue siendo el id,
/// que es lo que usan `ForEach` y `.sheet(item:)`.
///
/// El `hash` sigue siendo el id a propósito: dos asuntos iguales tienen el mismo
/// id, así que sigue cumpliendo que lo igual comparta hash, y no cambia el
/// comportamiento de nada que ya lo estuviera usando.
extension Revision: Equatable {
    static func == (l: Revision, r: Revision) -> Bool {
        l.id == r.id && l.tipo == r.tipo && l.concepto == r.concepto
            && l.detalleLista == r.detalleLista && l.archivado == r.archivado
            && l.descripcion == r.descripcion && l.seccionTitulo == r.seccionTitulo
            && l.campos == r.campos && l.seccionSecundaria == r.seccionSecundaria
            && l.camposSecundarios == r.camposSecundarios && l.notaPie == r.notaPie
            && l.acciones == r.acciones && l.esGasto == r.esGasto
            && l.editImporte == r.editImporte && l.editCategoria == r.editCategoria
            && l.editMetodo == r.editMetodo && l.editAportante == r.editAportante
            && l.editNota == r.editNota && l.editFecha == r.editFecha
            && l.toastResuelto == r.toastResuelto
    }
}

extension Revision: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
