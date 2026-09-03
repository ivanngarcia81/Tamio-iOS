import Foundation

/// Frontera de datos de la pantalla de movimientos. La vista solo habla con
/// esto; GRDB implementará las MISMAS operaciones (leer/crear/actualizar/
/// eliminar) sin tocar la UI. Por eso el CRUD vive aquí desde ya.
protocol MovimientosRepository {
    func lista(tipo: TipoMovimiento) async throws -> [Movimiento]
    func crear(_ m: Movimiento) async throws
    func actualizar(_ m: Movimiento) async throws
    func eliminar(id: Int) async throws
    /// Siguiente folio disponible, para un movimiento nuevo.
    func siguienteFolio() async -> String
}

/// Almacén falso en memoria. Es un **struct** (valor, como los demás repos) con
/// un almacén ESTÁTICO compartido, para que crear/editar/eliminar persistan
/// durante la sesión y se reflejen entre Ingresos y Gastos.
struct MockMovimientosRepository: MovimientosRepository {
    private static var almacen: [Movimiento] = MockMovimientosRepository.semilla
    private static var siguienteId: Int = (MockMovimientosRepository.semilla.map(\.id).max() ?? 0) + 1
    private static var folio: Int = 1044

    func lista(tipo: TipoMovimiento) async throws -> [Movimiento] {
        try? await Task.sleep(nanoseconds: 120_000_000)
        return Self.almacen.filter { $0.tipo == tipo }.sorted { $0.fecha > $1.fecha }
    }

    func crear(_ m: Movimiento) async throws {
        var nuevo = m
        if nuevo.id == 0 { nuevo.id = Self.siguienteId; Self.siguienteId += 1 }
        Self.almacen.append(nuevo)
    }

    func actualizar(_ m: Movimiento) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == m.id }) { Self.almacen[i] = m }
    }

    func eliminar(id: Int) async throws {
        Self.almacen.removeAll { $0.id == id }
    }

    func siguienteFolio() async -> String {
        defer { Self.folio += 1 }
        return String(Self.folio)
    }

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
            Movimiento(id: 1, tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "María Hernández",
                folio: "1043", metodo: L.t("Efectivo", "Cash"), monto: 1_200_00, hora: "11:20", fecha: dias(0),
                registradoPor: "Iván García", miembro: "María Hernández Ríos",
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"),
                nota: L.t("Entregado en sobre cerrado durante el culto de oración. Se confirmó el monto con la hermana antes de sellar el sobre.",
                          "Handed in a sealed envelope during prayer service. Amount confirmed with her before sealing."),
                sinDepositar: true, comprobante: "sobre-1043.jpg",
                auditoria: [
                    AuditEntry(id: 1, titulo: L.t("Creado · Iván García", "Created · Iván García"),
                               detalle: creadoEn(dias(0), "11:20")),
                    AuditEntry(id: 2, titulo: L.t("Categoría asignada", "Category assigned"),
                               detalle: L.t("Diezmos · fondo general", "Tithes · general fund")),
                    AuditEntry(id: 3, titulo: L.t("Sin depositar", "Not deposited"),
                               detalle: L.t("Se incluirá en el corte del domingo 23", "Will be in Sunday 23 deposit")),
                ]),
            Movimiento(id: 2, tipo: .ingreso, categoria: L.t("Ofrenda misionera", "Mission offering"), persona: nil,
                folio: "1041", metodo: L.t("Efectivo", "Cash"), monto: 6_845_00, hora: "12:05", fecha: dias(0),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones · ofrenda", "Missions · offering"), nota: nil,
                sinDepositar: true, comprobante: nil,
                auditoria: [AuditEntry(id: 1, titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "12:05"))]),
            Movimiento(id: 3, tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: L.t("Familia Ruvalcaba", "Ruvalcaba family"),
                folio: "1040", metodo: L.t("Cheque 8823", "Check 8823"), monto: 2_500_00, hora: "12:10", fecha: dias(0),
                registradoPor: "Iván García", miembro: L.t("Familia Ruvalcaba", "Ruvalcaba family"),
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"), nota: nil,
                sinDepositar: false, comprobante: nil,
                auditoria: [AuditEntry(id: 1, titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "12:10"))]),
            Movimiento(id: 4, tipo: .ingreso, categoria: L.t("Ofrenda de miércoles", "Wednesday offering"), persona: nil,
                folio: "1039", metodo: L.t("Efectivo", "Cash"), monto: 3_180_00, hora: "20:30", fecha: dias(1),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Ofrendas · culto", "Offerings · service"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: 5, tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "Pedro Salas",
                folio: "1038", metodo: L.t("Transferencia SPEI", "SPEI transfer"), monto: 900_00, hora: "19:00", fecha: dias(1),
                registradoPor: "Iván García", miembro: "Pedro Salas Aguirre",
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: 6, tipo: .ingreso, categoria: L.t("Diezmo", "Tithe"), persona: "Ana Lucía Torres",
                folio: "1037", metodo: L.t("Efectivo", "Cash"), monto: 1_450_00, hora: "19:10", fecha: dias(1),
                registradoPor: "Iván García", miembro: "Ana Lucía Torres",
                categoriaCompleta: L.t("Diezmos · fondo general", "Tithes · general fund"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: 7, tipo: .ingreso, categoria: L.t("Misiones", "Missions"), persona: L.t("ofrenda especial", "special offering"),
                folio: "1036", metodo: L.t("Efectivo", "Cash"), monto: 7_248_00, hora: "11:00", fecha: dias(4),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones · ofrenda", "Missions · offering"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: 8, tipo: .ingreso, categoria: L.t("Ofrenda de gratitud", "Thanksgiving offering"), persona: nil,
                folio: "1035", metodo: L.t("Efectivo", "Cash"), monto: 540_00, hora: "11:05", fecha: dias(4),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Ofrendas · culto", "Offerings · service"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: 101, tipo: .gasto, categoria: L.t("Utilidades", "Utilities"), persona: "Luz CFE",
                folio: "0518", metodo: L.t("Transferencia", "Transfer"), monto: 3_410_50, hora: "09:30", fecha: dias(0),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Utilidades · electricidad", "Utilities · electricity"),
                nota: L.t("Recibo bimestral del templo.", "Bimonthly church bill."),
                sinDepositar: false, comprobante: "cfe-0518.pdf",
                auditoria: [AuditEntry(id: 1, titulo: L.t("Creado · Iván García", "Created · Iván García"),
                                       detalle: creadoEn(dias(0), "09:30"))]),
            Movimiento(id: 102, tipo: .gasto, categoria: L.t("Mantenimiento", "Maintenance"), persona: L.t("Ferretería El Clavo", "El Clavo hardware"),
                folio: "0517", metodo: L.t("Efectivo", "Cash"), monto: 890_00, hora: "16:40", fecha: dias(1),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Mantenimiento · materiales", "Maintenance · supplies"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
            Movimiento(id: 103, tipo: .gasto, categoria: L.t("Misiones", "Missions"), persona: nil,
                folio: "0516", metodo: L.t("Transferencia", "Transfer"), monto: 2_000_00, hora: "10:00", fecha: dias(4),
                registradoPor: "Iván García", miembro: nil,
                categoriaCompleta: L.t("Misiones · apoyo", "Missions · support"), nota: nil,
                sinDepositar: false, comprobante: nil, auditoria: []),
        ]
        return v
    }
}
