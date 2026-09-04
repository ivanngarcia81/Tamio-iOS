import Foundation
import GRDB

/// `MovimientosRepository` que trabaja contra la base del teléfono y deja los
/// cambios en la cola de salida. Nunca toca la red: de eso se encarga
/// `MotorSincronizacion`, que corre aparte.
///
/// Que la escritura no espere al servidor es justo el punto: el tesorero
/// captura el sobre en el templo, con señal o sin ella, y la app se ocupa
/// después.
struct OfflineMovimientosRepository: MovimientosRepository {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    func lista(tipo: TipoMovimiento) async throws -> [Movimiento] {
        let tipoStr = tipo == .ingreso ? "ingreso" : "gasto"
        return try await cola.read { db in
            try MovimientoFila
                .filter(Column("tipo") == tipoStr && Column("borrado") == false)
                .order(Column("fecha").desc)
                .fetchAll(db)
                .map(\.movimiento)
                // `sinDepositar` se resuelve aquí, contra la tabla puente: es
                // una AUSENCIA —que ningún corte depositado lo reclame—, no un
                // campo del movimiento. La columna local existe por espejo del
                // esquema, pero su valor guardado no manda.
                .map { m in
                    var m = m
                    m.sinDepositar = (try? OfflineDepositosRepository.sinDepositar(m.id, db)) ?? true
                    m.incluidoEnCorte = (try? OfflineDepositosRepository.enAlgunCorte(m.id, db)) ?? false
                    return m
                }
        }
    }

    func crear(_ m: Movimiento) async throws {
        var nuevo = m
        // El id se genera aquí, no en el servidor: sin eso no se podría crear
        // nada sin red, ni referenciarlo hasta que llegara la respuesta.
        if nuevo.id.isEmpty { nuevo.id = UUID().uuidString }
        let seq = try await siguienteFolioLocal(tipo: nuevo.tipo)
        nuevo.folio = String(seq)

        // Copia inmutable antes del closure: capturar la `var` es un error en
        // Swift 6, no solo un aviso.
        let aInsertar = nuevo
        try await cola.write { db in
            try MovimientoFila(aInsertar, folioProvisional: true).insert(db)
            try Self.encolar(db, id: aInsertar.id, operacion: .crear)
        }
    }

    func actualizar(_ m: Movimiento) async throws {
        try await cola.write { db in
            guard let actual = try MovimientoFila.fetchOne(db, key: m.id) else { return }
            // El folio y su condición de provisional no los decide la pantalla.
            var fila = MovimientoFila(m,
                                      folioProvisional: actual.folioProvisional,
                                      actualizadoEn: actual.actualizadoEn)
            fila.folio = actual.folio
            fila.folioSeq = actual.folioSeq
            try fila.update(db)
            try Self.encolar(db, id: m.id, operacion: .actualizar)
        }
    }

    func eliminar(id: String) async throws {
        try await cola.write { db in
            guard var fila = try MovimientoFila.fetchOne(db, key: id) else { return }
            // Borrado lógico, igual que en Supabase: así el borrado se puede
            // propagar. Un DELETE de verdad no se puede sincronizar.
            fila.borrado = true
            try fila.update(db)
            try Self.encolar(db, id: id, operacion: .eliminar)
        }
    }

    /// Vista previa para la hoja de captura.
    func siguienteFolio(tipo: TipoMovimiento) async -> String {
        guard let seq = try? await siguienteFolioLocal(tipo: tipo) else { return "" }
        return "P-\(seq)"
    }

    // MARK: - Privado

    /// Numeración local provisional. No pretende coincidir con la del
    /// servidor: solo distingue un movimiento de otro hasta que el contador
    /// de Supabase le dé su folio definitivo al sincronizar.
    private func siguienteFolioLocal(tipo: TipoMovimiento) async throws -> Int {
        let tipoStr = tipo == .ingreso ? "ingreso" : "gasto"
        return try await cola.read { db in
            // `fetchOne` ya devuelve `Int?`; el `?? 0` de la consulta lo dejaba
            // en `Int`, así que el segundo `??` no se ejecutaba nunca. Sin
            // tabla vacía se notaba poco, pero era el caso que pretendía cubrir.
            let maximo = try Int.fetchOne(db, sql: """
                select max(folioSeq) from movimiento where tipo = ?
                """, arguments: [tipoStr])
            return (maximo ?? 0) + 1
        }
    }

    /// Deja constancia de que este registro tiene algo que subir.
    ///
    /// Si ya había una operación pendiente para el mismo registro se sustituye:
    /// al servidor le da igual por cuántas ediciones haya pasado, solo importa
    /// cómo quedó. La excepción es un borrado sobre algo que aún no se ha
    /// creado allí, que se resuelve al subir.
    private static func encolar(_ db: Database, id: String,
                                operacion: OperacionPendiente.Operacion) throws {
        let previa = try OperacionPendiente
            .filter(Column("entidad") == "movimiento" && Column("registroId") == id)
            .fetchOne(db)

        // Un alta que todavía no ha salido sigue siendo un alta aunque se edite.
        let efectiva: OperacionPendiente.Operacion
        if previa?.operacion == OperacionPendiente.Operacion.crear.rawValue,
           operacion == .actualizar {
            efectiva = .crear
        } else {
            efectiva = operacion
        }

        try OperacionPendiente
            .filter(Column("entidad") == "movimiento" && Column("registroId") == id)
            .deleteAll(db)

        var nueva = OperacionPendiente(id: nil, entidad: "movimiento", registroId: id,
                                       operacion: efectiva.rawValue,
                                       creadoEn: Date().timeIntervalSince1970,
                                       intentos: 0, ultimoError: nil)
        try nueva.insert(db)
    }
}
