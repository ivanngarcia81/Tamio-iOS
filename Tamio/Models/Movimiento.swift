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
    /// `var` por el mismo motivo que `id`: el número definitivo lo asigna el
    /// contador del servidor al guardar, no la hoja de captura.
    var folio: String
    let metodo: String
    let monto: Centavos
    let hora: String            // "11:20"
    let fecha: Date
    let registradoPor: String
    /// Valores largos del detalle.
    let miembro: String?
    let categoriaCompleta: String
    let nota: String?
    /// **Derivado, no capturado.** Un ingreso está "sin depositar" mientras
    /// ningún corte YA DEPOSITADO lo reclame. No es una casilla que alguien
    /// marca: es una ausencia en la tabla puente `corte_movimientos`. `var`
    /// porque el repositorio lo resuelve al leer — antes valía `tipo ==
    /// .ingreso`, así que TODO ingreso salía sin depositar para siempre.
    var sinDepositar: Bool
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
    /// Claves que la pantalla no edita pero que viven en la fila remota. Se
    /// arrastran en el round-trip porque, si no, una edición cualquiera las
    /// sobrescribe con nulo y se pierde el vínculo con el miembro y el
    /// desglose de la categoría.
    var memberUid: String? = nil
    var subcategoria: String? = nil
    /// Nombre del aportante que no tiene ficha en el padrón (un visitante, una
    /// aseguradora). Excluyente con `memberUid`: si está en el padrón se usa el
    /// uid y esto queda nulo.
    var aportanteNombre: String? = nil

    /// La categoría como identidad y no como texto: es lo que eligen el ícono
    /// y el color. `nil` si la iglesia la escribió a mano y no se parece a
    /// ninguna del catálogo.
    var claveCategoria: CategoriaClave? { Catalogos.clave(deEtiqueta: categoria) }

    /// La forma del dinero. Es lo que decide si suma en el chip de efectivo o
    /// en el de cheques del corte.
    var claveMetodo: Catalogos.MetodoClave? { Catalogos.clave(deMetodo: metodo) }
    var esEfectivo: Bool { claveMetodo == .efectivo }
    var esCheque: Bool { claveMetodo == .cheque }
    /// "Cheque 8823" → "8823". El número que pide el banco en la ficha.
    var numeroCheque: String? { Catalogos.numeroDeCheque(metodo) }

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
