import Foundation
import GRDB
import Observation
import Supabase

/// Lleva y trae entre la base del teléfono y Supabase.
///
/// El orden importa: **primero se sube y luego se baja**. Al revés, lo que baja
/// pisaría los cambios locales que aún no han salido.
@Observable
final class MotorSincronizacion {

    static let compartido = MotorSincronizacion()

    enum Estado: Equatable {
        case reposo
        case sincronizando
        /// No se pudo completar; el detalle es para enseñarlo, no para tragárselo.
        case fallo(String)
    }

    private(set) var estado: Estado = .reposo
    private(set) var ultimaSincronizacion: Date?
    /// Cuántos cambios esperan turno para subir. La UI lo enseña para que
    /// nadie crea que algo está guardado en el servidor cuando no lo está.
    private(set) var pendientes = 0

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }
    private let repoRemoto = SupabaseMovimientosRepository()

    private init() {}

    // MARK: - API

    @MainActor
    func sincronizar() async {
        guard estado != .sincronizando, !ModoRevision.sinLogin else { return }
        estado = .sincronizando
        do {
            try await subirPendientes()
            try await bajarCambios()
            try await bajarAportantes()
            try await bajarIglesia()
            // Los cortes DESPUÉS de los movimientos: el corte apunta a
            // movimientos por id, y resolver un puntero a algo que todavía no
            // ha bajado deja el corte vacío hasta la vuelta siguiente.
            try await bajarCortes()
            try await bajarCorteMovimientos()
            try await bajarDepositos()
            // Los recibos al final: son archivos, tardan, y ninguna otra cosa
            // depende de ellos. Que falle la subida de una foto no puede dejar
            // sin sincronizar el resto.
            try? await subirRecibosPendientes()
            ultimaSincronizacion = Date()
            estado = .reposo
        } catch {
            estado = .fallo(error.localizedDescription)
        }
        await recontarPendientes()
    }

    @MainActor
    func recontarPendientes() async {
        pendientes = (try? await cola.read { db in
            try OperacionPendiente.fetchCount(db)
        }) ?? 0
    }

    // MARK: - Subida

    private func subirPendientes() async throws {
        let operaciones = try await cola.read { db in
            try OperacionPendiente.order(Column("creadoEn")).fetchAll(db)
        }

        for op in operaciones {
            do {
                try await subir(op)
                _ = try await cola.write { db in
                    try OperacionPendiente.deleteOne(db, key: op.id)
                }
            } catch {
                // Se anota el fallo y se sigue con las demás: que un registro
                // dé problemas no puede bloquear la cola entera para siempre.
                try? await cola.write { db in
                    try db.execute(sql: """
                        update outbox set intentos = intentos + 1, ultimoError = ?
                        where id = ?
                        """, arguments: [error.localizedDescription, op.id])
                }
            }
        }
    }

    private func subir(_ op: OperacionPendiente) async throws {
        if op.entidad == "iglesia" {
            try await subirIglesia(op.registroId)
            return
        }
        if op.entidad == "aportante" {
            try await subirAportante(op)
            return
        }
        if op.entidad == "corte" {
            try await subirCorte(op)
            return
        }
        if op.entidad == "corteMovimiento" {
            try await subirCorteMovimiento(op)
            return
        }
        if op.entidad == "deposito" {
            try await subirDeposito(op)
            return
        }
        guard let fila = try await cola.read({ db in
            try MovimientoFila.fetchOne(db, key: op.registroId)
        }) else { return }

        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            // `crear` del repositorio remoto pide el folio al contador de
            // Postgres: aquí es donde el provisional se convierte en definitivo.
            try await repoRemoto.crear(fila.movimientoSinPrefijo)
            try await marcarSubido(op.registroId)

        case .actualizar:
            try await repoRemoto.actualizar(fila.movimientoSinPrefijo)
            try await marcarSubido(op.registroId)

        case .eliminar:
            try await repoRemoto.eliminar(id: op.registroId)
            _ = try await cola.write { db in
                try MovimientoFila.deleteOne(db, key: op.registroId)
            }

        case .none:
            return
        }
    }

    /// Tras subir, el registro deja de ser provisional. El folio definitivo lo
    /// traerá la bajada, que es quien lee lo que quedó realmente en el servidor.
    private func marcarSubido(_ id: String) async throws {
        _ = try await cola.write { db in
            try db.execute(sql: "update movimiento set folioProvisional = 0 where id = ?",
                           arguments: [id])
        }
    }

    // MARK: - Aportantes

    private struct AportanteEscritura: Encodable {
        let uid: String
        let churchId: String
        let nombre: String
        let telefono: String?
        let email: String?
        let rfc: String?
        let direccion: String?
        let estadoCivil: String?
        let fechaNacimiento: String?
        let fechaIngreso: String?
        let fechaCongregacion: String?
        let estadoMembresia: String
        let frecuenciaAporte: String
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, nombre, telefono, email, rfc, direccion, deleted
            case churchId          = "church_id"
            case estadoCivil       = "estado_civil"
            case fechaNacimiento   = "fecha_nacimiento"
            case fechaIngreso      = "fecha_ingreso"
            case fechaCongregacion = "fecha_congregacion"
            case estadoMembresia   = "estado_membresia"
            case frecuenciaAporte  = "frecuencia_aporte"
        }
    }

    private func subirAportante(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try AportanteFila.fetchOne(db, key: op.registroId)
        }) else { return }

        let cuerpo = AportanteEscritura(
            uid: fila.id, churchId: churchIdActivo, nombre: fila.nombre,
            telefono: fila.telefono, email: fila.correo, rfc: fila.idFiscal,
            direccion: fila.direccion, estadoCivil: fila.estadoCivil,
            fechaNacimiento: fila.nacimiento, fechaIngreso: fila.miembroDesde,
            fechaCongregacion: fila.congregaDesde, estadoMembresia: fila.estado,
            frecuenciaAporte: fila.frecuencia,
            deleted: op.operacion == OperacionPendiente.Operacion.eliminar.rawValue)

        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            try await supabase.from("members").insert(cuerpo).execute()
        case .actualizar, .eliminar:
            try await supabase.from("members").update(cuerpo)
                .eq("uid", value: fila.id)
                .eq("church_id", value: churchIdActivo)
                .execute()
        case .none:
            return
        }
    }

    private func bajarAportantes() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let nombre: String?
            let telefono, email, rfc, direccion: String?
            let estadoCivil, fechaNacimiento, fechaIngreso, fechaCongregacion: String?
            let estadoMembresia, frecuenciaAporte: String?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, nombre, telefono, email, rfc, direccion, deleted
                case estadoCivil       = "estado_civil"
                case fechaNacimiento   = "fecha_nacimiento"
                case fechaIngreso      = "fecha_ingreso"
                case fechaCongregacion = "fecha_congregacion"
                case estadoMembresia   = "estado_membresia"
                case frecuenciaAporte  = "frecuencia_aporte"
                case updatedAt         = "updated_at"
            }
        }

        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'aportante'")
        }
        var consulta = supabase.from("members").select()
            .eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [FilaRemota] = try await consulta
            .order("updated_at", ascending: true)
            .limit(500)
            .execute()
            .value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let pendiente = try OperacionPendiente
                    .filter(Column("entidad") == "aportante" && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }

                var a = Aportante(
                    id: r.uid, nombre: r.nombre ?? "",
                    estado: AportanteFila.estado(r.estadoMembresia ?? "activo"),
                    rol: "", miembroDesde: r.fechaIngreso ?? "",
                    telefono: r.telefono ?? "", correo: r.email ?? "",
                    nacimiento: r.fechaNacimiento ?? "", direccion: r.direccion ?? "",
                    estadoCivil: r.estadoCivil ?? "", idFiscal: r.rfc ?? "",
                    congregaDesde: r.fechaCongregacion ?? "",
                    frecuencia: FrecuenciaAporte(rawValue: r.frecuenciaAporte ?? "") ?? .ocasional,
                    aportes: [], familia: [])
                a.id = r.uid
                try AportanteFila(a, actualizadoEn: r.updatedAt,
                                  borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('aportante', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    // MARK: - Configuración de la iglesia

    private func subirIglesia(_ id: String) async throws {
        guard let fila = try await cola.read({ db in
            try IglesiaFila.fetchOne(db, key: id)
        }) else { return }

        struct IglesiaUpdate: Encodable {
            let nombre, direccion, ciudad, estado, pais: String
            let codigoPostal, idFiscal, telefono, correo, moneda: String
            let pieInstitucional: String
            let pastorNombre, pastorCargo: String
            let tesoreroNombre, tesoreroCargo: String
            let secretarioNombre, secretarioCargo: String
            let imprimirFirmas: Bool
            enum CodingKeys: String, CodingKey {
                case nombre, direccion, ciudad, estado, pais, telefono, correo, moneda
                case codigoPostal      = "codigo_postal"
                case idFiscal          = "id_fiscal"
                case pieInstitucional  = "pie_institucional"
                case pastorNombre      = "pastor_nombre"
                case pastorCargo       = "pastor_cargo"
                case tesoreroNombre    = "tesorero_nombre"
                case tesoreroCargo     = "tesorero_cargo"
                case secretarioNombre  = "secretario_nombre"
                case secretarioCargo   = "secretario_cargo"
                case imprimirFirmas    = "imprimir_firmas"
            }
        }

        let c = fila.configuracion
        try await supabase
            .from("iglesias")
            .update(IglesiaUpdate(
                nombre: c.nombre, direccion: c.direccion, ciudad: c.ciudad,
                estado: c.estado, pais: c.pais, codigoPostal: c.codigoPostal,
                idFiscal: c.idFiscal, telefono: c.telefono, correo: c.correo,
                moneda: c.moneda, pieInstitucional: c.pieInstitucional,
                pastorNombre: c.pastorNombre, pastorCargo: c.pastorCargo,
                tesoreroNombre: c.tesoreroNombre, tesoreroCargo: c.tesoreroCargo,
                secretarioNombre: c.secretarioNombre, secretarioCargo: c.secretarioCargo,
                imprimirFirmas: c.imprimirFirmas))
            .eq("id", value: id)
            .execute()
    }

    private func bajarIglesia() async throws {
        // No se pisa si hay cambios locales sin subir: los suyos van primero.
        let pendiente = try await cola.read { db in
            try OperacionPendiente.filter(Column("entidad") == "iglesia").fetchCount(db) > 0
        }
        if pendiente { return }

        struct FilaIglesia: Decodable {
            let nombre: String?
            let direccion, ciudad, estado, pais: String?
            let codigoPostal, idFiscal, telefono, correo, moneda: String?
            let pieInstitucional: String?
            let pastorNombre, pastorCargo: String?
            let tesoreroNombre, tesoreroCargo: String?
            let secretarioNombre, secretarioCargo: String?
            let imprimirFirmas: Bool?
            enum CodingKeys: String, CodingKey {
                case nombre, direccion, ciudad, estado, pais, telefono, correo, moneda
                case codigoPostal      = "codigo_postal"
                case idFiscal          = "id_fiscal"
                case pieInstitucional  = "pie_institucional"
                case pastorNombre      = "pastor_nombre"
                case pastorCargo       = "pastor_cargo"
                case tesoreroNombre    = "tesorero_nombre"
                case tesoreroCargo     = "tesorero_cargo"
                case secretarioNombre  = "secretario_nombre"
                case secretarioCargo   = "secretario_cargo"
                case imprimirFirmas    = "imprimir_firmas"
            }
        }

        let filas: [FilaIglesia] = try await supabase
            .from("iglesias")
            .select()
            .eq("id", value: churchIdActivo)
            .limit(1)
            .execute()
            .value
        guard let r = filas.first else { return }

        var c = ConfiguracionIglesia()
        c.nombre = r.nombre ?? ""
        c.direccion = r.direccion ?? ""
        c.ciudad = r.ciudad ?? ""
        c.estado = r.estado ?? ""
        c.pais = r.pais ?? ""
        c.codigoPostal = r.codigoPostal ?? ""
        c.idFiscal = r.idFiscal ?? ""
        c.telefono = r.telefono ?? ""
        c.correo = r.correo ?? ""
        c.moneda = r.moneda ?? Catalogos.monedaPorDefecto.codigo
        c.pieInstitucional = r.pieInstitucional ?? ""
        c.pastorNombre = r.pastorNombre ?? ""
        c.pastorCargo = r.pastorCargo ?? "Pastor"
        c.tesoreroNombre = r.tesoreroNombre ?? ""
        c.tesoreroCargo = r.tesoreroCargo ?? "Tesorero"
        c.secretarioNombre = r.secretarioNombre ?? ""
        c.secretarioCargo = r.secretarioCargo ?? "Secretario"
        c.imprimirFirmas = r.imprimirFirmas ?? true

        // Copia inmutable antes de entrar al closure: capturar la `var` es un
        // error en Swift 6, no solo un aviso.
        let configuracion = c
        try await cola.write { db in
            try IglesiaFila(id: churchIdActivo, configuracion).save(db)
        }
    }

    // MARK: - Bajada

    private func bajarCambios() async throws {
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'movimiento'")
        }

        var consulta = supabase
            .from("transactions")
            .select()
            .eq("church_id", value: churchIdActivo)
        if let cursor {
            consulta = consulta.gt("updated_at", value: cursor)
        }
        let filas: [FilaRemota] = try await consulta
            .order("updated_at", ascending: true)
            .limit(500)
            .execute()
            .value

        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for remota in filas {
                // Nunca se pisa un registro con cambios locales sin subir: los
                // suyos van primero y ya bajará su versión en la próxima vuelta.
                let tienePendiente = try OperacionPendiente
                    .filter(Column("registroId") == remota.uid)
                    .fetchCount(db) > 0
                if tienePendiente { continue }

                if remota.deleted == true {
                    try MovimientoFila.deleteOne(db, key: remota.uid)
                } else {
                    try remota.fila.save(db)
                }
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('movimiento', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    // MARK: - Depósitos

    /// Lo que viaja a `cortes`. **`periodo` y `ficha` no van**: en Supabase no
    /// tienen columna en esta tabla, pertenecen a `depositos_bancarios`, que
    /// solo nace cuando el dinero llega al banco. Hasta entonces viven como
    /// borrador en el teléfono.
    private struct CorteRemoto: Encodable {
        let uid: String
        let churchId: String
        let nombre: String
        let fecha: String
        let cuentaBanco: String
        let estado: String
        let notas: String
        let dobleFirmaPedida: Bool
        let segundaFirma: String?
        let segundaFirmaRol: String?
        let segundaFirmaEn: String?
        let segundaFirmaModo: String?
        let segundaConteo: Int?
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, nombre, fecha, estado, notas, deleted
            case churchId          = "church_id"
            case cuentaBanco       = "cuenta_banco"
            case dobleFirmaPedida  = "doble_firma_pedida"
            case segundaFirma      = "segunda_firma"
            case segundaFirmaRol   = "segunda_firma_rol"
            case segundaFirmaEn    = "segunda_firma_en"
            case segundaFirmaModo  = "segunda_firma_modo"
            case segundaConteo     = "segunda_conteo"
        }
    }

    private func subirCorte(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try CorteFila.fetchOne(db, key: op.registroId)
        }) else { return }

        let remoto = CorteRemoto(
            uid: fila.id, churchId: churchIdActivo, nombre: fila.titulo,
            fecha: fila.fecha, cuentaBanco: fila.cuenta, estado: fila.estado,
            notas: fila.descripcion,
            dobleFirmaPedida: fila.dobleFirmaPedida,
            segundaFirma: fila.segundaFirma, segundaFirmaRol: fila.segundaFirmaRol,
            segundaFirmaEn: fila.segundaFirmaEn, segundaFirmaModo: fila.segundaFirmaModo,
            segundaConteo: fila.segundaConteo,
            deleted: fila.borrado)

        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear, .actualizar, .eliminar:
            // `upsert` y no `insert`/`update` por separado: el mismo corte
            // puede haber salido ya desde otro aparato, y un alta repetida no
            // debe reventar la cola entera.
            try await supabase.from("cortes").upsert(remoto, onConflict: "uid")
                .execute()
        case .none:
            return
        }
    }

    /// La tabla puente: dos columnas útiles y nada más.
    private struct CorteMovimientoRemoto: Encodable {
        let uid: String
        let churchId: String
        let corteUid: String
        let txUid: String
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, deleted
            case churchId = "church_id"
            case corteUid = "corte_uid"
            case txUid    = "tx_uid"
        }
    }

    private func subirCorteMovimiento(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try CorteMovimientoFila.fetchOne(db, key: op.registroId)
        }) else { return }

        let remoto = CorteMovimientoRemoto(
            uid: fila.id, churchId: churchIdActivo,
            corteUid: fila.corteId, txUid: fila.movimientoId,
            deleted: fila.borrado)
        try await supabase.from("corte_movimientos").upsert(remoto, onConflict: "uid")
            .execute()
    }

    private struct CorteRemotoLeido: Decodable {
        let uid: String
        let nombre: String?
        let fecha: String?
        let cuentaBanco: String?
        let estado: String?
        let notas: String?
        let depositoUid: String?
        let registradoPor: String?
        let dobleFirmaPedida: Bool?
        let segundaFirma: String?
        let segundaFirmaRol: String?
        let segundaFirmaEn: String?
        let segundaFirmaModo: String?
        let segundaConteo: Int?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, nombre, fecha, estado, notas, deleted
            case cuentaBanco       = "cuenta_banco"
            case depositoUid       = "deposito_uid"
            case registradoPor     = "registrado_por"
            case dobleFirmaPedida  = "doble_firma_pedida"
            case segundaFirma      = "segunda_firma"
            case segundaFirmaRol   = "segunda_firma_rol"
            case segundaFirmaEn    = "segunda_firma_en"
            case segundaFirmaModo  = "segunda_firma_modo"
            case segundaConteo     = "segunda_conteo"
            case updatedAt         = "updated_at"
        }
    }

    private func bajarCortes() async throws {
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'corte'")
        }
        var consulta = supabase.from("cortes").select().eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [CorteRemotoLeido] = try await consulta
            .order("updated_at", ascending: true).limit(500).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let tienePendiente = try OperacionPendiente
                    .filter(Column("registroId") == r.uid).fetchCount(db) > 0
                if tienePendiente { continue }

                if r.deleted == true {
                    try CorteFila.deleteOne(db, key: r.uid)
                    continue
                }
                // `periodo` y `ficha` son borrador local y no viajan, así que
                // se conservan los que ya hubiera en vez de vaciarlos.
                let previo = try CorteFila.fetchOne(db, key: r.uid)
                // Campo a campo y no en un solo `init`: con veinte argumentos
                // y sus `??`, el comprobador de tipos de Swift se rinde.
                var fila = previo ?? CorteFila(id: r.uid)
                fila.titulo = r.nombre ?? ""
                fila.descripcion = r.notas ?? ""
                fila.estado = r.estado ?? CorteFila.abierto
                fila.cuenta = r.cuentaBanco ?? ""
                fila.fecha = r.fecha ?? ""
                fila.depositoId = r.depositoUid
                fila.registradoPor = r.registradoPor ?? ""
                fila.dobleFirmaPedida = r.dobleFirmaPedida ?? false
                fila.segundaFirma = r.segundaFirma
                fila.segundaFirmaRol = r.segundaFirmaRol
                fila.segundaFirmaEn = r.segundaFirmaEn
                fila.segundaFirmaModo = r.segundaFirmaModo
                fila.segundaConteo = r.segundaConteo
                fila.actualizadoEn = r.updatedAt
                fila.borrado = false
                try fila.save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('corte', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    private struct CorteMovimientoLeido: Decodable {
        let uid: String
        let corteUid: String?
        let txUid: String?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, deleted
            case corteUid  = "corte_uid"
            case txUid     = "tx_uid"
            case updatedAt = "updated_at"
        }
    }

    private func bajarCorteMovimientos() async throws {
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'corteMovimiento'")
        }
        var consulta = supabase.from("corte_movimientos").select()
            .eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [CorteMovimientoLeido] = try await consulta
            .order("updated_at", ascending: true).limit(1000).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let tienePendiente = try OperacionPendiente
                    .filter(Column("registroId") == r.uid).fetchCount(db) > 0
                if tienePendiente { continue }
                guard let corteUid = r.corteUid, let txUid = r.txUid else { continue }

                if r.deleted == true {
                    // Borrado lógico: el movimiento vuelve a quedar libre. Se
                    // BORRA la fila local en vez de marcarla, porque el índice
                    // único solo mira las vivas y una fila muerta no aporta.
                    try CorteMovimientoFila.deleteOne(db, key: r.uid)
                    continue
                }
                // El índice único local rechazaría un segundo corte vivo para
                // el mismo movimiento. Si el servidor manda uno, gana el
                // servidor: se retira el anterior antes de guardar.
                try db.execute(sql: """
                    delete from corteMovimiento where movimientoId = ? and id <> ? and borrado = 0
                    """, arguments: [txUid, r.uid])

                try CorteMovimientoFila(id: r.uid, corteId: corteUid,
                                        movimientoId: txUid,
                                        actualizadoEn: r.updatedAt,
                                        borrado: false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('corteMovimiento', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    // MARK: - Depósitos bancarios

    /// `monto` va en UNIDADES, no en centavos: la columna es `double precision`,
    /// igual que `transactions.monto`. La app opera en centavos y solo divide
    /// aquí, en la frontera.
    private struct DepositoRemoto: Encodable {
        let uid: String
        let churchId: String
        let fecha: String
        let periodo: String
        let monto: Double
        let moneda: String
        let cuentaBanco: String
        let referencia: String
        let comprobantePath: String?
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, fecha, periodo, monto, moneda, referencia, deleted
            case churchId         = "church_id"
            case cuentaBanco      = "cuenta_banco"
            case comprobantePath  = "comprobante_path"
        }
    }

    private func subirDeposito(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try DepositoFila.fetchOne(db, key: op.registroId)
        }) else { return }

        let remoto = DepositoRemoto(
            uid: fila.id, churchId: churchIdActivo,
            fecha: fila.fecha, periodo: fila.periodo,
            monto: Double(fila.monto) / 100.0,
            moneda: Money.codigo,
            cuentaBanco: fila.cuenta, referencia: fila.referencia,
            comprobantePath: fila.comprobantePath,
            deleted: fila.borrado)
        try await supabase.from("depositos_bancarios")
            .upsert(remoto, onConflict: "uid").execute()
    }

    /// **Los recibos que siguen solo en el teléfono.**
    ///
    /// El recibo se guarda en local en cuanto se toma la foto, sin esperar a la
    /// red: se hace EN EL BANCO, que es donde peor señal hay, y el papel se
    /// tira. Esto es lo que lo lleva al bucket cuando por fin hay cobertura, y
    /// solo entonces se suelta la copia local.
    private func subirRecibosPendientes() async throws {
        let pendientes = try await cola.read { db in
            try DepositoFila
                .filter(Column("comprobantePath") == nil && Column("borrado") == false)
                .fetchAll(db)
        }
        guard !pendientes.isEmpty else { return }
        let almacen = SupabaseComprobantesStorage()

        for fila in pendientes {
            guard let nombre = fila.archivoLocal,
                  let url = RecibosLocales.url(nombre),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let ruta = try await almacen.subir(url)
                try await OfflineDepositosRepository()
                    .reciboSubido(depositoId: fila.id, comprobantePath: ruta)
            } catch {
                // Se reintenta en la siguiente vuelta. El archivo NO se borra:
                // mientras no esté arriba, la copia local es la única que hay.
                continue
            }
        }
    }

    private struct DepositoRemotoLeido: Decodable {
        let uid: String
        let fecha: String?
        let periodo: String?
        let monto: Double?
        let cuentaBanco: String?
        let referencia: String?
        let comprobantePath: String?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, fecha, periodo, monto, referencia, deleted
            case cuentaBanco     = "cuenta_banco"
            case comprobantePath = "comprobante_path"
            case updatedAt       = "updated_at"
        }
    }

    private func bajarDepositos() async throws {
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'deposito'")
        }
        var consulta = supabase.from("depositos_bancarios").select()
            .eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [DepositoRemotoLeido] = try await consulta
            .order("updated_at", ascending: true).limit(500).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let tienePendiente = try OperacionPendiente
                    .filter(Column("registroId") == r.uid).fetchCount(db) > 0
                if tienePendiente { continue }
                if r.deleted == true {
                    try DepositoFila.deleteOne(db, key: r.uid)
                    continue
                }
                let previo = try DepositoFila.fetchOne(db, key: r.uid)
                var fila = previo ?? DepositoFila(DepositoBancario(id: r.uid, fecha: "",
                                                                   periodo: "", monto: 0,
                                                                   cuenta: ""))
                fila.fecha = r.fecha ?? ""
                fila.periodo = r.periodo ?? ""
                fila.monto = Int(((r.monto ?? 0) * 100).rounded())
                fila.cuenta = r.cuentaBanco ?? ""
                fila.referencia = r.referencia ?? ""
                fila.comprobantePath = r.comprobantePath
                fila.actualizadoEn = r.updatedAt
                fila.borrado = false
                try fila.save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('deposito', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }
}

