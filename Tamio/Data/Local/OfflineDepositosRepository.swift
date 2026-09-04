import Foundation
import GRDB

/// `DepositosRepository` contra la base del teléfono, con los cambios en la
/// cola de salida. Nunca toca la red: de eso se encarga `MotorSincronizacion`.
///
/// **El corte se resuelve con un JOIN, no con una copia.** `corte` guarda el
/// sobre y `corteMovimiento` guarda a qué apunta; los importes salen de sumar
/// los movimientos de verdad. Es la misma forma que tienen `cortes` y
/// `corte_movimientos` en Supabase, y el mismo cálculo que hacía `PuenteCortes`
/// en memoria.
struct OfflineDepositosRepository: DepositosRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    // MARK: - Lectura

    func cortes(estado: EstadoDeposito) async throws -> [Corte] {
        let buscado = estado == .depositado ? CorteFila.depositado : CorteFila.abierto
        return try await cola.read { db in
            let filas = try CorteFila
                .filter(Column("estado") == buscado && Column("borrado") == false)
                .order(Column("fecha").desc)
                .fetchAll(db)
            let caja = try Self.efectivoEnCaja(db)
            return try filas.map { try Self.resolver($0, db, efectivoEnCaja: caja) }
        }
    }

    func movimientosLibres() async throws -> [Movimiento] {
        try await cola.read { db in
            try Self.libres(db)
        }
    }

    func cuentas() async throws -> [String] {
        // Las cuentas todavía no tienen tabla propia: su sitio es la
        // configuración de la iglesia. Mientras tanto salen de los cortes que
        // ya existen, más las que el usuario haya dado de alta en esta sesión.
        let deCortes: [String] = try await cola.read { db in
            try String.fetchAll(db, sql: """
                select distinct cuenta from corte where cuenta <> '' and borrado = 0
                """)
        }
        return Self.ordenadas(Set(deCortes).union(Self.cuentasAltas))
    }

    // MARK: - Escritura

    func crear(_ corte: Corte) async throws {
        let fila = CorteFila(corte)
        try await cola.write { db in
            try fila.insert(db)
            try Self.encolar(db, entidad: "corte", id: fila.id, operacion: .crear)
        }
    }

    func actualizar(_ corte: Corte) async throws {
        let fila = CorteFila(corte)
        try await cola.write { db in
            guard let actual = try CorteFila.fetchOne(db, key: fila.id) else { return }
            var nueva = fila
            // Lo que no decide la pantalla se conserva.
            nueva.depositoId = actual.depositoId
            nueva.registradoPor = actual.registradoPor
            nueva.actualizadoEn = actual.actualizadoEn
            try nueva.update(db)
            try Self.encolar(db, entidad: "corte", id: fila.id, operacion: .actualizar)
        }
    }

    func marcarDepositado(id: String) async throws {
        try await cola.write { db in
            guard var fila = try CorteFila.fetchOne(db, key: id) else { return }
            fila.estado = CorteFila.depositado
            fila.descripcion = L.t(
                "Depositado el \(DepositosViewModel.textoFecha(Date()))",
                "Deposited \(DepositosViewModel.textoFecha(Date()))")
            try fila.update(db)
            try Self.encolar(db, entidad: "corte", id: id, operacion: .actualizar)
        }
    }

    func agregarAlCorte(corteId: String, movimientoIds: [String]) async throws {
        try await cola.write { db in
            for movId in movimientoIds {
                // **Un movimiento vivo pertenece a UN corte.** El índice único
                // lo impone igual que Postgres; se comprueba antes para poder
                // ignorar el duplicado en vez de reventar la escritura entera.
                let ocupado = try CorteMovimientoFila
                    .filter(Column("movimientoId") == movId && Column("borrado") == false)
                    .fetchCount(db) > 0
                if ocupado { continue }

                let fila = CorteMovimientoFila(id: UUID().uuidString,
                                               corteId: corteId,
                                               movimientoId: movId,
                                               actualizadoEn: nil,
                                               borrado: false)
                try fila.insert(db)
                try Self.encolar(db, entidad: "corteMovimiento", id: fila.id,
                                 operacion: .crear)
            }
        }
    }

    func quitarDelCorte(corteId: String, movimientoId: String) async throws {
        try await cola.write { db in
            guard var fila = try CorteMovimientoFila
                .filter(Column("corteId") == corteId
                        && Column("movimientoId") == movimientoId
                        && Column("borrado") == false)
                .fetchOne(db) else { return }
            // Borrado lógico, igual que en Supabase: el movimiento vuelve a
            // quedar libre y el borrado se puede sincronizar.
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, entidad: "corteMovimiento", id: fila.id,
                             operacion: .eliminar)
        }
    }

    func agregarCuenta(_ nombre: String) async throws {
        Self.cuentasAltas.insert(nombre)
    }

    // MARK: - Resolución

    /// Rellena el corte con los movimientos que apunta y con el efectivo en
    /// caja. Ninguno de los dos se guarda: son el `JOIN`.
    private static func resolver(_ fila: CorteFila, _ db: Database,
                                 efectivoEnCaja: Centavos) throws -> Corte {
        var c = fila.corte
        let ids = try String.fetchAll(db, sql: """
            select movimientoId from corteMovimiento where corteId = ? and borrado = 0
            """, arguments: [fila.id])
        c.movimientos = try MovimientoFila
            .filter(ids.contains(Column("id")) && Column("borrado") == false)
            .fetchAll(db)
            .map(\.movimiento)
            .map { Self.conDeposito($0, db) }
        c.efectivoEnCaja = efectivoEnCaja
        c.porRevisar = try MovimientoFila
            .filter(Column("marcadoPendiente") == true && Column("borrado") == false)
            .fetchCount(db)
        return c
    }

    /// `sinDepositar` se resuelve al leer: es una ausencia en la tabla puente,
    /// no un campo del movimiento.
    private static func conDeposito(_ m: Movimiento, _ db: Database) -> Movimiento {
        var m = m
        m.sinDepositar = (try? Self.sinDepositar(m.id, db)) ?? true
        m.incluidoEnCorte = (try? Self.enAlgunCorte(m.id, db)) ?? false
        return m
    }

    static func sinDepositar(_ movimientoId: String, _ db: Database) throws -> Bool {
        let estado = try String.fetchOne(db, sql: """
            select c.estado from corteMovimiento cm
            join corte c on c.id = cm.corteId and c.borrado = 0
            where cm.movimientoId = ? and cm.borrado = 0
            """, arguments: [movimientoId])
        guard let estado else { return true }   // ningún corte lo reclama
        return estado != CorteFila.depositado
    }

    static func enAlgunCorte(_ movimientoId: String, _ db: Database) throws -> Bool {
        try CorteMovimientoFila
            .filter(Column("movimientoId") == movimientoId && Column("borrado") == false)
            .fetchCount(db) > 0
    }

    /// Los ingresos que ningún corte reclama: lo que se puede meter en uno.
    static func libres(_ db: Database) throws -> [Movimiento] {
        try MovimientoFila.fetchAll(db, sql: """
            select m.* from movimiento m
            left join corteMovimiento cm
              on cm.movimientoId = m.id and cm.borrado = 0
            where m.tipo = 'ingreso' and m.borrado = 0 and cm.id is null
            order by m.fecha desc
            """).map(\.movimiento)
    }

    /// **El efectivo que hay en caja.** Como lo contado se deposita íntegro
    /// —nunca sale un gasto del dinero de la ofrenda—, es lo recibido en
    /// efectivo que ningún corte YA DEPOSITADO reclama.
    ///
    /// El filtro por forma de pago se hace en Swift y no en SQL a propósito: el
    /// método viaja como texto traducido y con el número pegado ("Cheque 8823",
    /// "Cash"), así que `where metodo = 'Efectivo'` fallaría con la app en
    /// inglés. `Catalogos.clave(deMetodo:)` reconoce la raíz en los dos idiomas.
    static func efectivoEnCaja(_ db: Database) throws -> Centavos {
        let filas = try MovimientoFila.fetchAll(db, sql: """
            select m.* from movimiento m
            left join corteMovimiento cm
              on cm.movimientoId = m.id and cm.borrado = 0
            left join corte c
              on c.id = cm.corteId and c.borrado = 0
            where m.tipo = 'ingreso' and m.borrado = 0
              and (c.estado is null or c.estado <> ?)
            """, arguments: [CorteFila.depositado])
        return filas.map(\.movimiento)
            .filter(\.esEfectivo)
            .reduce(0) { $0 + $1.monto }
    }

    // MARK: - Interno

    /// Cuentas dadas de alta en esta sesión. Provisional: su sitio definitivo
    /// es la configuración de la iglesia, con su propia tabla.
    private static var cuentasAltas: Set<String> = []

    private static func ordenadas(_ s: Set<String>) -> [String] {
        s.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Igual que en movimientos: un alta que todavía no ha salido sigue siendo
    /// un alta aunque se edite después.
    private static func encolar(_ db: Database, entidad: String, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == entidad && Column("registroId") == id)
            .fetchOne(db)

        let efectiva: OperacionPendiente.Operacion
        if previa?.operacion == OperacionPendiente.Operacion.crear.rawValue,
           operacion == .actualizar {
            efectiva = .crear
        } else {
            efectiva = operacion
        }

        try OperacionPendiente
            .filter(Column("entidad") == entidad && Column("registroId") == id)
            .deleteAll(db)

        var nueva = OperacionPendiente(id: nil, entidad: entidad, registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}

/// El repositorio de depósitos que usa la app: la base del teléfono, siempre.
/// En modo revisión son datos de ejemplo, porque sin sesión iniciada Supabase
/// no devolvería ni aceptaría nada que sincronizar.
func repositorioDepositos() -> DepositosRepository {
    ModoRevision.sinLogin ? MockDepositosRepository() : OfflineDepositosRepository()
}
