import Foundation

protocol DepositosRepository {
    func cortes(estado: EstadoDeposito) async throws -> [Corte]
    func crear(_ corte: Corte) async throws
    func actualizar(_ corte: Corte) async throws
    /// **Registrar el depósito** crea la fila de `depositos_bancarios` y el
    /// corte la apunta. Sustituye a `marcarDepositado`, que solo cambiaba un
    /// estado: sin fila no había dónde guardar el recibo, ni la fecha real en
    /// que se fue al banco, ni la referencia que da la ventanilla.
    func registrarDeposito(corteId: String, _ deposito: DepositoBancario) async throws
    /// Marca el recibo como ya subido al bucket. Lo llama la sincronización.
    func reciboSubido(depositoId: String, comprobantePath: String) async throws
    /// Cuentas donde se puede depositar. Estaban escritas a mano en el
    /// ViewModel, así que no había forma de dar de alta la del banco propio.
    func cuentas() async throws -> [String]
    func agregarCuenta(_ nombre: String) async throws
    /// Los ingresos que ningún corte reclama todavía: lo que se puede meter en
    /// un corte. **Antes no existía**: el corte inventaba su propio dinero.
    func movimientosLibres() async throws -> [Movimiento]
    func agregarAlCorte(corteId: String, movimientoIds: [String]) async throws
    func quitarDelCorte(corteId: String, movimientoId: String) async throws
    /// La segunda firma. `nombre` nulo con `conteo` puesto es un DESCUADRE:
    /// alguien contó, no cuadró y lo dejó anotado sin firmar. Esa cifra se
    /// guarda igual — perderla sería tirar justo el dato por el que se cuenta
    /// dos veces.
    func firmar(corteId: String, nombre: String?, rol: String?,
                modo: ModoSegundaFirma, conteo: Centavos?) async throws
    func quitarFirma(corteId: String) async throws
}

/// **La tabla puente `corte_movimientos`, mientras no hay GRDB.**
///
/// En Supabase esto son dos columnas —`corte_uid` y `tx_uid`— y nada más: sin
/// monto, sin categoría, sin copia de nada. Un corte no contiene dinero,
/// contiene punteros a movimientos que ya viven en Ingresos.
///
/// Aquí vive aparte de los dos repositorios porque **los dos la consultan**:
/// Depósitos para saber qué agrupa cada corte, y Movimientos para saber si un
/// ingreso sigue sin depositar. Es el mismo `JOIN` que hará GRDB.
enum PuenteCortes {
    /// corteId → ids de movimiento.
    private static var porCorte: [String: [String]] = [:]
    /// corteId → estado, para poder responder "¿esto ya se depositó?".
    private static var estados: [String: EstadoDeposito] = [:]

    /// La semilla se arranca sola en el primer acceso, venga de donde venga.
    /// Ingresos puede cargar antes que Depósitos, y sin esto los ingresos ya
    /// depositados saldrían un instante como "sin depositar".
    private static var sembrado = false
    private static func asegurarSemilla() {
        guard !sembrado else { return }
        sembrado = true
        estados = ["1": .pendiente, "2": .pendiente, "3": .pendiente, "10": .depositado]
        porCorte = [
            "1":  ["201", "202", "203", "204"],
            "2":  ["205", "206", "207"],
            "3":  ["208", "209", "210", "211"],
            "10": ["301", "302", "303"],
        ]
    }

    static func ids(deCorte corteId: String) -> [String] {
        asegurarSemilla()
        return porCorte[corteId] ?? []
    }

    static func corteDe(_ movimientoId: String) -> String? {
        asegurarSemilla()
        return porCorte.first { $0.value.contains(movimientoId) }?.key
    }

    /// **Un movimiento vive en UN corte, nunca en dos.** No es una regla de la
    /// app: Postgres ya la impone con `idx_corte_movs_tx_vivo`, un índice único
    /// sobre `tx_uid` para las filas vivas. Aquí se respeta la misma para que
    /// el mock no permita lo que el servidor va a rechazar — depositar el mismo
    /// diezmo dos veces.
    @discardableResult
    static func agregar(_ movimientoId: String, a corteId: String) -> Bool {
        guard corteDe(movimientoId) == nil else { return false }
        porCorte[corteId, default: []].append(movimientoId)
        return true
    }

    static func quitar(_ movimientoId: String, de corteId: String) {
        porCorte[corteId]?.removeAll { $0 == movimientoId }
    }

    static func registrar(corte: String, estado: EstadoDeposito) {
        asegurarSemilla()
        estados[corte] = estado
    }

    static func olvidar(corte: String) {
        porCorte[corte] = nil
        estados[corte] = nil
    }

