import Foundation

protocol RevisarRepository {
    func asuntos() async -> [Revision]
    func resolver(id: String) async
    /// Resuelve de golpe solo los tipos que se le pasen. No existe un
    /// "resuélvelo todo": un duplicado o un gasto sin comprobante no se
    /// aprueban en bloque, que es justo lo que su bandera está pidiendo.
    func resolverTodos(tipos: Set<RevisionTipo>) async
    func restaurar(_ r: Revision) async
    func actualizar(_ r: Revision) async
}

/// Datos falsos que reproducen la bandeja "Por revisar" del handoff (10 asuntos,
/// 2 miembros archivados). Almacén estático mutable: aprobar / devolver / editar
/// persisten mientras vive la app (mañana es GRDB).
struct MockRevisarRepository: RevisarRepository {
    private static var almacen: [Revision] = semilla

    func asuntos() async -> [Revision] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.almacen
    }
    func resolver(id: String) async { Self.almacen.removeAll { $0.id == id } }
    func resolverTodos(tipos: Set<RevisionTipo>) async {
        Self.almacen.removeAll { !$0.archivado && tipos.contains($0.tipo) }
    }
    func restaurar(_ r: Revision) async {
        if !Self.almacen.contains(where: { $0.id == r.id }) {
            Self.almacen.insert(r, at: 0)
        }
    }
    func actualizar(_ r: Revision) async {
        if let i = Self.almacen.firstIndex(where: { $0.id == r.id }) { Self.almacen[i] = r }
    }

    /// Asuntos sin archivar. El Dashboard lo lee para su aviso "por revisar",
    /// que antes llevaba un 7 suelto en su propia semilla mientras el badge del
    /// tab y esta bandeja contaban 8. Una sola fuente para los tres.
    static var porRevisarCount: Int { almacen.filter { !$0.archivado }.count }

    // Constructores de acciones comunes.
    private static var aprobar: AccionRevision { .init(label: L.t("Aprobar", "Approve"), kind: .aprobar, prominente: true) }
    private static var pedir: AccionRevision { .init(label: L.t("Pedir dato", "Request info"), kind: .pedir) }
    private static var editarPrim: AccionRevision { .init(label: L.t("Editar", "Edit"), kind: .editar, prominente: true) }
    private static var editarSec: AccionRevision { .init(label: L.t("Editar", "Edit"), kind: .editar) }
    private static var devolver: AccionRevision { .init(label: L.t("Devolver al tesorero", "Return to treasurer"), kind: .devolver) }
    private static func resolver(_ es: String, _ en: String) -> AccionRevision { .init(label: L.t(es, en), kind: .resolver, prominente: true) }
    /// "Ver movimientos recurrentes", "Ir al corte": llevan a otra pantalla, no
    /// resuelven nada, así que no van en verde prominente.
    private static func navegar(_ es: String, _ en: String) -> AccionRevision {
        .init(label: L.t(es, en), kind: .resolver, navegacion: true)
    }

    private static var semilla: [Revision] {
        [
            Revision(id: "1", tipo: .vistoBueno, concepto: L.t("Ofrenda del domingo", "Sunday offering"),
                     detalleLista: L.t("Rocío Ibarra · 30 ago 2026", "Rocío Ibarra · Aug 30, 2026"),
                     descripcion: L.t("«Ofrenda del domingo» por $8,420.00 se registró el 30 ago 2026 y quedó en espera de tu visto bueno. Hasta que se apruebe no cuenta en los totales del mes ni sale en el estado financiero.",
                                      "«Sunday offering» for $8,420.00 was recorded on Aug 30, 2026 and is awaiting your approval. Until approved it doesn't count in monthly totals or appear in the financial statement."),
                     seccionTitulo: L.t("EL INGRESO", "ENTRY DETAILS"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Ofrenda del domingo", "Sunday offering")),
                        .init(label: L.t("Importe", "Amount"), valor: "+$8,420.00", resalte: .verde),
                        .init(label: L.t("Categoría", "Category"), valor: L.t("Ofrenda general", "General offering")),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("30 ago 2026", "Aug 30, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Efectivo", "Cash")),
                        .init(label: L.t("Comprobante", "Receipt"), valor: L.t("Sin comprobante", "No receipt"), resalte: .rojo),
                        .init(label: L.t("Registrado por", "Logged by"), valor: L.t("Rocío Ibarra · Secretaría", "Rocío Ibarra · Secretary")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0114"),
                     ],
                     acciones: [aprobar, devolver, pedir],
                     editImporte: "8,420.00", editCategoria: L.t("Ofrenda general", "General offering"), editMetodo: L.t("Efectivo", "Cash")),

            Revision(id: "2", tipo: .vistoBueno, concepto: L.t("Compra de sillas", "Chairs purchase"),
                     detalleLista: L.t("Luis Aguilar · 29 ago 2026", "Luis Aguilar · Aug 29, 2026"),
                     descripcion: L.t("«Compra de sillas» por $6,900.00 se registró el 29 ago 2026 y quedó en espera de tu visto bueno. Hasta que se apruebe no cuenta en los totales del mes ni sale en el estado financiero.",
                                      "«Chairs purchase» for $6,900.00 was recorded on Aug 29, 2026 and is awaiting your approval. Until approved it doesn't count in monthly totals or appear in the financial statement."),
                     seccionTitulo: L.t("EL GASTO", "EXPENSE DETAILS"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Compra de sillas", "Chairs purchase")),
                        .init(label: L.t("Importe", "Amount"), valor: "−$6,900.00", resalte: .rojo),
                        .init(label: L.t("Categoría", "Category"), valor: L.t("Mobiliario", "Furniture")),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("29 ago 2026", "Aug 29, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Transferencia", "Transfer")),
                        .init(label: L.t("Comprobante", "Receipt"), valor: "factura-sillas.pdf"),
                        .init(label: L.t("Registrado por", "Logged by"), valor: L.t("Luis Aguilar · Tesorería", "Luis Aguilar · Treasury")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0111"),
                     ],
                     acciones: [aprobar, devolver, pedir],
                     esGasto: true, editImporte: "6,900.00", editCategoria: L.t("Mobiliario", "Furniture"), editMetodo: L.t("Transferencia", "Transfer")),

            Revision(id: "3", tipo: .sinComprobante, concepto: L.t("Mantenimiento del aire", "AC maintenance"),
                     detalleLista: L.t("Luis Aguilar · 26 ago 2026", "Luis Aguilar · Aug 26, 2026"),
                     descripcion: L.t("«Mantenimiento del aire» ($4,350.00) se pagó por transferencia el 26 ago 2026 y no tiene comprobante adjunto. Se avisa porque pasa de $1,000.00; por debajo de esa cifra no se pide.",
                                      "«AC maintenance» ($4,350.00) was paid by transfer on Aug 26, 2026 and has no receipt attached. Flagged because it's over $1,000.00; below that it isn't required."),
                     seccionTitulo: L.t("EL GASTO", "EXPENSE DETAILS"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Mantenimiento del aire", "AC maintenance")),
                        .init(label: L.t("Importe", "Amount"), valor: "−$4,350.00", resalte: .rojo),
                        .init(label: L.t("Categoría", "Category"), valor: L.t("Mantenimiento", "Maintenance")),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("26 ago 2026", "Aug 26, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Transferencia", "Transfer")),
                        .init(label: L.t("Comprobante", "Receipt"), valor: L.t("Sin comprobante", "No receipt"), resalte: .rojo),
                        .init(label: L.t("Registrado por", "Logged by"), valor: L.t("Luis Aguilar · Tesorería", "Luis Aguilar · Treasury")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0103"),
                     ],
                     acciones: [aprobar, devolver, pedir],
                     esGasto: true, editImporte: "4,350.00", editCategoria: L.t("Mantenimiento", "Maintenance"), editMetodo: L.t("Transferencia", "Transfer")),

            Revision(id: "4", tipo: .duplicado, concepto: L.t("Renta del anexo", "Annex rent"),
                     detalleLista: L.t("Luis Aguilar · 28 ago 2026", "Luis Aguilar · Aug 28, 2026"),
                     descripcion: L.t("«Renta del anexo» por $3,500.00 del 28 ago 2026 se parece a otro de $3,500.00 del 22 ago 2026: mismo importe, misma contraparte y pocos días de diferencia. Puede ser un cobro real repetido o el mismo capturado dos veces.",
                                      "«Annex rent» for $3,500.00 on Aug 28, 2026 looks like another for $3,500.00 on Aug 22, 2026: same amount, same counterparty, a few days apart. It could be a real repeated charge or the same one captured twice."),
                     seccionTitulo: L.t("EL GASTO", "EXPENSE DETAILS"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Renta del anexo", "Annex rent")),
                        .init(label: L.t("Importe", "Amount"), valor: "−$3,500.00", resalte: .rojo),
                        .init(label: L.t("Categoría", "Category"), valor: L.t("Renta", "Rent")),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("28 ago 2026", "Aug 28, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Transferencia", "Transfer")),
                        .init(label: L.t("Registrado por", "Logged by"), valor: L.t("Luis Aguilar · Tesorería", "Luis Aguilar · Treasury")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0108"),
                     ],
                     seccionSecundaria: L.t("EL OTRO MOVIMIENTO", "OTHER ENTRY"),
                     camposSecundarios: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Renta del anexo", "Annex rent")),
                        .init(label: L.t("Importe", "Amount"), valor: "−$3,500.00", resalte: .rojo),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("22 ago 2026", "Aug 22, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Transferencia", "Transfer")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0096"),
                     ],
                     notaPie: L.t("Los dos siguen en los libros: esta alerta no borra ninguno, solo pide que alguien diga cuál se queda.",
                                  "Both stay in the books: this alert deletes neither, it just asks someone to say which one stays."),
                     acciones: [editarPrim, pedir],
                     esGasto: true, editImporte: "3,500.00", editCategoria: L.t("Renta", "Rent"), editMetodo: L.t("Transferencia", "Transfer")),

            Revision(id: "5", tipo: .categoriaVacia, concepto: L.t("Depósito varios", "Misc deposit"),
                     detalleLista: L.t("CSV · 25 ago 2026", "CSV · Aug 25, 2026"),
                     descripcion: L.t("«Depósito varios» por $1,180.00 del 25 ago 2026 entró sin categoría. Sin ella no aparece en el desglose de los reportes ni suma en ninguna línea del estado financiero.",
                                      "«Misc deposit» for $1,180.00 on Aug 25, 2026 came in with no category. Without one it doesn't appear in report breakdowns or add to any line of the financial statement."),
                     seccionTitulo: L.t("EL INGRESO", "ENTRY DETAILS"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Depósito varios", "Misc deposit")),
                        .init(label: L.t("Importe", "Amount"), valor: "+$1,180.00", resalte: .verde),
                        .init(label: L.t("Categoría", "Category"), valor: L.t("Sin categoría", "No category"), resalte: .rojo),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("25 ago 2026", "Aug 25, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Transferencia", "Transfer")),
                        .init(label: L.t("Comprobante", "Receipt"), valor: L.t("Sin comprobante", "No receipt"), resalte: .rojo),
                        .init(label: L.t("Registrado por", "Logged by"), valor: L.t("Importado de CSV", "Imported from CSV")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0099"),
                     ],
                     acciones: [resolver("Asignar categoría", "Assign category"), pedir],
                     editImporte: "1,180.00", editCategoria: L.t("Ofrenda general", "General offering"), editMetodo: L.t("Transferencia", "Transfer")),

            Revision(id: "6", tipo: .sinVincular, concepto: L.t("Diezmo", "Tithe"),
                     detalleLista: L.t("Luis Aguilar · 24 ago 2026", "Luis Aguilar · Aug 24, 2026"),
                     descripcion: L.t("«Diezmo» por $2,400.00 del 24 ago 2026 está marcado para constancia pero no tiene aportante vinculado. Sin el vínculo no puede salir en la constancia anual de nadie.",
                                      "«Tithe» for $2,400.00 on Aug 24, 2026 is marked for a statement but has no giver linked. Without the link it can't appear on anyone's annual statement."),
                     seccionTitulo: L.t("EL INGRESO", "ENTRY DETAILS"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Diezmo", "Tithe")),
                        .init(label: L.t("Importe", "Amount"), valor: "+$2,400.00", resalte: .verde),
                        .init(label: L.t("Categoría", "Category"), valor: L.t("Diezmo", "Tithe")),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("24 ago 2026", "Aug 24, 2026")),
                        .init(label: L.t("Método de pago", "Payment method"), valor: L.t("Transferencia", "Transfer")),
                        .init(label: L.t("Comprobante", "Receipt"), valor: L.t("Sin comprobante", "No receipt"), resalte: .rojo),
                        .init(label: L.t("Aportante", "Giver"), valor: L.t("Sin vincular", "Unlinked"), resalte: .rojo),
                        .init(label: L.t("Registrado por", "Logged by"), valor: L.t("Luis Aguilar · Tesorería", "Luis Aguilar · Treasury")),
                        .init(label: L.t("Folio", "Folio"), valor: "2026‑0097"),
                     ],
                     acciones: [resolver("Vincular aportante", "Link giver"), pedir],
                     editImporte: "2,400.00", editCategoria: L.t("Diezmo", "Tithe"), editMetodo: L.t("Transferencia", "Transfer")),

            Revision(id: "7", tipo: .recurrenteVencido, concepto: L.t("Renta del anexo", "Annex rent"),
                     detalleLista: L.t("Serie mensual · julio y agosto sin generar", "Monthly series · July and August not generated"),
                     descripcion: L.t("«Renta del anexo» lleva 2 meses sin generar su movimiento. Los meses cumplidos no se crean solos hacia atrás: hay que generarlos o mover la fecha de la serie.",
                                      "«Annex rent» hasn't generated its entry for 2 months. Past months aren't created backwards on their own: generate them or move the series date."),
                     seccionTitulo: L.t("LA SERIE", "SERIES"),
                     campos: [
                        .init(label: L.t("Concepto", "Concept"), valor: L.t("Renta del anexo", "Annex rent")),
                        .init(label: L.t("Tipo", "Type"), valor: L.t("Gasto", "Expense")),
                        .init(label: L.t("Importe por mes", "Amount per month"), valor: "$3,500.00", resalte: .rojo),
                        .init(label: L.t("Empezó en", "Started"), valor: L.t("ene 2026", "Jan 2026")),
                        .init(label: L.t("Último mes generado", "Last month generated"), valor: L.t("jun 2026", "Jun 2026")),
                        .init(label: L.t("Meses sin generar", "Months not generated"), valor: L.t("julio y agosto de 2026", "July and August 2026"), resalte: .rojo),
                     ],
                     acciones: [navegar("Ver movimientos recurrentes", "See recurring entries")]),

            Revision(id: "8", tipo: .faltaFirma, concepto: L.t("Miércoles 19 de agosto", "Wednesday Aug 19"),
                     detalleLista: L.t("Luis Aguilar · falta la segunda firma", "Luis Aguilar · second signature missing"),
                     descripcion: L.t("El corte «Miércoles 19 de agosto» del 19 ago 2026 pidió que una segunda persona contara el dinero, y todavía nadie ha firmado. Lo registró Luis Aguilar, así que la firma le toca a alguien más. Si el dinero ya está en el banco, lo que queda por revisar es el registro.",
                                      "The «Wednesday Aug 19» cut on Aug 19, 2026 asked for a second person to count the money, and nobody has signed yet. Luis Aguilar logged it, so the signature falls to someone else. If the money is already in the bank, what's left to review is the record."),
                     seccionTitulo: L.t("EL CORTE", "DEPOSIT"),
                     campos: [
                        .init(label: L.t("Corte", "Cut"), valor: L.t("Miércoles 19 de agosto", "Wednesday Aug 19")),
                        .init(label: L.t("Fecha", "Date"), valor: L.t("19 ago 2026", "Aug 19, 2026")),
                        .init(label: L.t("Movimientos", "Entries"), valor: "9"),
                        .init(label: L.t("Importe contado", "Counted amount"), valor: "$4,310.00"),
                        .init(label: L.t("Lo registró", "Logged by"), valor: "Luis Aguilar"),
                        .init(label: L.t("Segunda firma", "Second signature"), valor: L.t("Pendiente", "Pending"), resalte: .rojo),
                     ],
                     acciones: [navegar("Ir al corte", "Go to the cut")]),

            Revision(id: "9", tipo: .archivado, concepto: "Carmen Ortiz Salinas",
                     detalleLista: L.t("Sin correo registrado", "No email on file"),
                     archivado: true,
                     descripcion: L.t("Carmen Ortiz Salinas está archivada. Se conserva su historial de aportes, pero no aparece en el padrón ni se le puede registrar nada nuevo hasta restaurarla.",
                                      "Carmen Ortiz Salinas is archived. Her giving history is kept, but she doesn't appear on the roll and nothing new can be logged for her until restored."),
                     seccionTitulo: L.t("EL MIEMBRO", "MEMBER"),
                     campos: [
                        .init(label: L.t("Nombre", "Name"), valor: "Carmen Ortiz Salinas"),
                        .init(label: L.t("Correo", "Email"), valor: L.t("Sin correo registrado", "No email on file"), resalte: .rojo),
                        .init(label: L.t("Miembro desde", "Member since"), valor: "2011"),
                        .init(label: L.t("Motivo de la baja", "Reason removed"), valor: L.t("Traslado a otra iglesia", "Transfer to another church")),
                        .init(label: L.t("Fecha de la baja", "Removed on"), valor: L.t("22 ago 2026", "Aug 22, 2026")),
                     ],
                     acciones: [resolver("Restaurar", "Restore")]),

            Revision(id: "10", tipo: .archivado, concepto: "Tomás Iracheta Guzmán",
                     detalleLista: "tomas.ig@gmail.com",
                     archivado: true,
                     descripcion: L.t("Tomás Iracheta Guzmán está archivado. Se conserva su historial de aportes, pero no aparece en el padrón ni se le puede registrar nada nuevo hasta restaurarlo.",
                                      "Tomás Iracheta Guzmán is archived. His giving history is kept, but he doesn't appear on the roll and nothing new can be logged for him until restored."),
                     seccionTitulo: L.t("EL MIEMBRO", "MEMBER"),
                     campos: [
                        .init(label: L.t("Nombre", "Name"), valor: "Tomás Iracheta Guzmán"),
                        .init(label: L.t("Correo", "Email"), valor: "tomas.ig@gmail.com"),
                        .init(label: L.t("Miembro desde", "Member since"), valor: "2013"),
                        .init(label: L.t("Motivo de la baja", "Reason removed"), valor: L.t("Dejó de congregarse", "Stopped attending")),
                        .init(label: L.t("Fecha de la baja", "Removed on"), valor: L.t("14 nov 2024", "Nov 14, 2024")),
                     ],
                     acciones: [resolver("Restaurar", "Restore")]),
        ]
    }
}
