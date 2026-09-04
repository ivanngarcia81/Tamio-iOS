import Foundation

/// **La bandeja "Por revisar" no es una lista: es una consulta.**
///
/// Nadie crea un asunto por revisar. Se miran los datos que ya existen
/// —movimientos, aportantes, cortes— y de ahí sale lo que merece que una
/// persona lo mire. Igual que `sinDepositar`: no es un campo que alguien marca,
/// es algo que se deriva.
///
/// Antes esto eran diez asuntos escritos a mano en un `MockRevisarRepository`
/// que ya no existe. Ninguno salía de un dato real, así que la misma pregunta
/// —"¿cuántos hay por revisar?"— tenía CINCO respuestas a la vez: 8 en el badge
/// del tab, 8 en la sidebar, otra en el KPI del Inicio, 2 escrito a mano en el
/// corte del domingo y 1 si se contaban los movimientos marcados de verdad.
///
/// **La regla que gobierna qué entra**, tomada de la app web:
///
/// > Una alerta señala algo que una persona tiene que MIRAR, no algo que esté
/// > mal por definición.
///
/// De ahí salen dos consecuencias que no son obvias: "Otro" no cuenta como
/// categoría vacía —es una categoría legítima que alguien eligió, y marcarla
/// sería reprochar una decisión—, y un movimiento que ya espera visto bueno no
/// vuelve a salir más abajo por lo mismo que ya se va a revisar.
///
/// Si un movimiento dispara DOS alertas distintas, salen las dos: son dos cosas
/// que revisar, y esconder la segunda debajo de la primera la perdería.
enum CalculadoraRevisiones {

    /// **Gasto sin comprobante: a partir de cuánto merece una mirada.**
    /// $1,000 en la moneda de la iglesia. El prototipo lo dibuja como un
    /// interruptor de Ajustes ("Exigir comprobante en gastos mayores a
    /// $1,000") que la app todavía no tiene; mientras no exista, el número vive
    /// aquí, con nombre y comentario, y no repartido por la pantalla.
    static let umbralComprobante: Centavos = 100_000

    /// Dos movimientos son "duplicado probable" si caen dentro de esta ventana.
    static let diasDuplicado = 8

    /// Calcula la bandeja entera, **en el orden en que se atiende**: primero lo
    /// que pide una decisión, después lo que pide un arreglo, y al final lo que
    /// solo pide enterarse.
    static func calcular(movimientos: [Movimiento],
                         archivados: [Aportante],
                         cortesSinFirma: [Corte]) -> [Revision] {
        var out: [Revision] = []

        // 1 · Espera visto bueno. Pide una DECISIÓN: ¿queda o se devuelve?
        let pendientes = movimientos.filter(\.marcadoPendiente)
        out += pendientes.map(vistoBueno)

        // Los pendientes ya salieron arriba; las reglas de abajo miran el resto
        // para que un mismo movimiento no aparezca dos veces por lo mismo.
        let idsPendientes = Set(pendientes.map(\.id))
        let resto = movimientos.filter { !idsPendientes.contains($0.id) }

        // 2 · Duplicado probable. La otra que pide DECISIÓN: cuál de los dos
        // es el bueno no lo puede saber la app.
        out += duplicados(resto)

        // 3 · Gasto sin comprobante por encima del umbral.
        out += resto
            .filter { $0.tipo == .gasto && $0.comprobante == nil && $0.monto >= umbralComprobante }
            .map(sinComprobante)

        // 4 · Categoría vacía. "Otro" NO cuenta.
        out += resto.filter { categoriaVacia($0) }.map(categoriaVaciaRevision)

        // 5 · Aportante sin vincular. **La alerta con consecuencia fiscal**: un
        // diezmo sin miembro no puede salir en la constancia anual, que es el
        // papel que la iglesia entrega en enero.
        out += resto.filter { sinVincular($0) }.map(sinVincularRevision)

        // 6 · Falta la segunda firma. Va ANTES de lo archivado porque pide una
        // acción de alguien —contar o revisar y firmar— y lo archivado solo
        // pide enterarse. Solo los cortes que la PIDIERON: uno que nació sin la
        // marca no está incompleto, y anunciarlo convertiría una opción en un
        // reproche.
        out += cortesSinFirma.map(faltaFirma)

        // 7 · Miembros archivados. Ya no piden nada; se enseñan y se pueden
        // restaurar.
        out += archivados.map(archivado)

        return out
    }

