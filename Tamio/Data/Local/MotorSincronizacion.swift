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
            try await bajarIglesia()
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
        c.moneda = r.moneda ?? "MXN"
        c.pieInstitucional = r.pieInstitucional ?? ""
        c.pastorNombre = r.pastorNombre ?? ""
        c.pastorCargo = r.pastorCargo ?? "Pastor"
        c.tesoreroNombre = r.tesoreroNombre ?? ""
        c.tesoreroCargo = r.tesoreroCargo ?? "Tesorero"
        c.secretarioNombre = r.secretarioNombre ?? ""
        c.secretarioCargo = r.secretarioCargo ?? "Secretario"
        c.imprimirFirmas = r.imprimirFirmas ?? true

        try await cola.write { db in
            try IglesiaFila(id: churchIdActivo, c).save(db)
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
                marcadoPendiente: estado == "pendiente",
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
         rfc: String?, notasAuditoria: String?, marcadoPendiente: Bool,
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
        self.marcadoPendiente = marcadoPendiente; self.incluidoEnCorte = incluidoEnCorte
        self.darConstanciaAnual = darConstanciaAnual; self.repiteMensual = repiteMensual
        self.actualizadoEn = actualizadoEn; self.folioProvisional = folioProvisional
        self.borrado = borrado
    }
}