// MARK: - Fila remota

private extension MotorSincronizacion {
    /// Lo que devuelve `transactions`, en crudo.
    struct FilaRemota: Decodable {
        let uid: String
        let memberUid: String?
        let tipo: String?
        let categoria: String?
        let subcategoria: String?
        let concepto: String?
        let fecha: String?
        let monto: Double?
        let metodoPago: String?
        let beneficiario: String?
        let beneficiarioRfc: String?
        let comprobantePath: String?
        let aportanteNombre: String?
        let emitirConstancia: Int?
        let notas: String?
        let estado: String?
        let registradoPor: String?
        let folio: String?
        let folioSeq: Int?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, tipo, categoria, subcategoria, concepto, fecha, monto
            case notas, estado, folio, deleted, beneficiario
            case memberUid         = "member_uid"
            case metodoPago        = "metodo_pago"
            case beneficiarioRfc   = "beneficiario_rfc"
            case comprobantePath   = "comprobante_path"
            case aportanteNombre   = "aportante_nombre"
            case emitirConstancia  = "emitir_constancia"
            case registradoPor     = "registrado_por"
            case folioSeq          = "folio_seq"
            case updatedAt         = "updated_at"
        }

        var fila: MovimientoFila {
            let esIngreso = tipo == "ingreso"
            let nombre = aportanteNombre
            let fechaDate = Fechas.desdeTexto(fecha) ?? Date()
            let hf = DateFormatter()
            hf.locale = Locale(identifier: "en_US_POSIX")
            hf.dateFormat = "HH:mm"
            let cat = categoria ?? ""

            return MovimientoFila(
                id: uid,
                tipo: esIngreso ? "ingreso" : "gasto",
                categoria: cat,
                subcategoria: subcategoria,
                persona: esIngreso ? nombre : beneficiario,
                folio: folio ?? String(folioSeq ?? 0),
                folioSeq: folioSeq,
                metodo: metodoPago ?? "Efectivo",
                monto: Int(((monto ?? 0) * 100).rounded()),
                hora: hf.string(from: fechaDate),
                fecha: fechaDate.timeIntervalSince1970,
                registradoPor: registradoPor ?? "",
                miembro: nombre,
                memberUid: memberUid,
                aportanteNombre: aportanteNombre,
                categoriaCompleta: subcategoria.map { "\(cat) · \($0)" } ?? cat,
                nota: concepto,
                sinDepositar: esIngreso,
                comprobante: comprobantePath,
                pagadoA: beneficiario,
                rfc: beneficiarioRfc,
                notasAuditoria: notas,
                estadoRevision: estado ?? "aprobado",
                incluidoEnCorte: false,
                darConstanciaAnual: (emitirConstancia ?? 0) != 0,
                repiteMensual: false,
                actualizadoEn: updatedAt,
                folioProvisional: false,
                borrado: deleted ?? false
            )
        }
    }
}

