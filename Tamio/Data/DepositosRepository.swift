import Foundation

protocol DepositosRepository {
    func cortes(estado: EstadoDeposito) async throws -> [Corte]
    func crear(_ corte: Corte) async throws
    func actualizar(_ corte: Corte) async throws
    func marcarDepositado(id: Int) async throws
}

/// Datos falsos que reproducen la pantalla de Depósitos del handoff. Usa un
/// almacén estático mutable para que crear / actualizar / marcar-depositado
/// persistan mientras la app vive (mañana este almacén es GRDB).
struct MockDepositosRepository: DepositosRepository {
    private static var almacen: [Corte] = pendientes + depositados

    func cortes(estado: EstadoDeposito) async throws -> [Corte] {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return Self.almacen.filter { $0.estado == estado }
    }

    func crear(_ corte: Corte) async throws {
        Self.almacen.insert(corte, at: 0)
    }

    func actualizar(_ corte: Corte) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == corte.id }) {
            Self.almacen[i] = corte
        }
    }

    func marcarDepositado(id: Int) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == id }) else { return }
        Self.almacen[i].estado = .depositado
        Self.almacen[i].descripcion = L.t("Depositado hoy", "Deposited today")
    }

    private static var pendientes: [Corte] {
        [
            Corte(
                id: 1,
                titulo: L.t("Corte del domingo 23", "Sunday 23 cut"),
                subtitulo: L.t("14 movimientos · Banorte ··4821", "14 entries · Banorte ··4821"),
                descripcion: L.t("Dinero en caja del domingo 23 de agosto · revísalo antes de llevarlo al banco",
                                 "Cash from Sunday Aug 23 · review before taking it to the bank"),
                montoTotal: 18_540_00, estado: .pendiente,
                efectivoSeleccionado: 8_045_00, efectivoEstimado: 19_720_00,
                chequesMonto: 3_400_00, chequesCount: 2,
                listoParaDepositar: 11_445_00, seleccionados: 4, totalSeleccionables: 5,
                chequeos: [
                    Chequeo(id: 1, tipo: .aviso,
                            titulo: L.t("2 movimientos marcados por revisar", "2 entries flagged for review"),
                            detalle: L.t("No se cuentan en los totales del mes hasta que los confirmes, así que tampoco entran en este depósito.",
                                         "They don't count in monthly totals until confirmed, so they're not in this deposit either."),
                            enlace: L.t("Ir a Por revisar", "Go to Review")),
                    Chequeo(id: 2, tipo: .ok,
                            titulo: L.t("El efectivo alcanza", "Cash is enough"),
                            detalle: L.t("Vas a depositar $8,045.00 en efectivo de los $19,720.00 estimados en caja a esa fecha.",
                                         "You'll deposit $8,045.00 in cash of the $19,720.00 estimated on hand by that date."),
                            enlace: nil),
                    Chequeo(id: 3, tipo: .duda,
                            titulo: L.t("Periodo contable: agosto 2026", "Accounting period: August 2026"),
                            detalle: L.t("Si este dinero es de julio, cambia el periodo al registrar el depósito: suma en el periodo que elijas, no en la fecha en que lo llevas al banco.",
                                         "If this is July's money, change the period when recording: it adds to the period you pick, not the bank date."),
                            enlace: nil),
                ],
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Diezmo", "Tithe"), folio: "1042",
                                   cuando: L.t("Domingo 23 · 12:38 p.m.", "Sunday 23 · 12:38 p.m."), monto: 1_200_00, seleccionado: true),
                    MovimientoCaja(id: 2, categoria: L.t("Ofrenda misionera", "Mission offering"), folio: "1041",
                                   cuando: L.t("Domingo 23 · contada por los ujieres", "Sunday 23 · counted by ushers"), monto: 6_845_00, seleccionado: true),
                    MovimientoCaja(id: 3, categoria: L.t("Diezmo", "Tithe"), folio: "1040",
                                   cuando: L.t("Cheque 3841 · Banamex", "Check 3841 · Banamex"), monto: 2_500_00, seleccionado: true, esCheque: true),
                ],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 24 de agosto", "Monday, Aug 24"),
                                           periodo: L.t("Agosto 2026", "August 2026"), monto: 11_445_00)
            ),
            Corte(
                id: 2,
                titulo: L.t("Ofrendas de miércoles 19", "Wednesday 19 offerings"),
                subtitulo: L.t("6 movimientos · Sin cuenta asignada", "6 entries · No account assigned"),
                descripcion: L.t("Dinero en caja del miércoles 19 de agosto · falta asignar la cuenta",
                                 "Cash from Wednesday Aug 19 · account not assigned yet"),
                montoTotal: 3_180_00, estado: .pendiente,
                efectivoSeleccionado: 3_180_00, efectivoEstimado: 3_180_00,
                chequesMonto: 0, chequesCount: 0,
                listoParaDepositar: 3_180_00, seleccionados: 6, totalSeleccionables: 6,
                chequeos: [
                    Chequeo(id: 1, tipo: .aviso,
                            titulo: L.t("Sin cuenta asignada", "No account assigned"),
                            detalle: L.t("Elige a qué cuenta va este depósito antes de registrarlo.",
                                         "Pick which account this deposit goes to before recording it."),
                            enlace: L.t("Asignar cuenta", "Assign account")),
                    Chequeo(id: 2, tipo: .ok,
                            titulo: L.t("Todo en efectivo", "All cash"),
                            detalle: L.t("Los 6 movimientos son en efectivo y suman $3,180.00.",
                                         "All 6 entries are cash, totaling $3,180.00."), enlace: nil),
                ],
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Ofrenda de miércoles", "Wednesday offering"), folio: "1039",
                                   cuando: L.t("Miércoles 19 · culto", "Wednesday 19 · service"), monto: 3_180_00, seleccionado: true),
                ],
                registro: RegistroDeposito(cuenta: L.t("Sin asignar", "Unassigned"),
                                           fecha: L.t("Por definir", "To be set"),
                                           periodo: L.t("Agosto 2026", "August 2026"), monto: 3_180_00)
            ),
        ]
    }

    private static var depositados: [Corte] {
        [
            Corte(
                id: 10,
                titulo: L.t("Corte del domingo 16", "Sunday 16 cut"),
                subtitulo: L.t("11 movimientos · Banorte ··4821", "11 entries · Banorte ··4821"),
                descripcion: L.t("Depositado el lunes 17 de agosto", "Deposited Monday, Aug 17"),
                montoTotal: 14_320_00, estado: .depositado,
                efectivoSeleccionado: 9_820_00, efectivoEstimado: 9_820_00,
                chequesMonto: 4_500_00, chequesCount: 3,
                listoParaDepositar: 14_320_00, seleccionados: 11, totalSeleccionables: 11,
                chequeos: [
                    Chequeo(id: 1, tipo: .ok, titulo: L.t("Depósito registrado", "Deposit recorded"),
                            detalle: L.t("Ficha adjunta el lunes 17 de agosto por Iván García.",
                                         "Slip attached Monday, Aug 17 by Iván García."), enlace: nil),
                ],
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Diezmo", "Tithe"), folio: "1030",
                                   cuando: L.t("Domingo 16", "Sunday 16"), monto: 5_320_00, seleccionado: true),
                    MovimientoCaja(id: 2, categoria: L.t("Ofrenda", "Offering"), folio: "1029",
                                   cuando: L.t("Domingo 16", "Sunday 16"), monto: 4_500_00, seleccionado: true),
                ],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 17 de agosto", "Monday, Aug 17"),
                                           periodo: L.t("Agosto 2026", "August 2026"), monto: 14_320_00)
            ),
        ]
    }
}
