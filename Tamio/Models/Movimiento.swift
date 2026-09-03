import Foundation

/// Un movimiento completo, como lo pide la pantalla Ingresos/Gastos del handoff:
/// además de lo de la lista, trae los campos del detalle, la nota, el estado de
/// depósito, el comprobante y el rastro de auditoría.
struct Movimiento: Identifiable {
    /// `var` (no `let`): al crear un movimiento nuevo se manda con id vacío
    /// y Supabase asigna el UID real en el INSERT.
    var id: String
    let tipo: TipoMovimiento
    /// Categoría corta para el titular y el punto ("Diezmo", "Servicios").
    let categoria: String
    let persona: String?
    let folio: String
    let metodo: String
    let monto: Centavos
    let hora: String            // "11:20"
    let fecha: Date
    let registradoPor: String
    /// Valores largos del detalle.
    let miembro: String?
    let categoriaCompleta: String
    let nota: String?
    let sinDepositar: Bool
    var comprobante: String?    // "sobre-1042.jpg" — var: se puede adjuntar/reemplazar
    let auditoria: [AuditEntry]
    // Campos adicionales del formulario completo
    var pagadoA: String? = nil          // beneficiario del gasto (required para gastos)
    var rfc: String? = nil
    var notasAuditoria: String? = nil
    var marcadoPendiente: Bool = false  // envía a "Por revisar"
    var incluidoEnCorte: Bool = true
    var darConstanciaAnual: Bool = true // solo ingresos
    var repiteMensual: Bool = false

    var titular: String {
        if let persona, !persona.isEmpty { return "\(categoria) · \(persona)" }
        return categoria
    }
    var subtitulo: String { "Folio \(folio) · \(metodo)" }
    var esIngreso: Bool { tipo == .ingreso }
}

extension Movimiento: Hashable {
    static func == (l: Movimiento, r: Movimiento) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Una entrada del rastro de auditoría (título + detalle).
struct AuditEntry: Identifiable {
    let id: String
    let titulo: String
    let detalle: String
}
