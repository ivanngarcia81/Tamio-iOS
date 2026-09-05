import Foundation

/// El punto de la revisión en que está un movimiento. Los rawValue son los que
/// viajan a `transactions.estado`.
enum EstadoRevision: String {
    case pendiente, aprobado, rechazado

    var etiqueta: String {
        switch self {
        case .pendiente: return L.t("Espera visto bueno", "Awaiting approval")
        case .aprobado:  return L.t("Aprobado", "Approved")
        case .rechazado: return L.t("Devuelto al tesorero", "Returned to treasurer")
        }
    }
}

/// Un movimiento completo, como lo pide la pantalla Ingresos/Gastos del handoff:
/// además de lo de la lista, trae los campos del detalle, la nota, el estado de
/// depósito, el comprobante y el rastro de auditoría.
struct Movimiento: Identifiable {
    /// `var` (no `let`): al crear un movimiento nuevo se manda con id vacío
    /// y Supabase asigna el UID real en el INSERT.
    var id: String
    let tipo: TipoMovimiento
    /// Categoría corta para el titular y el punto ("Diezmo", "Servicios").
    /// `var`: la bandeja "Por revisar" la asigna cuando un movimiento llegó sin
    /// ella —lo típico al importar un CSV con la columna en blanco—.
    var categoria: String
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
    /// **En qué punto de la revisión está.** Tres valores, los mismos que
    /// `transactions.estado` en Supabase: `pendiente` espera visto bueno,
    /// `aprobado` cuenta en los totales, `rechazado` fue devuelto al tesorero y
    /// NO cuenta en ningún sitio.
    ///
    /// Antes solo existía `marcadoPendiente`, un booleano, así que "devolver al
    /// tesorero" no tenía dónde escribirse: la bandeja hacía lo mismo que
    /// aprobar y solo cambiaba el texto del aviso. Dos acciones opuestas con el
    /// mismo efecto.
    var estadoRevision: EstadoRevision = .aprobado

    /// Conveniencia sobre `estadoRevision`, para no reescribir los sitios que
    /// solo preguntan "¿espera visto bueno?".
    var marcadoPendiente: Bool {
        get { estadoRevision == .pendiente }
        set { estadoRevision = newValue ? .pendiente : .aprobado }
    }
    var incluidoEnCorte: Bool = true
    /// Solo ingresos. **Por omisión NO**, igual que la hoja de captura y que la
    /// app web (`emitir_constancia` nace en 0). Estaba en `true` aquí, y como
    /// la bandeja avisa de "aportante sin vincular" cuando un ingreso va a la
    /// constancia y no tiene miembro, ese default hacía saltar la regla en
    /// TODOS los ingresos de golpe.
    var darConstanciaAnual: Bool = false
    /// **Se repite cada mes, y nada más: no sabe desde cuándo ni hasta cuándo.**
    ///
    /// Con un booleano suelto no se puede saber si un recurrente VENCIÓ, que es
    /// lo que la bandeja tendría que avisar: "el pago de la luz se repite cada
    /// mes y este mes no está". Hacen falta dos datos que hoy no existen —desde
    /// qué mes se repite y cuál fue el último generado— y probablemente una
    /// tabla propia, porque un recurrente no es un movimiento: es la regla que
    /// los crea.
    ///
    /// Por eso "Por revisar" NO tiene la regla de recurrente vencido. Estuvo
    /// declarada en `RevisionTipo` con etiqueta e inicial, sin que nada la
    /// generara nunca; se quitó de allí y la deuda queda escrita aquí, que es
    /// donde se va a resolver. Mientras tanto el interruptor de la hoja de
    /// captura guarda la intención, y el detalle la enseña.
    var repiteMensual: Bool = false
    /// **Qué serie recurrente lo generó**, si lo generó alguna. Apunta a
    /// `MovimientoRecurrente.id` y viaja a `transactions.recurrente_uid`.
    ///
    /// Sirve para lo que un movimiento suelto no puede: cambiarle el importe a
    /// una renta entera cuando sube, o retirar la serie completa cuando el
    /// contrato acaba. Sin este vínculo, los movimientos que genera un
    /// recurrente son indistinguibles de los capturados a mano.
    var recurrenteId: String? = nil
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
