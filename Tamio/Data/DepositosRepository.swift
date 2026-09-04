import Foundation

protocol DepositosRepository {
    func cortes(estado: EstadoDeposito) async throws -> [Corte]
    func crear(_ corte: Corte) async throws
    func actualizar(_ corte: Corte) async throws
    func marcarDepositado(id: String) async throws
    /// Cuentas donde se puede depositar. Estaban escritas a mano en el
    /// ViewModel, así que no había forma de dar de alta la del banco propio.
    func cuentas() async throws -> [String]
    func agregarCuenta(_ nombre: String) async throws
}

/// Datos falsos que reproducen la pantalla de Depósitos del handoff. Usa un
/// almacén estático mutable para que crear / actualizar / marcar-depositado
/// persistan mientras la app vive (mañana este almacén es GRDB).
struct MockDepositosRepository: DepositosRepository {
    private static var almacen: [Corte] = pendientes + depositados
    private static var cuentasAlmacen: [String] = [
        "Banorte ··4821", "Chase ··7730", "BBVA ··9014",
    ]

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

    func marcarDepositado(id: String) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == id }) else { return }
        Self.almacen[i].estado = .depositado
        Self.almacen[i].descripcion = L.t(
            "Depositado el \(DepositosViewModel.textoFecha(Date()))",
            "Deposited \(DepositosViewModel.textoFecha(Date()))")
    }

    func cuentas() async throws -> [String] { Self.cuentasAlmacen }

    func agregarCuenta(_ nombre: String) async throws {
        guard !Self.cuentasAlmacen.contains(nombre) else { return }
        Self.cuentasAlmacen.append(nombre)
    }

    // MARK: - Semilla

    /// Tres cortes de prueba con dinero real de un fin de semana: efectivo
    /// mezclado con cheques numerados, un culto entre semana 100 % en efectivo,
    /// y un corte grande con tres cheques. Los importes de la fila y del
    /// detalle **salen de sumar los movimientos**, no de un campo escrito.
    private static var pendientes: [Corte] {
        [
            Corte(
                id: "1",
                titulo: L.t("Culto domingo 6 de septiembre", "Sunday, September 6 service"),
                descripcion: L.t("Dinero en caja del domingo 6 · revísalo antes de llevarlo al banco",
                                 "Cash from Sunday, Sep 6 · review before taking it to the bank"),
                estado: .pendiente,
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Diezmo", "Tithe"), folio: "1051",
                                   cuando: L.t("Domingo 6 · 12:38 p.m.", "Sunday 6 · 12:38 p.m."),
                                   monto: 1_500_00, seleccionado: true),
                    MovimientoCaja(id: 2, categoria: L.t("Ofrenda general", "General offering"), folio: "1052",
                                   cuando: L.t("Domingo 6 · contada por los ujieres", "Sunday 6 · counted by ushers"),
                                   monto: 2_050_00, seleccionado: true),
                    MovimientoCaja(id: 3, categoria: L.t("Ofrenda misionera", "Mission offering"), folio: "1053",
                                   cuando: L.t("Domingo 6 · contada por los ujieres", "Sunday 6 · counted by ushers"),
                                   monto: 600_00, seleccionado: true),
                    MovimientoCaja(id: 4, categoria: L.t("Diezmo", "Tithe"), folio: "1054",
                                   cuando: L.t("Domingo 6 · sobre nominativo", "Sunday 6 · named envelope"),
                                   monto: 1_700_00, seleccionado: true,
                                   esCheque: true, numeroCheque: "3841"),
                ],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 7 de septiembre", "Monday, Sep 7"),
                                           periodo: L.t("Septiembre 2026", "September 2026")),
                efectivoEstimado: 6_200_00,
                porRevisar: 2
            ),
            Corte(
                id: "2",
                titulo: L.t("Ofrendas miércoles 2 de septiembre", "Wednesday, September 2 offerings"),
                descripcion: L.t("Dinero en caja del miércoles 2 · todo en efectivo",
                                 "Cash from Wednesday, Sep 2 · all cash"),
                estado: .pendiente,
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Ofrenda general", "General offering"), folio: "1048",
                                   cuando: L.t("Miércoles 2 · culto", "Wednesday 2 · service"),
                                   monto: 1_200_00, seleccionado: true),
                    MovimientoCaja(id: 2, categoria: L.t("Donación jóvenes", "Youth donation"), folio: "1049",
                                   cuando: L.t("Miércoles 2 · culto", "Wednesday 2 · service"),
                                   monto: 420_00, seleccionado: true),
                    MovimientoCaja(id: 3, categoria: L.t("Misiones", "Missions"), folio: "1050",
                                   cuando: L.t("Miércoles 2 · culto", "Wednesday 2 · service"),
                                   monto: 300_00, seleccionado: true),
                ],
                registro: RegistroDeposito(cuenta: "Chase ··7730",
                                           fecha: L.t("Jueves 3 de septiembre", "Thursday, Sep 3"),
                                           periodo: L.t("Septiembre 2026", "September 2026")),
                efectivoEstimado: 1_920_00
            ),
            Corte(
                id: "3",
                titulo: L.t("Culto especial y fondo de construcción", "Special service and building fund"),
                descripcion: L.t("Corte grande · tres cheques y el efectivo del culto especial",
                                 "Large cut · three checks plus the special service cash"),
                estado: .pendiente,
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Diezmo", "Tithe"), folio: "1055",
                                   cuando: L.t("Domingo 6 · sobre nominativo", "Sunday 6 · named envelope"),
                                   monto: 2_250_00, seleccionado: true,
                                   esCheque: true, numeroCheque: "4102"),
                    MovimientoCaja(id: 2, categoria: L.t("Diezmo", "Tithe"), folio: "1056",
                                   cuando: L.t("Domingo 6 · sobre nominativo", "Sunday 6 · named envelope"),
                                   monto: 1_800_00, seleccionado: true,
                                   esCheque: true, numeroCheque: "4103"),
                    MovimientoCaja(id: 3, categoria: L.t("Ofrenda general", "General offering"), folio: "1057",
                                   cuando: L.t("Domingo 6 · culto especial", "Sunday 6 · special service"),
                                   monto: 2_100_00, seleccionado: true),
                    MovimientoCaja(id: 4, categoria: L.t("Fondo de construcción", "Building fund"), folio: "1058",
                                   cuando: L.t("Domingo 6 · sobre nominativo", "Sunday 6 · named envelope"),
                                   monto: 1_280_00, seleccionado: true,
                                   esCheque: true, numeroCheque: "4104"),
                ],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 7 de septiembre", "Monday, Sep 7"),
                                           periodo: L.t("Septiembre 2026", "September 2026")),
                efectivoEstimado: 2_100_00
            ),
        ]
    }

    private static var depositados: [Corte] {
        [
            Corte(
                id: "10",
                titulo: L.t("Corte del domingo 16 de agosto", "Sunday, August 16 cut"),
                descripcion: L.t("Depositado el lunes 17 de agosto", "Deposited Monday, Aug 17"),
                estado: .depositado,
                movimientos: [
                    MovimientoCaja(id: 1, categoria: L.t("Diezmo", "Tithe"), folio: "1030",
                                   cuando: L.t("Domingo 16", "Sunday 16"), monto: 5_320_00, seleccionado: true),
                    MovimientoCaja(id: 2, categoria: L.t("Ofrenda general", "General offering"), folio: "1029",
                                   cuando: L.t("Domingo 16", "Sunday 16"), monto: 4_500_00, seleccionado: true),
                    MovimientoCaja(id: 3, categoria: L.t("Diezmo", "Tithe"), folio: "1028",
                                   cuando: L.t("Domingo 16 · sobre nominativo", "Sunday 16 · named envelope"),
                                   monto: 4_500_00, seleccionado: true,
                                   esCheque: true, numeroCheque: "2277"),
                ],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 17 de agosto", "Monday, Aug 17"),
                                           periodo: L.t("Agosto 2026", "August 2026")),
                efectivoEstimado: 9_820_00,
                fichaAdjunta: "ficha-banorte-17ago.pdf"
            ),
        ]
    }
}