private extension MovimientoFila {
    /// El folio provisional se enseña con "P-" delante, pero eso es adorno de
    /// pantalla: lo que se manda al servidor no lo lleva.
    var movimientoSinPrefijo: Movimiento {
        var m = movimiento
        m.folio = folio
        return m
    }

    init(id: String, tipo: String, categoria: String, subcategoria: String?,
         persona: String?, folio: String, folioSeq: Int?, metodo: String, monto: Int,
         hora: String, fecha: Double, registradoPor: String, miembro: String?,
         memberUid: String?, aportanteNombre: String?, categoriaCompleta: String,
         nota: String?, sinDepositar: Bool, comprobante: String?, pagadoA: String?,
         rfc: String?, notasAuditoria: String?, estadoRevision: String,
         incluidoEnCorte: Bool, darConstanciaAnual: Bool, repiteMensual: Bool,
         actualizadoEn: String?, folioProvisional: Bool, borrado: Bool) {
        self.id = id; self.tipo = tipo; self.categoria = categoria
        self.subcategoria = subcategoria; self.persona = persona; self.folio = folio
        self.folioSeq = folioSeq; self.metodo = metodo; self.monto = monto
        self.hora = hora; self.fecha = fecha; self.registradoPor = registradoPor
        self.miembro = miembro; self.memberUid = memberUid
        self.aportanteNombre = aportanteNombre; self.categoriaCompleta = categoriaCompleta
        self.nota = nota; self.sinDepositar = sinDepositar; self.comprobante = comprobante
        self.pagadoA = pagadoA; self.rfc = rfc; self.notasAuditoria = notasAuditoria
        self.estadoRevision = estadoRevision; self.incluidoEnCorte = incluidoEnCorte
        self.darConstanciaAnual = darConstanciaAnual; self.repiteMensual = repiteMensual
        self.actualizadoEn = actualizadoEn; self.folioProvisional = folioProvisional
        self.borrado = borrado
    }
}