    // MARK: - Reglas que necesitan explicación

    /// "Otro" es una categoría de verdad que alguien eligió. Esto caza lo que
    /// entra por importación de CSV con la columna en blanco, que es de donde
    /// salen en la práctica.
    private static func categoriaVacia(_ m: Movimiento) -> Bool {
        m.categoria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func sinVincular(_ m: Movimiento) -> Bool {
        guard m.tipo == .ingreso, m.memberUid == nil else { return false }
        return m.claveCategoria == .diezmo || m.darConstanciaAnual
    }

    /// **La huella de un movimiento para comparar duplicados**: quién, cuánto y
    /// de qué. Con miembro se usa su id; sin miembro, el concepto normalizado
    /// —así dos "Renta del anexo" del mismo monto se ven, y dos ofrendas
    /// sueltas de distinto concepto no se confunden.
    private static func huella(_ m: Movimiento) -> String {
        let quien = m.memberUid.map { "m\($0)" }
            ?? "c\((m.nota ?? m.categoria).lowercased().trimmingCharacters(in: .whitespaces))"
        return "\(m.tipo)|\(m.monto)|\(quien)"
    }

    /// Se agrupa por huella y dentro de cada grupo se compara por fecha; solo
    /// se anuncia UNA vez por pareja —el más nuevo contra el más viejo—, porque
    /// dos avisos del mismo hecho son ruido.
    private static func duplicados(_ movimientos: [Movimiento]) -> [Revision] {
        var grupos: [String: [Movimiento]] = [:]
        for m in movimientos { grupos[huella(m), default: []].append(m) }

        var out: [Revision] = []
        for grupo in grupos.values where grupo.count >= 2 {
            let orden = grupo.sorted { $0.fecha < $1.fecha }
            for i in 1..<orden.count {
                let previo = orden[i - 1], actual = orden[i]
                let dias = Calendar.current.dateComponents([.day],
                                                           from: Calendar.current.startOfDay(for: previo.fecha),
                                                           to: Calendar.current.startOfDay(for: actual.fecha)).day ?? 0
                if abs(dias) <= diasDuplicado {
                    out.append(duplicado(actual, gemelo: previo))
                }
            }
        }
        return out
    }
}

// MARK: - De un dato a un asunto de la bandeja
//
// La bandeja de iOS no enseña una alerta escueta: enseña una ficha con su
// descripción, sus campos y sus botones. Así que la calculadora no solo decide
// QUÉ entra, también construye cómo se lee. Los textos son los mismos que traía
// la semilla; lo que cambia es que ahora los valores salen del movimiento real.
extension CalculadoraRevisiones {

    // Acciones, con el mismo reparto que ya usaba la pantalla.
    private static var aprobar: AccionRevision {
        .init(label: L.t("Aprobar", "Approve"), kind: .aprobar, prominente: true)
    }
    private static var pedir: AccionRevision {
        .init(label: L.t("Pedir dato", "Request info"), kind: .pedir)
    }
    private static var editarPrim: AccionRevision {
        .init(label: L.t("Editar", "Edit"), kind: .editar, prominente: true)
    }
    private static var editarSec: AccionRevision {
        .init(label: L.t("Editar", "Edit"), kind: .editar)
    }
    private static var devolver: AccionRevision {
        .init(label: L.t("Devolver al tesorero", "Return to treasurer"), kind: .devolver)
    }
    private static func resolver(_ es: String, _ en: String) -> AccionRevision {
        .init(label: L.t(es, en), kind: .resolver, prominente: true)
    }
    /// "Ir al corte": lleva a otra pantalla, no resuelve nada, así que no va en
    /// verde prominente.
    private static func navegar(_ es: String, _ en: String) -> AccionRevision {
        .init(label: L.t(es, en), kind: .resolver, navegacion: true)
    }

    // MARK: Piezas comunes

    private static func fecha(_ m: Movimiento) -> String { Fechas.corta(m.fecha) }

    private static func importe(_ m: Movimiento) -> CampoRevision {
        .init(label: L.t("Importe", "Amount"),
              valor: Money.firmado(m.monto, ingreso: m.esIngreso),
              resalte: m.esIngreso ? .verde : .rojo)
    }

