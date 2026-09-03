import Foundation

/// Frontera de datos de la pantalla de movimientos. La vista solo habla con
/// esto; GRDB implementará las MISMAS operaciones (leer/crear/actualizar/
/// eliminar) sin tocar la UI. Por eso el CRUD vive aquí desde ya.
protocol MovimientosRepository {
    func lista(tipo: TipoMovimiento) async throws -> [Movimiento]
    func crear(_ m: Movimiento) async throws
    func actualizar(_ m: Movimiento) async throws
    func eliminar(id: String) async throws
    /// Folio que le tocaría al siguiente movimiento de esa serie, para
    /// enseñarlo en la hoja de captura. Es orientativo: no reserva nada, así
    /// que cancelar la hoja no deja huecos en la numeración. El folio
    /// definitivo lo asigna `crear`.
    func siguienteFolio(tipo: TipoMovimiento) async -> String
}

/// El repositorio que usa la app: la base del teléfono, siempre. Escribe local
/// y encola; `MotorSincronizacion` lleva y trae contra Supabase por su cuenta.
/// Ninguna pantalla espera ya a la red para guardar.
///
/// En modo revisión son datos de ejemplo, porque sin sesión iniciada Supabase
/// no devolvería ni aceptaría nada que sincronizar.
func repositorioMovimientos() -> MovimientosRepository {
    ModoRevision.sinLogin ? MockMovimientosRepository() : OfflineMovimientosRepository()
}

/// Almacén falso en memoria. Es un **struct** (valor, como los demás repos) con
/// un almacén ESTÁTICO compartido, para que crear/editar/eliminar persistan
/// durante la sesión y se reflejen entre Ingresos y Gastos.
struct MockMovimientosRepository: MovimientosRepository {
    private static var almacen: [Movimiento] = MockMovimientosRepository.semilla
    /// Un contador por serie, igual que en Supabase.
    /// El contador de gastos iba en 1044 mientras la semilla de gastos usaba
    /// folios 05xx: el primer gasto nuevo saltaba de "0518" a "1045".
    private static var folios: [TipoMovimiento: Int] = [.ingreso: 1044, .gasto: 521]