    /// **Sin depositar = ningún corte YA DEPOSITADO lo reclama.** Estar en un
    /// corte abierto no cuenta: el dinero sigue en la caja fuerte hasta que
    /// alguien va al banco. Un gasto nunca está "sin depositar".
    static func sinDepositar(_ m: Movimiento) -> Bool {
        guard m.tipo == .ingreso else { return false }
        guard let corte = corteDe(m.id) else { return true }
        return estados[corte] != .depositado
    }

    /// El efectivo sin depositar que NO está en este corte: lo que se queda en
    /// la caja fuerte si el tesorero va al banco solo con este sobre.
    static func efectivoFuera(de corte: Corte, _ movimientos: [Movimiento]) -> Centavos {
        efectivoEnCaja(movimientos) - corte.efectivoSeleccionado
    }

    /// Libre = no está en ningún corte, ni abierto ni depositado. Es lo que se
    /// puede añadir a uno.
    static func estaLibre(_ m: Movimiento) -> Bool {
        m.tipo == .ingreso && corteDe(m.id) == nil
    }

    /// **El efectivo que hay en caja**, calculado. Como lo contado se deposita
    /// íntegro —nunca sale un gasto del dinero de la ofrenda—, es exactamente
    /// lo recibido en efectivo que ningún corte depositado reclama. Era un
    /// número escrito a mano en dos sitios distintos: el campo del corte y el
    /// KPI "Saldo en caja" de Tesorería, que podían contradecirse.
    static func efectivoEnCaja(_ movimientos: [Movimiento]) -> Centavos {
        movimientos
            .filter { $0.tipo == .ingreso && $0.esEfectivo && sinDepositar($0) }
            .reduce(0) { $0 + $1.monto }
    }
}

/// Datos falsos que reproducen la pantalla de Depósitos. El almacén es estático
/// para que crear / actualizar / marcar-depositado persistan mientras la app
/// vive (mañana este almacén es GRDB).
struct MockDepositosRepository: DepositosRepository {
    private static var almacen: [Corte] = pendientes + depositados
    private static var cuentasAlmacen: [String] = [
        "Banorte ··4821", "Chase ··7730", "BBVA ··9014",
    ]

    // MARK: - Lectura

    func cortes(estado: EstadoDeposito) async throws -> [Corte] {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return Self.almacen.filter { $0.estado == estado }.map { Self.resolver($0) }
    }

    /// Rellena el corte con los movimientos que apunta y con el efectivo en
    /// caja del momento. Ninguno de los dos se guarda: son el `JOIN`.
    private static func resolver(_ c: Corte) -> Corte {
        var c = c
        let todos = MockMovimientosRepository.todos
        let ids = PuenteCortes.ids(deCorte: c.id)
        c.movimientos = ids.compactMap { id in todos.first { $0.id == id } }
        c.efectivoEnCaja = PuenteCortes.efectivoEnCaja(todos)
        // Los ingresos marcados por revisar que NO entran en ningún corte: son
        // los que el checklist avisa que se quedan fuera del depósito. Era un
        // "2" escrito en la semilla, mientras el badge del tab decía 8.
        c.porRevisar = todos.filter {
            $0.tipo == .ingreso && $0.marcadoPendiente && PuenteCortes.estaLibre($0)
        }.count
        return c
    }

    func movimientosLibres() async throws -> [Movimiento] {
        MockMovimientosRepository.todos
            .filter { PuenteCortes.estaLibre($0) }
            .sorted { $0.fecha > $1.fecha }
    }

    func cuentas() async throws -> [String] { Self.cuentasAlmacen }

    // MARK: - Escritura

    func crear(_ corte: Corte) async throws {
        Self.almacen.insert(corte, at: 0)
        PuenteCortes.registrar(corte: corte.id, estado: corte.estado)
    }

    func actualizar(_ corte: Corte) async throws {
        if let i = Self.almacen.firstIndex(where: { $0.id == corte.id }) {
            // Los movimientos NO se guardan en el corte: viven en la tabla
            // puente. Si se guardaran aquí habría dos versiones de la misma
            // lista y una de las dos acabaría vieja.
            var sinResolver = corte
            sinResolver.movimientos = []
            Self.almacen[i] = sinResolver
        }
    }

    func agregarAlCorte(corteId: String, movimientoIds: [String]) async throws {
        for id in movimientoIds { PuenteCortes.agregar(id, a: corteId) }
    }

    func quitarDelCorte(corteId: String, movimientoId: String) async throws {
        PuenteCortes.quitar(movimientoId, de: corteId)
    }

