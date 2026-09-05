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

    // MARK: - Lo que se enseña

    /// El estado del motor en una frase, para las dos pantallas de Ajustes.
    ///
    /// Vivía suelto dentro de la vista del iPhone, así que el iPad no lo tenía
    /// y se inventaba el suyo: un `@State` que decía "Sincronizado" siempre y
    /// un contador que subía de tres en tres al pulsar. Quien lo enseña no
    /// puede ser quien decide qué dice.
    var estadoLegible: String {
        // Sin sesión, `sincronizar()` se da la vuelta en la primera línea. Si
        // no se dice, la pantalla queda en "Sin sincronizar todavía" y el
        // botón parece roto: no lo está, es que no hay a dónde subir.
        guard !ModoRevision.sinLogin else {
            return L.t("Sin sesión", "Not signed in")
        }
        switch estado {
        case .sincronizando: return L.t("Sincronizando…", "Syncing…")
        case .fallo(let detalle): return detalle
        case .reposo:
            guard let fecha = ultimaSincronizacion else {
                return L.t("Sin sincronizar todavía", "Not synced yet")
            }
            let f = DateFormatter()
            f.locale = L.locale
            f.dateStyle = .short
            f.timeStyle = .short
            return f.string(from: fecha)
        }
    }

    /// Los cambios que esperan turno, en la frase que se lee en pantalla.
    /// La última vuelta no terminó. Es para el punto de color de Ajustes: un
    /// punto verde fijo junto a "Sincronizado" era lo que había antes, y decía
    /// lo mismo con la sincronización rota.
    var haFallado: Bool {
        if case .fallo = estado { return true }
        return false
    }

    /// Si tiene sentido ofrecer el botón de sincronizar a mano.
    var puedeSincronizar: Bool { !ModoRevision.sinLogin && estado != .sincronizando }

    var pendientesLegible: String {
        pendientes == 1
            ? L.t("1 cambio", "1 change")
            : L.t("\(pendientes) cambios", "\(pendientes) changes")
    }

    // MARK: - API

    @MainActor
    func sincronizar() async {
        guard estado != .sincronizando, !ModoRevision.sinLogin else { return }
        estado = .sincronizando
        do {
            try await subirPendientes()
            try await bajarCambios()
            try await bajarAportantes()
            // Los parentescos DESPUÉS de las personas: cada fila apunta a dos
            // fichas por uid, y una relación cuyo otro extremo no ha bajado
            // se salta entera hasta la vuelta siguiente.
            try await bajarParentescos()
            // La asistencia DESPUÉS de los cultos: cada marca apunta a uno por
            // id, y una lista cuyo culto no ha bajado no se puede colocar.
            try await bajarCultos()
            // Las tres hijas del culto, después de él y por la misma razón que
            // los parentescos van después de las personas.
            try await bajarAsistencia()
            try await bajarPuestos()
            try await bajarOrden()
            try await bajarIglesia()
            // Los cortes DESPUÉS de los movimientos: el corte apunta a
            // movimientos por id, y resolver un puntero a algo que todavía no
            // ha bajado deja el corte vacío hasta la vuelta siguiente.
            try await bajarCortes()
            try await bajarCorteMovimientos()
            try await bajarDepositos()
            try await bajarCategorias()
            // Las definiciones recurrentes, ANTES de que la app las
            // materialice: si otro aparato creó la renta, este tiene que
            // conocerla para no volver a registrarla por su cuenta.
            try await bajarRecurrentes()
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
        if op.entidad == "miembro" {
            try await subirMiembro(op)
            return
        }
        if op.entidad == "parentesco" {
            try await subirParentesco(op)
            return
        }
        if op.entidad == "culto" {
            try await subirCulto(op)
            return
        }
        if op.entidad == "asistencia" {
            try await subirAsistencia(op)
            return
        }
        if op.entidad == "puesto" {
            try await subirPuesto(op)
            return
        }
        if op.entidad == "orden" {
            try await subirOrden(op)
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
        if op.entidad == "categoriaCustom" {
            try await subirCategoria(op)
            return
        }
        if op.entidad == "movimientoRecurrente" {
            try await subirRecurrente(op)
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
        /// **La bandera de la baja**, como entero 0/1 porque así está
        /// declarada en `members`. Sin ella, una baja hecha desde el teléfono
        /// dejaba a la persona contada como activa en el app web.
        let activo: Int
        let fechaBaja: String?
        let motivoBaja: String?
        let frecuenciaAporte: String
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, nombre, telefono, email, rfc, direccion, deleted, activo
            case churchId          = "church_id"
            case estadoCivil       = "estado_civil"
            case fechaNacimiento   = "fecha_nacimiento"
            case fechaIngreso      = "fecha_ingreso"
            case fechaCongregacion = "fecha_congregacion"
            case estadoMembresia   = "estado_membresia"
            case fechaBaja         = "fecha_baja"
            case motivoBaja        = "motivo_baja"
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
            activo: fila.activo ? 1 : 0,
            // Nulos y no vacíos, que es lo que el web deja al restaurar.
            fechaBaja: fila.activo ? nil : fila.fechaBaja,
            motivoBaja: fila.activo ? nil : fila.motivoBaja,
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

    // MARK: - La asistencia

    /// Lo que el aparato escribe en `servicios`. **`asistentes` y `ausentes`
    /// van vacías a propósito**: el web las marca como legado y las escribe
    /// así; el roster de verdad son las filas de `servicio_asistencia`.
    private struct CultoEscritura: Encodable {
        let uid, churchId, fecha, tipo: String
        let dirige, predica, tituloMensaje, textoBiblico, resumenMensaje: String?
        let participaciones, temaEscuela, maestroEscuela: String?
        let asistentes, ausentes, visitantes: String
        let ninos, jovenes, adultos: Int
        let eventos: String?
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, fecha, tipo, dirige, predica, participaciones, visitantes
            case ninos, jovenes, adultos, eventos, deleted, asistentes, ausentes
            case churchId       = "church_id"
            case tituloMensaje  = "titulo_mensaje"
            case textoBiblico   = "texto_biblico"
            case resumenMensaje = "resumen_mensaje"
            case temaEscuela    = "tema_escuela"
            case maestroEscuela = "maestro_escuela"
        }

        init(_ f: ServicioFila, churchId: String, deleted: Bool) {
            func o(_ s: String) -> String? { s.isEmpty ? nil : s }
            uid = f.id; self.churchId = churchId; fecha = f.fecha; tipo = f.tipo
            dirige = o(f.dirige); predica = o(f.predica)
            tituloMensaje = o(f.tituloMensaje); textoBiblico = o(f.textoBiblico)
            resumenMensaje = o(f.resumenMensaje); participaciones = f.participaciones
            temaEscuela = o(f.temaEscuela); maestroEscuela = o(f.maestroEscuela)
            asistentes = "[]"; ausentes = "[]"; visitantes = f.visitantes
            ninos = f.ninos; jovenes = f.jovenes; adultos = f.adultos
            eventos = o(f.eventos)
            self.deleted = deleted
        }
    }

    private func subirCulto(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try ServicioFila.fetchOne(db, key: op.registroId)
        }) else { return }
        let cuerpo = CultoEscritura(fila, churchId: churchIdActivo,
                                    deleted: fila.borrado || op.operacion == OperacionPendiente.Operacion.eliminar.rawValue)
        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            try await supabase.from("servicios").insert(cuerpo).execute()
        case .actualizar, .eliminar:
            try await supabase.from("servicios").update(cuerpo)
                .eq("uid", value: fila.id).eq("church_id", value: churchIdActivo).execute()
        case .none:
            return
        }
    }

    private struct AsistenciaEscritura: Encodable {
        let uid, churchId, servicioUid, memberUid: String
        let presente: Int
        let razon, razonOtra: String?
        let seguimiento: Int
        let nombreSnapshot: String
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, presente, razon, seguimiento, deleted
            case churchId       = "church_id"
            case servicioUid    = "servicio_uid"
            case memberUid      = "member_uid"
            case razonOtra      = "razon_otra"
            case nombreSnapshot = "nombre_snapshot"
        }

        init(_ f: AsistenciaFila, churchId: String, deleted: Bool) {
            func o(_ s: String) -> String? { s.isEmpty ? nil : s }
            uid = f.id; self.churchId = churchId
            servicioUid = f.servicioId; memberUid = f.miembroId
            presente = f.presente ? 1 : 0
            razon = o(f.razon); razonOtra = o(f.razonOtra)
            seguimiento = f.seguimiento ? 1 : 0
            nombreSnapshot = f.nombreSnapshot
            self.deleted = deleted
        }
    }

    private func subirAsistencia(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try AsistenciaFila.fetchOne(db, key: op.registroId)
        }) else { return }
        let cuerpo = AsistenciaEscritura(fila, churchId: churchIdActivo,
                                         deleted: fila.borrado || op.operacion == OperacionPendiente.Operacion.eliminar.rawValue)
        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            try await supabase.from("servicio_asistencia").insert(cuerpo).execute()
        case .actualizar, .eliminar:
            try await supabase.from("servicio_asistencia").update(cuerpo)
                .eq("uid", value: fila.id).eq("church_id", value: churchIdActivo).execute()
        case .none:
            return
        }
    }

    private struct PuestoEscritura: Encodable {
        let uid, churchId, servicioUid, puesto, nombre: String
        let memberUid: String?
        let deleted: Bool
        enum CodingKeys: String, CodingKey {
            case uid, puesto, nombre, deleted
            case churchId    = "church_id"
            case servicioUid = "servicio_uid"
            case memberUid   = "member_uid"
        }
    }

    private func subirPuesto(_ op: OperacionPendiente) async throws {
        guard let f = try await cola.read({ db in
            try ServicioPuestoFila.fetchOne(db, key: op.registroId)
        }) else { return }
        let cuerpo = PuestoEscritura(
            uid: f.id, churchId: churchIdActivo, servicioUid: f.servicioId,
            puesto: f.puesto, nombre: f.nombre, memberUid: f.miembroId,
            deleted: f.borrado || op.operacion == OperacionPendiente.Operacion.eliminar.rawValue)
        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            try await supabase.from("servicio_puestos").insert(cuerpo).execute()
        case .actualizar, .eliminar:
            try await supabase.from("servicio_puestos").update(cuerpo)
                .eq("uid", value: f.id).eq("church_id", value: churchIdActivo).execute()
        case .none: return
        }
    }

    private struct OrdenEscritura: Encodable {
        let uid, churchId, servicioUid, hora, titulo, encargado: String
        let posicion: Int
        let deleted: Bool
        enum CodingKeys: String, CodingKey {
            case uid, posicion, hora, titulo, encargado, deleted
            case churchId    = "church_id"
            case servicioUid = "servicio_uid"
        }
    }

    private func subirOrden(_ op: OperacionPendiente) async throws {
        guard let f = try await cola.read({ db in
            try ServicioOrdenFila.fetchOne(db, key: op.registroId)
        }) else { return }
        let cuerpo = OrdenEscritura(
            uid: f.id, churchId: churchIdActivo, servicioUid: f.servicioId,
            hora: f.hora, titulo: f.titulo, encargado: f.encargado, posicion: f.posicion,
            deleted: f.borrado || op.operacion == OperacionPendiente.Operacion.eliminar.rawValue)
        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            try await supabase.from("servicio_orden").insert(cuerpo).execute()
        case .actualizar, .eliminar:
            try await supabase.from("servicio_orden").update(cuerpo)
                .eq("uid", value: f.id).eq("church_id", value: churchIdActivo).execute()
        case .none: return
        }
    }

    private func bajarPuestos() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let servicioUid, puesto, nombre, memberUid: String?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, puesto, nombre, deleted
                case servicioUid = "servicio_uid"
                case memberUid   = "member_uid"
                case updatedAt   = "updated_at"
            }
        }
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'puesto'")
        }
        var consulta = supabase.from("servicio_puestos").select().eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [FilaRemota] = try await consulta
            .order("updated_at", ascending: true).limit(1000).execute().value
        guard !filas.isEmpty else { return }
        try await cola.write { db in
            for r in filas {
                guard let s = r.servicioUid, !s.isEmpty else { continue }
                let pendiente = try OperacionPendiente
                    .filter(Column("entidad") == "puesto" && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }
                try ServicioPuestoFila(id: r.uid, servicioId: s, puesto: r.puesto ?? "",
                                       nombre: r.nombre ?? "", miembroId: r.memberUid,
                                       actualizadoEn: r.updatedAt,
                                       borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('puesto', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    private func bajarOrden() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let servicioUid, hora, titulo, encargado: String?
            let posicion: Int?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, posicion, hora, titulo, encargado, deleted
                case servicioUid = "servicio_uid"
                case updatedAt   = "updated_at"
            }
        }
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'orden'")
        }
        var consulta = supabase.from("servicio_orden").select().eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [FilaRemota] = try await consulta
            .order("updated_at", ascending: true).limit(1000).execute().value
        guard !filas.isEmpty else { return }
        try await cola.write { db in
            for r in filas {
                guard let s = r.servicioUid, !s.isEmpty else { continue }
                let pendiente = try OperacionPendiente
                    .filter(Column("entidad") == "orden" && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }
                try ServicioOrdenFila(id: r.uid, servicioId: s, posicion: r.posicion ?? 0,
                                      hora: r.hora ?? "", titulo: r.titulo ?? "",
                                      encargado: r.encargado ?? "", actualizadoEn: r.updatedAt,
                                      borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('orden', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    private func bajarCultos() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let fecha, tipo, dirige, predica: String?
            let tituloMensaje, textoBiblico, resumenMensaje: String?
            let participaciones, temaEscuela, maestroEscuela, visitantes, eventos: String?
            let ninos, jovenes, adultos: Int?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, fecha, tipo, dirige, predica, participaciones, visitantes
                case ninos, jovenes, adultos, eventos, deleted
                case tituloMensaje  = "titulo_mensaje"
                case textoBiblico   = "texto_biblico"
                case resumenMensaje = "resumen_mensaje"
                case temaEscuela    = "tema_escuela"
                case maestroEscuela = "maestro_escuela"
                case updatedAt      = "updated_at"
            }
        }
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'culto'")
        }
        var consulta = supabase.from("servicios").select().eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [FilaRemota] = try await consulta
            .order("updated_at", ascending: true).limit(500).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let pendiente = try OperacionPendiente
                    .filter(Column("entidad") == "culto" && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }
                try ServicioFila(id: r.uid, fecha: r.fecha ?? "", tipo: r.tipo ?? "dominical",
                                 dirige: r.dirige ?? "", predica: r.predica ?? "",
                                 tituloMensaje: r.tituloMensaje ?? "", textoBiblico: r.textoBiblico ?? "",
                                 resumenMensaje: r.resumenMensaje ?? "",
                                 participaciones: r.participaciones ?? "[]",
                                 temaEscuela: r.temaEscuela ?? "", maestroEscuela: r.maestroEscuela ?? "",
                                 visitantes: r.visitantes ?? "[]",
                                 ninos: r.ninos ?? 0, jovenes: r.jovenes ?? 0, adultos: r.adultos ?? 0,
                                 eventos: r.eventos ?? "", actualizadoEn: r.updatedAt,
                                 borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('culto', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    private func bajarAsistencia() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let servicioUid, memberUid, razon, razonOtra, nombreSnapshot: String?
            let presente, seguimiento: Int?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, presente, razon, seguimiento, deleted
                case servicioUid    = "servicio_uid"
                case memberUid      = "member_uid"
                case razonOtra      = "razon_otra"
                case nombreSnapshot = "nombre_snapshot"
                case updatedAt      = "updated_at"
            }
        }
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'asistencia'")
        }
        var consulta = supabase.from("servicio_asistencia").select().eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [FilaRemota] = try await consulta
            .order("updated_at", ascending: true).limit(1000).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                // Una marca sin culto o sin persona no se puede colocar.
                guard let s = r.servicioUid, let m = r.memberUid, !s.isEmpty, !m.isEmpty else { continue }
                let pendiente = try OperacionPendiente
                    .filter(Column("entidad") == "asistencia" && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }
                try AsistenciaFila(id: r.uid, servicioId: s, miembroId: m,
                                   presente: (r.presente ?? 0) != 0,
                                   razon: r.razon ?? "", razonOtra: r.razonOtra ?? "",
                                   seguimiento: (r.seguimiento ?? 0) != 0,
                                   nombreSnapshot: r.nombreSnapshot ?? "",
                                   actualizadoEn: r.updatedAt,
                                   borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('asistencia', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    // MARK: - El padrón: la otra cara de la misma fila

    /// Lo que el padrón escribe en `members`: todo lo que `MiembroFila` lleva,
    /// y nada de `frecuencia_aporte`, que es de Tesorería y va en
    /// `AportanteEscritura`. Si las dos entidades tienen algo pendiente sobre
    /// la misma persona, cada una manda sus columnas y las compartidas salen
    /// iguales, porque las dos las leen de la misma fila local.
    ///
    /// Los booleanos van como 0/1: así están declarados allí.
    private struct MiembroEscritura: Encodable {
        let uid: String
        let churchId: String
        let nombre: String
        let telefono, email, rfc, direccion, estadoCivil, fechaNacimiento: String?
        let fechaIngreso, fechaCongregacion: String?
        let estadoMembresia: String
        let activo: Int
        let fechaBaja, motivoBaja: String?
        let iglesiaAnterior: String?
        let bautizadoAgua: Int
        let fechaBautismoAgua: String?
        let bautizadoEspiritu: Int
        let fechaBautismoEspiritu: String?
        let cursoMembresia: Int
        let ministerios, ministeriosInteres, cargos, instrumentos, habilidades, etiquetas: String
        let disponibilidad: String?
        let interesServir: Int
        let notas: String?
        let historialEstados, seguimientoNotas: String
        let seguimientoRevisadoEn: String?
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, nombre, telefono, email, rfc, direccion, deleted, activo
            case ministerios, cargos, instrumentos, habilidades, etiquetas, disponibilidad, notas
            case churchId              = "church_id"
            case estadoCivil           = "estado_civil"
            case fechaNacimiento       = "fecha_nacimiento"
            case fechaIngreso          = "fecha_ingreso"
            case fechaCongregacion     = "fecha_congregacion"
            case estadoMembresia       = "estado_membresia"
            case fechaBaja             = "fecha_baja"
            case motivoBaja            = "motivo_baja"
            case iglesiaAnterior       = "iglesia_anterior"
            case bautizadoAgua         = "bautizado_agua"
            case fechaBautismoAgua     = "fecha_bautismo_agua"
            case bautizadoEspiritu     = "bautizado_espiritu"
            case fechaBautismoEspiritu = "fecha_bautismo_espiritu"
            case cursoMembresia        = "curso_membresia"
            case ministeriosInteres    = "ministerios_interes"
            case interesServir         = "interes_servir"
            case historialEstados      = "historial_estados"
            case seguimientoNotas      = "seguimiento_notas"
            case seguimientoRevisadoEn = "seguimiento_revisado_en"
        }

        init(_ f: MiembroFila, churchId: String, deleted: Bool) {
            func o(_ s: String) -> String? { s.isEmpty ? nil : s }
            uid = f.id; self.churchId = churchId; nombre = f.nombre
            telefono = o(f.telefono); email = o(f.correo); rfc = o(f.idFiscal)
            direccion = o(f.direccion); estadoCivil = o(f.estadoCivil); fechaNacimiento = o(f.nacimiento)
            fechaIngreso = o(f.miembroDesde); fechaCongregacion = o(f.congregaDesde)
            estadoMembresia = f.estado
            activo = f.activo ? 1 : 0
            // Nulos y no vacíos, que es lo que el web deja al restaurar.
            fechaBaja = f.activo ? nil : o(f.fechaBaja)
            motivoBaja = f.activo ? nil : o(f.motivoBaja)
            iglesiaAnterior = o(f.iglesiaAnterior)
            bautizadoAgua = f.bautizadoAgua ? 1 : 0
            fechaBautismoAgua = o(f.fechaBautismoAgua)
            bautizadoEspiritu = f.bautizadoEspiritu ? 1 : 0
            fechaBautismoEspiritu = o(f.fechaBautismoEspiritu)
            cursoMembresia = f.cursoMembresia ? 1 : 0
            ministerios = f.ministerios; ministeriosInteres = f.ministeriosInteres
            cargos = f.cargos; instrumentos = f.instrumentos; habilidades = f.habilidades
            etiquetas = f.etiquetas
            disponibilidad = o(f.disponibilidad)
            interesServir = f.interesServir ? 1 : 0
            notas = o(f.notas)
            historialEstados = f.historialEstados; seguimientoNotas = f.seguimientoNotas
            seguimientoRevisadoEn = o(f.seguimientoRevisadoEn)
            self.deleted = deleted
        }
    }

    private func subirMiembro(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try MiembroFila.fetchOne(db, key: op.registroId)
        }) else { return }
        let cuerpo = MiembroEscritura(fila, churchId: churchIdActivo,
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

    private struct ParentescoEscritura: Encodable {
        let uid: String
        let churchId: String
        let memberUid: String
        let parienteUid: String
        let tipo: String
        let deleted: Bool
        enum CodingKeys: String, CodingKey {
            case uid, tipo, deleted
            case churchId    = "church_id"
            case memberUid   = "member_uid"
            case parienteUid = "pariente_uid"
        }
    }

    private func subirParentesco(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try ParentescoFila.fetchOne(db, key: op.registroId)
        }) else { return }
        let cuerpo = ParentescoEscritura(
            uid: fila.id, churchId: churchIdActivo, memberUid: fila.miembroId,
            parienteUid: fila.parienteId, tipo: fila.tipo,
            deleted: fila.borrado || op.operacion == OperacionPendiente.Operacion.eliminar.rawValue)
        switch OperacionPendiente.Operacion(rawValue: op.operacion) {
        case .crear:
            try await supabase.from("parentescos").insert(cuerpo).execute()
        case .actualizar, .eliminar:
            try await supabase.from("parentescos").update(cuerpo)
                .eq("uid", value: fila.id)
                .eq("church_id", value: churchIdActivo)
                .execute()
        case .none:
            return
        }
    }

    private func bajarParentescos() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let memberUid, parienteUid, tipo: String?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, tipo, deleted
                case memberUid   = "member_uid"
                case parienteUid = "pariente_uid"
                case updatedAt   = "updated_at"
            }
        }
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'parentesco'")
        }
        var consulta = supabase.from("parentescos").select()
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
                // Media relación no es una relación: sin los dos extremos no
                // hay fila que guardar.
                guard let m = r.memberUid, let p = r.parienteUid, !m.isEmpty, !p.isEmpty else { continue }
                let pendiente = try OperacionPendiente
                    .filter(Column("entidad") == "parentesco" && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }
                try ParentescoFila(id: r.uid, miembroId: m, parienteId: p, tipo: r.tipo ?? "otro",
                                   actualizadoEn: r.updatedAt, borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('parentesco', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    private func bajarAportantes() async throws {
        struct FilaRemota: Decodable {
            let uid: String
            let nombre: String?
            let telefono, email, rfc, direccion: String?
            let estadoCivil, fechaNacimiento, fechaIngreso, fechaCongregacion: String?
            let estadoMembresia, frecuenciaAporte: String?
            let activo: Int?
            let fechaBaja, motivoBaja: String?
            // El padrón (v15). Todo lo que el web guarda en la misma fila.
            let iglesiaAnterior, fechaBautismoAgua, fechaBautismoEspiritu: String?
            let bautizadoAgua, bautizadoEspiritu, cursoMembresia, interesServir: Int?
            let ministerios, ministeriosInteres, cargos, instrumentos, habilidades, etiquetas: String?
            let disponibilidad, notas, historialEstados, seguimientoNotas, seguimientoRevisadoEn: String?
            let updatedAt: String?
            let deleted: Bool?
            enum CodingKeys: String, CodingKey {
                case uid, nombre, telefono, email, rfc, direccion, deleted, activo
                case ministerios, cargos, instrumentos, habilidades, etiquetas, disponibilidad, notas
                case fechaBaja         = "fecha_baja"
                case motivoBaja        = "motivo_baja"
                case iglesiaAnterior       = "iglesia_anterior"
                case bautizadoAgua         = "bautizado_agua"
                case fechaBautismoAgua     = "fecha_bautismo_agua"
                case bautizadoEspiritu     = "bautizado_espiritu"
                case fechaBautismoEspiritu = "fecha_bautismo_espiritu"
                case cursoMembresia        = "curso_membresia"
                case ministeriosInteres    = "ministerios_interes"
                case interesServir         = "interes_servir"
                case historialEstados      = "historial_estados"
                case seguimientoNotas      = "seguimiento_notas"
                case seguimientoRevisadoEn = "seguimiento_revisado_en"
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
                // Dos entidades escriben esta fila —Tesorería y el padrón—,
                // y lo que cualquiera de las dos tenga pendiente de subir no
                // se pisa con lo que baja.
                let pendiente = try OperacionPendiente
                    .filter((Column("entidad") == "aportante" || Column("entidad") == "miembro")
                            && Column("registroId") == r.uid)
                    .fetchCount(db) > 0
                if pendiente { continue }

                var a = Aportante(
                    id: r.uid, nombre: r.nombre ?? "",
                    estado: AportanteFila.estado(registro: r.estadoMembresia ?? "activo",
                                                 activo: (r.activo ?? 1) != 0,
                                                 fechaBaja: r.fechaBaja ?? "",
                                                 motivoBaja: r.motivoBaja ?? ""),
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

                // Y la otra cara de la misma fila: las columnas del padrón.
                // `MiembroFila` no lleva `frecuencia`, así que no toca lo que
                // acaba de escribir la línea de arriba.
                var m = Miembro(id: r.uid, nombre: r.nombre ?? "")
                m.estado = a.estado
                m.telefono = a.telefono; m.correo = a.correo; m.nacimiento = a.nacimiento
                m.direccion = a.direccion; m.estadoCivil = a.estadoCivil; m.idFiscal = a.idFiscal
                m.fechaIngreso = a.miembroDesde; m.fechaCongregacion = a.congregaDesde
                m.iglesiaAnterior = r.iglesiaAnterior ?? ""
                m.bautizadoAgua = (r.bautizadoAgua ?? 0) != 0
                m.fechaBautismoAgua = r.fechaBautismoAgua ?? ""
                m.bautizadoEspiritu = (r.bautizadoEspiritu ?? 0) != 0
                m.fechaBautismoEspiritu = r.fechaBautismoEspiritu ?? ""
                m.cursoMembresia = (r.cursoMembresia ?? 0) != 0
                m.ministerios = Padron.lista(r.ministerios ?? "[]")
                m.ministeriosInteres = Padron.lista(r.ministeriosInteres ?? "[]")
                m.cargos = Padron.lista(r.cargos ?? "[]")
                m.instrumentos = Padron.lista(r.instrumentos ?? "[]")
                m.habilidades = Padron.lista(r.habilidades ?? "[]")
                m.etiquetas = Padron.lista(r.etiquetas ?? "[]")
                m.disponibilidad = r.disponibilidad ?? ""
                m.interesServir = (r.interesServir ?? 0) != 0
                m.notas = r.notas ?? ""
                m.historialEstados = MiembroFila.lista(r.historialEstados ?? "[]")
                m.seguimientoNotas = MiembroFila.lista(r.seguimientoNotas ?? "[]")
                m.seguimientoRevisadoEn = r.seguimientoRevisadoEn ?? ""
                try MiembroFila(m, actualizadoEn: r.updatedAt,
                                borrado: r.deleted ?? false).update(db)
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
            let saldoInicial: Int
            let pastorNombre, pastorCargo: String
            let tesoreroNombre, tesoreroCargo: String
            let tesoreroEmail, tesoreroTelefono: String
            let pastorEmail, pastorTelefono: String
            let secretarioNombre, secretarioCargo: String
            let imprimirFirmas: Bool
            enum CodingKeys: String, CodingKey {
                case nombre, direccion, ciudad, estado, pais, telefono, correo, moneda
                case codigoPostal      = "codigo_postal"
                case idFiscal          = "id_fiscal"
                case pieInstitucional  = "pie_institucional"
                case saldoInicial      = "saldo_inicial"
                case pastorNombre      = "pastor_nombre"
                case pastorCargo       = "pastor_cargo"
                case tesoreroNombre    = "tesorero_nombre"
                case tesoreroCargo     = "tesorero_cargo"
                case tesoreroEmail     = "tesorero_email"
                case tesoreroTelefono  = "tesorero_telefono"
                case pastorEmail       = "pastor_email"
                case pastorTelefono    = "pastor_telefono"
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
                saldoInicial: c.saldoInicial,
                pastorNombre: c.pastorNombre, pastorCargo: c.pastorCargo,
                tesoreroNombre: c.tesoreroNombre, tesoreroCargo: c.tesoreroCargo,
                tesoreroEmail: c.tesoreroCorreo, tesoreroTelefono: c.tesoreroTelefono,
                pastorEmail: c.pastorCorreo, pastorTelefono: c.pastorTelefono,
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
            let saldoInicial: Int?
            let pastorNombre, pastorCargo: String?
            let tesoreroNombre, tesoreroCargo: String?
            let tesoreroEmail, tesoreroTelefono: String?
            let pastorEmail, pastorTelefono: String?
            let secretarioNombre, secretarioCargo: String?
            let imprimirFirmas: Bool?
            // Bajan pero no suben: ver `ConfiguracionIglesia`.
            let tesoreroVePadron: Bool?
            let tesoreroPuedeEliminar: Bool?
            let plan: String?
            let subEstado: String?
            let subVence: String?
            enum CodingKeys: String, CodingKey {
                case nombre, direccion, ciudad, estado, pais, telefono, correo, moneda
                case codigoPostal      = "codigo_postal"
                case idFiscal          = "id_fiscal"
                case pieInstitucional  = "pie_institucional"
                case saldoInicial      = "saldo_inicial"
                case pastorNombre      = "pastor_nombre"
                case pastorCargo       = "pastor_cargo"
                case tesoreroNombre    = "tesorero_nombre"
                case tesoreroCargo     = "tesorero_cargo"
                case tesoreroEmail     = "tesorero_email"
                case tesoreroTelefono  = "tesorero_telefono"
                case pastorEmail       = "pastor_email"
                case pastorTelefono    = "pastor_telefono"
                case secretarioNombre  = "secretario_nombre"
                case secretarioCargo   = "secretario_cargo"
                case imprimirFirmas    = "imprimir_firmas"
                case tesoreroVePadron      = "tesorero_ve_padron"
                case tesoreroPuedeEliminar = "tesorero_puede_eliminar"
                case plan
                case subEstado             = "sub_estado"
                case subVence              = "sub_vence"
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
        c.saldoInicial = r.saldoInicial ?? 0
        c.pastorNombre = r.pastorNombre ?? ""
        c.pastorCargo = r.pastorCargo ?? "Pastor"
        c.tesoreroNombre = r.tesoreroNombre ?? ""
        c.tesoreroCargo = r.tesoreroCargo ?? "Tesorero"
        c.tesoreroCorreo = r.tesoreroEmail ?? ""
        c.tesoreroTelefono = r.tesoreroTelefono ?? ""
        c.pastorCorreo = r.pastorEmail ?? ""
        c.pastorTelefono = r.pastorTelefono ?? ""
        c.secretarioNombre = r.secretarioNombre ?? ""
        c.secretarioCargo = r.secretarioCargo ?? "Secretario"
        c.imprimirFirmas = r.imprimirFirmas ?? true
        c.tesoreroVePadron = r.tesoreroVePadron ?? false
        c.tesoreroPuedeEliminar = r.tesoreroPuedeEliminar ?? true
        c.plan = r.plan ?? ""
        c.subEstado = r.subEstado ?? ""
        c.subVence = r.subVence ?? ""

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

    // MARK: - Categorías de la iglesia

    private struct CategoriaRemota: Encodable {
        let uid: String
        let churchId: String
        let tipo: String
        let nombre: String
        let color: String
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, tipo, nombre, color, deleted
            case churchId = "church_id"
        }
    }

    private func subirCategoria(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try CategoriaCustomFila.fetchOne(db, key: op.registroId)
        }) else { return }

        let remoto = CategoriaRemota(uid: fila.id, churchId: churchIdActivo,
                                     tipo: fila.tipo, nombre: fila.nombre,
                                     color: fila.color, deleted: fila.borrado)
        try await supabase.from("categorias_custom")
            .upsert(remoto, onConflict: "uid").execute()
    }

    private struct CategoriaRemotaLeida: Decodable {
        let uid: String
        let tipo: String?
        let nombre: String?
        let color: String?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, tipo, nombre, color, deleted
            case updatedAt = "updated_at"
        }
    }

    private func bajarCategorias() async throws {
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'categoriaCustom'")
        }
        var consulta = supabase.from("categorias_custom").select()
            .eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [CategoriaRemotaLeida] = try await consulta
            .order("updated_at", ascending: true).limit(500).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let tienePendiente = try OperacionPendiente
                    .filter(Column("registroId") == r.uid).fetchCount(db) > 0
                if tienePendiente { continue }
                if r.deleted == true {
                    // Se borra la fila local en vez de marcarla: nada apunta a
                    // una categoría por id —los movimientos guardan su nombre—,
                    // así que una fila muerta aquí no sirve de nada.
                    try CategoriaCustomFila.deleteOne(db, key: r.uid)
                    continue
                }
                try CategoriaCustomFila(
                    CategoriaCustom(id: r.uid,
                                    tipo: r.tipo == "ingreso" ? .ingreso : .gasto,
                                    nombre: r.nombre ?? "",
                                    color: r.color ?? ""),
                    actualizadoEn: r.updatedAt).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('categoriaCustom', ?)
                    on conflict(entidad) do update set cursor = excluded.cursor
                    """, arguments: [ultimo])
            }
        }
    }

    // MARK: - Movimientos recurrentes

    /// La DEFINICIÓN, no los movimientos que genera: esos suben como cualquier
    /// otro movimiento, con su `recurrente_uid` a cuestas.
    ///
    /// Que la definición viaje es lo que permite que la renta se registre sola
    /// en el iPad del pastor aunque se creara en el iPhone del tesorero. Y es
    /// justo lo que no pasaba: `repiteMensual` era una columna local que no
    /// tenía a dónde ir.
    private struct RecurrenteRemoto: Encodable {
        let uid: String
        let churchId: String
        let tipo: String
        let categoria: String
        let subcategoria: String?
        let concepto: String?
        let monto: Double
        let metodoPago: String
        let beneficiario: String?
        let beneficiarioRfc: String?
        let dia: Int
        let mesInicio: String
        let ultimoMesGenerado: String?
        let activo: Bool
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case uid, tipo, categoria, subcategoria, concepto, monto, dia, activo, deleted
            case churchId          = "church_id"
            case metodoPago        = "metodo_pago"
            case beneficiario
            case beneficiarioRfc   = "beneficiario_rfc"
            case mesInicio         = "mes_inicio"
            case ultimoMesGenerado = "ultimo_mes_generado"
        }
    }

    private func subirRecurrente(_ op: OperacionPendiente) async throws {
        guard let fila = try await cola.read({ db in
            try MovimientoRecurrenteFila.fetchOne(db, key: op.registroId)
        }) else { return }

        let remoto = RecurrenteRemoto(
            uid: fila.id, churchId: churchIdActivo, tipo: fila.tipo,
            categoria: fila.categoria, subcategoria: fila.subcategoria,
            concepto: fila.nota,
            // En pesos, como `transactions.monto`: la app guarda centavos.
            monto: Double(fila.monto) / 100.0,
            metodoPago: fila.metodo, beneficiario: fila.pagadoA,
            beneficiarioRfc: fila.rfc, dia: fila.dia,
            mesInicio: fila.mesInicio, ultimoMesGenerado: fila.ultimoMesGenerado,
            activo: fila.activo, deleted: fila.borrado)
        try await supabase.from("movimientos_recurrentes")
            .upsert(remoto, onConflict: "uid").execute()
    }

    private struct RecurrenteRemotoLeido: Decodable {
        let uid: String
        let tipo: String?
        let categoria: String?
        let subcategoria: String?
        let concepto: String?
        let monto: Double?
        let metodoPago: String?
        let beneficiario: String?
        let beneficiarioRfc: String?
        let dia: Int?
        let mesInicio: String?
        let ultimoMesGenerado: String?
        let activo: Bool?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, tipo, categoria, subcategoria, concepto, monto, dia, activo, deleted
            case metodoPago        = "metodo_pago"
            case beneficiario
            case beneficiarioRfc   = "beneficiario_rfc"
            case mesInicio         = "mes_inicio"
            case ultimoMesGenerado = "ultimo_mes_generado"
            case updatedAt         = "updated_at"
        }
    }

    private func bajarRecurrentes() async throws {
        let cursor = try await cola.read { db in
            try String.fetchOne(db, sql: "select cursor from syncEstado where entidad = 'movimientoRecurrente'")
        }
        var consulta = supabase.from("movimientos_recurrentes").select()
            .eq("church_id", value: churchIdActivo)
        if let cursor { consulta = consulta.gt("updated_at", value: cursor) }
        let filas: [RecurrenteRemotoLeido] = try await consulta
            .order("updated_at", ascending: true).limit(500).execute().value
        guard !filas.isEmpty else { return }

        try await cola.write { db in
            for r in filas {
                let tienePendiente = try OperacionPendiente
                    .filter(Column("registroId") == r.uid).fetchCount(db) > 0
                if tienePendiente { continue }
                // Borrado LÓGICO, al revés que las categorías: aquí sí hay
                // quien apunte a la definición por id —los movimientos que
                // generó— y borrar la fila dejaría ese vínculo colgando.
                guard let mesInicio = r.mesInicio else { continue }
                let def = MovimientoRecurrente(
                    id: r.uid,
                    tipo: r.tipo == "ingreso" ? .ingreso : .gasto,
                    categoria: r.categoria ?? "",
                    subcategoria: r.subcategoria,
                    nota: r.concepto,
                    monto: Int(((r.monto ?? 0) * 100).rounded()),
                    metodo: r.metodoPago ?? "Efectivo",
                    pagadoA: r.beneficiario,
                    rfc: r.beneficiarioRfc,
                    dia: r.dia ?? 1,
                    mesInicio: mesInicio,
                    ultimoMesGenerado: r.ultimoMesGenerado,
                    activo: r.activo ?? true)
                try MovimientoRecurrenteFila(def, actualizadoEn: r.updatedAt,
                                             borrado: r.deleted ?? false).save(db)
            }
            if let ultimo = filas.last?.updatedAt {
                try db.execute(sql: """
                    insert into syncEstado (entidad, cursor) values ('movimientoRecurrente', ?)
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
        let recurrenteUid: String?
        let updatedAt: String?
        let deleted: Bool?

        enum CodingKeys: String, CodingKey {
            case uid, tipo, categoria, subcategoria, concepto, fecha, monto
            case notas, estado, folio, deleted, beneficiario
            case recurrenteUid     = "recurrente_uid"
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
                // Igual que en el repositorio remoto: se deriva del vínculo con
                // la serie. En `false` fijo, cada bajada borraba la marca de
                // recurrente de un movimiento que sí lo era.
                repiteMensual: recurrenteUid != nil,
                recurrenteId: recurrenteUid,
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
         recurrenteId: String? = nil,
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
        self.recurrenteId = recurrenteId
        self.actualizadoEn = actualizadoEn; self.folioProvisional = folioProvisional
        self.borrado = borrado
    }
}