    /// Los campos de la ficha de un movimiento. El comprobante se resalta en
    /// rojo cuando falta: es el hueco que la bandeja está señalando.
    private static func campos(_ m: Movimiento) -> [CampoRevision] {
        [
            .init(label: L.t("Concepto", "Concept"), valor: m.titular),
            importe(m),
            .init(label: L.t("Categoría", "Category"),
                  valor: m.categoria.isEmpty ? L.t("Sin categoría", "No category") : m.categoria,
                  resalte: m.categoria.isEmpty ? .rojo : .ninguno),
            .init(label: L.t("Fecha", "Date"), valor: fecha(m)),
            .init(label: L.t("Método de pago", "Payment method"), valor: m.metodo),
            .init(label: L.t("Comprobante", "Receipt"),
                  valor: m.comprobante ?? L.t("Sin comprobante", "No receipt"),
                  resalte: m.comprobante == nil ? .rojo : .ninguno),
            .init(label: L.t("Registrado por", "Logged by"), valor: m.registradoPor),
            .init(label: L.t("Folio", "Folio"), valor: m.folio),
        ]
    }

    private static func base(_ m: Movimiento, tipo: RevisionTipo,
                             descripcion: String,
                             acciones: [AccionRevision],
                             toast: String) -> Revision {
        Revision(
            id: "tx-\(m.id)-\(tipo.rawValue)",
            tipo: tipo,
            concepto: m.titular,
            detalleLista: "\(m.registradoPor) · \(fecha(m))",
            descripcion: descripcion,
            seccionTitulo: m.esIngreso ? L.t("EL INGRESO", "ENTRY DETAILS")
                                       : L.t("EL GASTO", "EXPENSE DETAILS"),
            campos: campos(m),
            acciones: acciones,
            esGasto: !m.esIngreso,
            editImporte: Money.fmt(m.monto).replacingOccurrences(of: Money.moneda.simbolo, with: ""),
            editCategoria: m.categoria,
            editMetodo: m.metodo,
            editAportante: m.miembro,
            toastResuelto: toast)
    }

    // MARK: Un constructor por regla

    static func vistoBueno(_ m: Movimiento) -> Revision {
        base(m, tipo: .vistoBueno,
             descripcion: L.t("«\(m.titular)» por \(Money.fmt(m.monto)) se registró el \(fecha(m)) y quedó en espera de tu visto bueno. Hasta que se apruebe no cuenta en los totales del mes ni sale en el estado financiero.",
                              "«\(m.titular)» for \(Money.fmt(m.monto)) was recorded on \(fecha(m)) and is awaiting your approval. Until approved it doesn't count in monthly totals or appear in the financial statement."),
             acciones: [aprobar, devolver, pedir],
             toast: L.t("Aprobado.", "Approved."))
    }

    static func sinComprobante(_ m: Movimiento) -> Revision {
        base(m, tipo: .sinComprobante,
             descripcion: L.t("Este gasto de \(Money.fmt(m.monto)) no tiene comprobante, y pasa de \(Money.fmt(umbralComprobante)). Sin él no se puede justificar en una auditoría ni ante la asamblea.",
                              "This \(Money.fmt(m.monto)) expense has no receipt, and it's over \(Money.fmt(umbralComprobante)). Without one it can't be justified in an audit or before the assembly."),
             acciones: [resolver("Adjuntar comprobante", "Attach receipt"), editarSec, pedir],
             toast: L.t("Comprobante adjuntado.", "Receipt attached."))
    }

    static func categoriaVaciaRevision(_ m: Movimiento) -> Revision {
        base(m, tipo: .categoriaVacia,
             descripcion: L.t("Este movimiento se quedó sin categoría, así que no suma en ningún renglón del reporte del mes. Suele pasar al importar un archivo con la columna en blanco.",
                              "This entry has no category, so it doesn't add to any line of the monthly report. It usually happens when importing a file with that column blank."),
             acciones: [editarPrim, pedir],
             toast: L.t("Categoría asignada.", "Category assigned."))
    }