    func lista(tipo: TipoMovimiento) async throws -> [Movimiento] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.almacen.filter { $0.tipo == tipo }.sorted { $0.fecha > $1.fecha }
    }

    func crear(_ m: Movimiento) async throws {
        var nuevo = m
        if nuevo.id.isEmpty { nuevo.id = UUID().uuidString }
        // El folio se consume al guardar, no al abrir la hoja.
        let seq = (Self.folios[m.tipo] ?? 0) + 1
        Self.folios[m.tipo] = seq
        nuevo.folio = Self.folio(seq)
        Self.almacen.append(nuevo)
    }

    func actualizar(_ m: Movimiento) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == m.id }) { Self.almacen[i] = m }
    }

    func eliminar(id: String) async throws {
        Self.almacen.removeAll { $0.id == id }
    }

    func siguienteFolio(tipo: TipoMovimiento) async -> String {
        Self.folio((Self.folios[tipo] ?? 0) + 1)
    }

    /// Cuatro dígitos, como los folios de la semilla: sin esto el folio nuevo
    /// de un gasto salía "522" junto a un "0521" y no parecían la misma serie.
    private static func folio(_ n: Int) -> String { String(format: "%04d", n) }

    // MARK: - Semilla (los datos del handoff)

    private static func dias(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }

    /// Detalle del evento "Creado" del rastro de auditoría, construido con la
    /// MISMA fecha y hora del movimiento. Antes iba escrito a mano —"20 de
    /// agosto 2026, 12:10"— en movimientos fechados hoy: la ficha mostraba una
    /// fecha en la cabecera y otra distinta, con la misma hora, en el rastro.
    private static func creadoEn(_ fecha: Date, _ hora: String) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = L.t("d 'de' MMMM yyyy", "MMM d, yyyy")
        return "\(f.string(from: fecha)), \(hora) · iPad"
    }

    private static var semilla: [Movimiento] {
        var v: [Movimiento] = []
        v += [
            Movimiento(id: "1", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "María Hernández",
                folio: "1043", metodo: L.t("Efectivo", "Cash"), monto: 1_200_00, hora: "11:20", fecha: dias(0),
                registradoPor: "Iván García", miembro: "María Hernández Ríos",
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"),
                nota: L.t("Entregado en sobre cerrado durante el culto de oración. Se confirmó el monto con la hermana antes de sellar el sobre.",
                          "Handed in a sealed envelope during prayer service. Amount confirmed with her before sealing."),
                sinDepositar: true, comprobante: "sobre-1043.jpg",
                auditoria: [
                    AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                               detalle: creadoEn(dias(0), "11:20")),
                    AuditEntry(id: "2", titulo: L.t("Categoría asignada", "Category assigned"),
                               detalle: L.t("Diezmos · fondo general", "Tithes · general fund")),
                    AuditEntry(id: "3", titulo: L.t("Sin depositar", "Not deposited"),
                               detalle: L.t("Se incluirá en el corte del domingo 23", "Will be in Sunday 23 deposit")),
                ]),
            Movimiento(id: "2", tipo: .ingreso, categoria: L.t("Ofrenda misionera", "Mission offering"), persona: nil,
                folio: "1041", metodo: L.t("Efectivo", "Cash"), monto: 6_845_00, hora: "12:05", fecha: dias(0),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones · ofrenda", "Missions · offering"), nota: nil,
                sinDepositar: true, comprobante: nil,
                auditoria: [AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "12:05"))]),
            Movimiento(id: "3", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: L.t("Familia Ruvalcaba", "Ruvalcaba family"),
                folio: "1040", metodo: L.t("Cheque 8823", "Check 8823"), monto: 2_500_00, hora: "12:10", fecha: dias(0),
                registradoPor: "Iván García", miembro: L.t("Familia Ruvalcaba", "Ruvalcaba family"),
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"), nota: nil,
                sinDepositar: false, comprobante: nil,
                auditoria: [AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "12:10"))]),
            Movimiento(id: "4", tipo: .ingreso, categoria: L.t("Ofrenda de miércoles", "Wednesday offering"), persona: nil,
                folio: "1039", metodo: L.t("Efectivo", "Cash"), monto: 3_180_00, hora: "20:30", fecha: dias(1),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Ofrendas · culto", "Offerings · service"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: "5", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "Pedro Salas",
                folio: "1038", metodo: L.t("Transferencia SPEI", "SPEI transfer"), monto: 900_00, hora: "19:00", fecha: dias(1),
                registradoPor: "Iván García", miembro: "Pedro Salas Aguirre",
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: "6", tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "Ana Lucía Torres",
                folio: "1037", metodo: L.t("Efectivo", "Cash"), monto: 1_450_00, hora: "19:10", fecha: dias(1),
                registradoPor: "Iván García", miembro: "Ana Lucía Torres",
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: "7", tipo: .ingreso, categoria: L.t("Misiones", "Missions"), persona: L.t("ofrenda especial", "special offering"),
                folio: "1036", metodo: L.t("Efectivo", "Cash"), monto: 7_248_00, hora: "11:00", fecha: dias(4),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones · ofrenda", "Missions · offering"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: "8", tipo: .ingreso, categoria: L.t("Ofrenda de gratitud", "Thanksgiving offering"), persona: nil,
                folio: "1035", metodo: L.t("Efectivo", "Cash"), monto: 540_00, hora: "11:05", fecha: dias(4),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Ofrendas · culto", "Offerings · service"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: "101", tipo: .gasto, categoria: L.t("Utilidades", "Utilities"), persona: "Luz CFE",
                folio: "0518", metodo: L.t("Transferencia", "Transfer"), monto: 3_410_50, hora: "09:30", fecha: dias(0),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Utilidades · electricidad", "Utilities · electricity"),
                nota: L.t("Recibo bimestral del templo.", "Bimonthly church bill."),
                sinDepositar: false, comprobante: "cfe-0518.pdf",
                auditoria: [AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "09:30"))],
                pagadoA: "Luz CFE"),
            Movimiento(id: "102", tipo: .gasto, categoria: L.t("Mantenimiento", "Maintenance"), persona: L.t("Ferretería El Clavo", "El Clavo hardware"),
                folio: "0517", metodo: L.t("Efectivo", "Cash"), monto: 890_00, hora: "16:40", fecha: dias(1),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Mantenimiento · materiales", "Maintenance · supplies"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: [],
                pagadoA: L.t("Ferretería El Clavo", "El Clavo hardware")),
            Movimiento(id: "103", tipo: .gasto, categoria: L.t("Misiones", "Missions"), persona: nil,
                folio: "0516", metodo: L.t("Transferencia", "Transfer"), monto: 2_000_00, hora: "10:00", fecha: dias(4),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones · apoyo", "Missions · support"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            // --- Gastos de prueba (3 sep 2026) para recorrer la pantalla con
            // beneficiario, RFC vacío, notas internas, comprobante y marcado
            // pendiente: los tres campos que la ficha no enseñaba.
            Movimiento(id: "104", tipo: .gasto, categoria: L.t("Utilidades", "Utilities"),
                persona: "PSE&G",
                folio: "0519", metodo: L.t("Transferencia", "Transfer"), monto: 428_63,
                hora: "10:15", fecha: dias(0),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Utilidades", "Utilities"),
                nota: L.t("Factura de electricidad de agosto", "August electricity bill"),
                sinDepositar: false, comprobante: "factura-pseg-agosto-2026.pdf",
                auditoria: [AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "10:15"))],
                pagadoA: "PSE&G", rfc: nil,
                notasAuditoria: L.t("Factura de agosto de 2026", "August 2026 bill"),
                marcadoPendiente: false, incluidoEnCorte: false, darConstanciaAnual: false,
                repiteMensual: false),
            Movimiento(id: "105", tipo: .gasto, categoria: L.t("Suministros", "Supplies"),
                persona: "Costco",
                folio: "0520", metodo: L.t("Tarjeta", "Card"), monto: 189_74,
                hora: "17:20", fecha: dias(1),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Suministros", "Supplies"),
                nota: L.t("Papel, sobres y tinta para la impresora",
                          "Paper, envelopes and printer ink"),
                sinDepositar: false, comprobante: "recibo-costco.jpg",
                auditoria: [AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(1), "17:20"))],
                pagadoA: "Costco", rfc: nil,
                notasAuditoria: L.t("Compra para la oficina de la iglesia",
                                    "Purchase for the church office"),
                marcadoPendiente: false, incluidoEnCorte: false, darConstanciaAnual: false,
                repiteMensual: false),
            Movimiento(id: "106", tipo: .gasto, categoria: L.t("Misiones", "Missions"),
                persona: L.t("Iglesia Misionera La Esperanza", "La Esperanza Mission Church"),
                folio: "0521", metodo: L.t("Cheque", "Check"), monto: 600_00,
                hora: "12:00", fecha: dias(2),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones", "Missions"),
                nota: L.t("Ofrenda mensual para obra misionera",
                          "Monthly offering for mission work"),
                sinDepositar: false, comprobante: "copia-cheque-misiones.jpg",
                auditoria: [AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(2), "12:00"))],
                pagadoA: L.t("Iglesia Misionera La Esperanza", "La Esperanza Mission Church"),
                rfc: nil,
                notasAuditoria: L.t("Cheque preparado, pendiente de entrega",
                                    "Check prepared, pending delivery"),
                marcadoPendiente: true, incluidoEnCorte: false, darConstanciaAnual: false,
                repiteMensual: false),
        ]
        return v
    }
}