    func registrarDeposito(corteId: String, _ deposito: DepositoBancario) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == corteId }) else { return }
        Self.almacen[i].estado = .depositado
        Self.almacen[i].deposito = deposito
        Self.almacen[i].descripcion = L.t(
            "Depositado el \(deposito.fecha)", "Deposited \(deposito.fecha)")
        // Al cerrarse el corte, sus movimientos dejan de ser efectivo en caja.
        PuenteCortes.registrar(corte: corteId, estado: .depositado)
    }

    func reciboSubido(depositoId: String, comprobantePath: String) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.deposito?.id == depositoId })
        else { return }
        Self.almacen[i].deposito?.comprobantePath = comprobantePath
        Self.almacen[i].deposito?.archivoLocal = nil
    }

    func agregarCuenta(_ nombre: String) async throws {
        guard !Self.cuentasAlmacen.contains(nombre) else { return }
        Self.cuentasAlmacen.append(nombre)
    }

    func firmar(corteId: String, nombre: String?, rol: String?,
                modo: ModoSegundaFirma, conteo: Centavos?) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == corteId }) else { return }
        let limpio = nombre?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hayNombre = !(limpio?.isEmpty ?? true)
        Self.almacen[i].segundaFirma = hayNombre ? limpio : nil
        Self.almacen[i].segundaFirmaRol = hayNombre ? rol : nil
        Self.almacen[i].segundaFirmaModo = modo.rawValue
        Self.almacen[i].segundaConteo = conteo
        // La fecha solo existe si hay firma: sin nombre no hay nada firmado.
        Self.almacen[i].segundaFirmaEn = hayNombre
            ? DepositosViewModel.textoFecha(Date()) : nil
    }

    func quitarFirma(corteId: String) async throws {
        guard let i = Self.almacen.firstIndex(where: { $0.id == corteId }) else { return }
        Self.almacen[i].segundaFirma = nil
        Self.almacen[i].segundaFirmaRol = nil
        Self.almacen[i].segundaFirmaEn = nil
        Self.almacen[i].segundaFirmaModo = nil
        Self.almacen[i].segundaConteo = nil
    }

    // MARK: - Semilla

    /// Los cortes solo dicen a QUÉ movimientos apuntan; el vínculo vive en
    /// `PuenteCortes`. Aquí no hay ningún total escrito que pueda desmentir a
    /// la suma de los movimientos.
    private static var pendientes: [Corte] {
        [
            Corte(
                id: "1",
                titulo: L.t("Culto domingo 6 de septiembre", "Sunday, September 6 service"),
                descripcion: L.t("Dinero en caja del domingo 6 · revísalo antes de llevarlo al banco",
                                 "Cash from Sunday, Sep 6 · review before taking it to the bank"),
                estado: .pendiente,
                movimientos: [],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 7 de septiembre", "Monday, Sep 7"),
                                           periodo: L.t("Septiembre 2026", "September 2026")),
                registradoPor: "Iván García",
                dobleFirmaPedida: true
            ),
            Corte(
                id: "2",
                titulo: L.t("Ofrendas miércoles 2 de septiembre", "Wednesday, September 2 offerings"),
                descripcion: L.t("Dinero en caja del miércoles 2 · todo en efectivo",
                                 "Cash from Wednesday, Sep 2 · all cash"),
                estado: .pendiente,
                movimientos: [],
                registro: RegistroDeposito(cuenta: "Chase ··7730",
                                           fecha: L.t("Jueves 3 de septiembre", "Thursday, Sep 3"),
                                           periodo: L.t("Septiembre 2026", "September 2026"))
            ),
            Corte(
                id: "3",
                titulo: L.t("Culto especial y fondo de construcción", "Special service and building fund"),
                descripcion: L.t("Corte grande · tres cheques y el efectivo del culto especial",
                                 "Large cut · three checks plus the special service cash"),
                estado: .pendiente,
                movimientos: [],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 7 de septiembre", "Monday, Sep 7"),
                                           periodo: L.t("Septiembre 2026", "September 2026"))
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
                movimientos: [],
                registro: RegistroDeposito(cuenta: "Banorte ··4821",
                                           fecha: L.t("Lunes 17 de agosto", "Monday, Aug 17"),
                                           periodo: L.t("Agosto 2026", "August 2026")),
                deposito: DepositoBancario(
                    id: "d10",
                    fecha: L.t("Lunes 17 de agosto", "Monday, Aug 17"),
                    periodo: L.t("Agosto 2026", "August 2026"),
                    monto: 14_320_00,
                    cuenta: "Banorte ··4821",
                    referencia: "OP-884213",
                    comprobantePath: "ficha-banorte-17ago.pdf")
            ),
        ]
    }
}