    static func sinVincularRevision(_ m: Movimiento) -> Revision {
        base(m, tipo: .sinVincular,
             descripcion: L.t("Este ingreso no está vinculado a ningún aportante del padrón, así que NO saldrá en su constancia anual — el papel que la iglesia entrega en enero.",
                              "This income isn't linked to anyone in the directory, so it will NOT appear on their annual giving statement — the paper the church hands out in January."),
             acciones: [resolver("Vincular aportante", "Link giver"), editarSec, pedir],
             toast: L.t("Aportante vinculado.", "Giver linked."))
    }

    /// El duplicado enseña LOS DOS movimientos: decidir cuál se queda sin ver
    /// el otro al lado es imposible.
    static func duplicado(_ m: Movimiento, gemelo: Movimiento) -> Revision {
        var r = base(m, tipo: .duplicado,
                     descripcion: L.t("Hay otro movimiento por el mismo importe y del mismo origen a pocos días de este. Puede ser un cobro repetido o dos aportes de verdad; solo tú puedes decidirlo.",
                                      "There's another entry for the same amount and source within a few days of this one. It could be a double entry or two genuine gifts; only you can tell."),
                     acciones: [resolver("No es duplicado", "Not a duplicate"), devolver],
                     toast: L.t("Marcado como no duplicado.", "Marked as not a duplicate."))
        r.seccionSecundaria = L.t("EL OTRO MOVIMIENTO", "THE OTHER ENTRY")
        r.camposSecundarios = campos(gemelo)
        return r
    }

    static func faltaFirma(_ c: Corte) -> Revision {
        Revision(
            id: "co-\(c.id)-firma",
            tipo: .faltaFirma,
            concepto: c.titulo,
            detalleLista: L.t("\(Money.fmt(c.montoTotal)) · \(c.registro.cuenta)",
                              "\(Money.fmt(c.montoTotal)) · \(c.registro.cuenta)"),
            descripcion: c.conteoDescuadra
                ? L.t("Alguien contó este corte y NO cuadró: contó \(Money.fmt(c.segundaConteo ?? 0)) y el corte suma \(Money.fmt(c.montoTotal)). La cifra quedó anotada sin firma.",
                      "Someone counted this cut and it did NOT add up: they counted \(Money.fmt(c.segundaConteo ?? 0)) and the cut totals \(Money.fmt(c.montoTotal)). The figure was recorded unsigned.")
                : L.t("Este corte pidió que una segunda persona contara el dinero, y todavía nadie lo ha hecho.",
                      "This cut asked for a second person to count the money, and nobody has yet."),
            seccionTitulo: L.t("EL CORTE", "THE CUT"),
            campos: [
                .init(label: L.t("Movimientos", "Entries"), valor: "\(c.cuantos)"),
                .init(label: L.t("Efectivo", "Cash"), valor: Money.fmt(c.efectivoSeleccionado)),
                .init(label: L.t("Cheques", "Checks"), valor: Money.fmt(c.chequesMonto)),
                .init(label: L.t("Total", "Total"), valor: Money.fmt(c.montoTotal), resalte: .verde),
                .init(label: L.t("Cuenta", "Account"), valor: c.registro.cuenta),
                .init(label: L.t("Contado por el asistente", "Counted by the assistant"),
                      valor: c.segundaConteo.map(Money.fmt) ?? L.t("Sin contar", "Not counted"),
                      resalte: c.conteoDescuadra ? .rojo : .ninguno),
            ],
            acciones: [navegar("Ir al corte", "Go to the cut")],
            toastResuelto: L.t("Corte firmado.", "Cut signed."))
    }

    static func archivado(_ a: Aportante) -> Revision {
        Revision(
            id: "m-\(a.id)-archivado",
            tipo: .archivado,
            concepto: a.nombre,
            detalleLista: a.estado.etiqueta,
            archivado: true,
            descripcion: L.t("\(a.nombre) está dado de baja del padrón. Sus aportes anteriores siguen contando en los reportes; solo deja de aparecer en las listas de activos.",
                             "\(a.nombre) has been removed from the directory. Their past giving still counts in reports; they simply stop appearing in active lists."),
            seccionTitulo: L.t("EL APORTANTE", "THE GIVER"),
            campos: [
                .init(label: L.t("Nombre", "Name"), valor: a.nombre),
                .init(label: L.t("Estado", "Status"), valor: a.estado.etiqueta),
            ],
            acciones: [navegar("Restaurar", "Restore")],
            toastResuelto: L.t("Aportante restaurado.", "Giver restored."))
    }
}
