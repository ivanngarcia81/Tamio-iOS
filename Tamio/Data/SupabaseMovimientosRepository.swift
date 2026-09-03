import Foundation
import Supabase

/// Implementación real de `MovimientosRepository` conectada a la tabla
/// `transactions` de Supabase. Usa soft-delete (`deleted = true`).
struct SupabaseMovimientosRepository: MovimientosRepository {

    // MARK: - DTO de lectura

    private struct TransaccionDTO: Decodable {
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
        let estado: String?
        let notas: String?
        let registradoPor: String?
        let folio: String?
        let folioSeq: Int?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case uid
            case memberUid        = "member_uid"
            case tipo, categoria, subcategoria, concepto, fecha, monto, estado, notas, folio
            case metodoPago       = "metodo_pago"
            case beneficiario
            case beneficiarioRfc  = "beneficiario_rfc"
            case comprobantePath  = "comprobante_path"
            case aportanteNombre  = "aportante_nombre"
            case emitirConstancia = "emitir_constancia"
            case registradoPor    = "registrado_por"
            case folioSeq         = "folio_seq"
            case createdAt        = "created_at"
        }
    }

    // MARK: - DTO de escritura

    private struct TransaccionInsert: Encodable {
        let uid: String
        let churchId: String
        let memberUid: String?
        let tipo: String
        let categoria: String
        let subcategoria: String?
        let comprobantePath: String?
        let aportanteNombre: String?
        let concepto: String?
        let fecha: String
        let monto: Double
        let metodoPago: String
        let beneficiario: String?
        let beneficiarioRfc: String?
        let emitirConstancia: Int
        let estado: String
        let notas: String?
        let registradoPor: String
        let folio: String
        let folioSeq: Int?

        enum CodingKeys: String, CodingKey {
            case uid
            case churchId         = "church_id"
            case memberUid        = "member_uid"
            case tipo, categoria, subcategoria, concepto, fecha, monto, estado, notas, folio
            case comprobantePath  = "comprobante_path"
            case aportanteNombre  = "aportante_nombre"
            case metodoPago       = "metodo_pago"
            case beneficiario
            case beneficiarioRfc  = "beneficiario_rfc"
            case emitirConstancia = "emitir_constancia"
            case registradoPor    = "registrado_por"
            case folioSeq         = "folio_seq"
        }
    }

    // MARK: - MovimientosRepository

    func lista(tipo: TipoMovimiento) async throws -> [Movimiento] {
        let tipoStr = tipo == .ingreso ? "ingreso" : "gasto"
        let rows: [TransaccionDTO] = try await supabase
            .from("transactions")
            .select()
            .eq("church_id", value: churchIdActivo)
            .eq("tipo", value: tipoStr)
            .eq("deleted", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value

        let nombres = await memberNames(for: rows.compactMap { $0.memberUid })
        return rows.compactMap { mapear($0, nombres: nombres) }
    }

    func crear(_ m: Movimiento) async throws {
        var nuevo = m
        if nuevo.id.isEmpty { nuevo.id = UUID().uuidString }
        // El folio definitivo se pide aquí, no al abrir la hoja: el RPC lo
        // entrega y lo reserva en un solo statement, así que dos capturas
        // simultáneas no pueden recibir el mismo número. El que traiga el
        // movimiento desde la UI era solo la vista previa.
        let seq = try await consumirFolio(tipo: nuevo.tipo)
        try await supabase
            .from("transactions")
            .insert(toInsert(nuevo, folioSeq: seq))
            .execute()
    }

    func actualizar(_ m: Movimiento) async throws {
        try await supabase
            .from("transactions")
            .update(toInsert(m))
            .eq("uid", value: m.id)
            .eq("church_id", value: churchIdActivo)
            .execute()
    }

    func eliminar(id: String) async throws {
        struct SoftDelete: Encodable { let deleted: Bool }
        try await supabase
            .from("transactions")
            .update(SoftDelete(deleted: true))
            .eq("uid", value: id)
            .eq("church_id", value: churchIdActivo)
            .execute()
    }

    /// Vista previa del folio. Antes esto era `max(folio_seq) + 1` leído por el
    /// cliente y luego escrito al guardar: además de reutilizar los folios de
    /// los movimientos borrados y de mezclar ingresos con gastos, dejaba una
    /// ventana entre la lectura y la escritura en la que otra captura se
    /// llevaba el mismo número. Ahora el contador vive en Postgres.
    func siguienteFolio(tipo: TipoMovimiento) async -> String {
        let previsto: Int? = try? await supabase
            .rpc("folio_previsto", params: ParamsFolio(churchId: churchIdActivo,
                                                       serie: serie(tipo)))
            .execute()
            .value
        // Sin red no hay folio que enseñar. Se deja vacío en vez de inventar un
        // número: el definitivo lo pone el servidor al guardar.
        return previsto.map(String.init) ?? ""
    }

    private struct ParamsFolio: Encodable {
        let churchId: String
        let serie: String
        enum CodingKeys: String, CodingKey {
            case churchId = "p_church_id"
            case serie    = "p_serie"
        }
    }

    private func serie(_ t: TipoMovimiento) -> String {
        t == .ingreso ? "ingreso" : "gasto"
    }

    /// Reserva el siguiente folio de la serie. Lanza si no se puede: guardar un
    /// movimiento sin folio fiable es peor que no guardarlo.
    private func consumirFolio(tipo: TipoMovimiento) async throws -> Int {
        try await supabase
            .rpc("siguiente_folio", params: ParamsFolio(churchId: churchIdActivo,
                                                        serie: serie(tipo)))
            .execute()
            .value
    }

    // MARK: - Helpers privados

    private func memberNames(for uids: [String]) async -> [String: String] {
        guard !uids.isEmpty else { return [:] }
        struct NameDTO: Decodable { let uid: String; let nombre: String? }
        let rows: [NameDTO] = (try? await supabase
            .from("members")
            .select("uid,nombre")
            .in("uid", values: uids)
            .execute()
            .value) ?? []
        return Dictionary(rows.map { ($0.uid, $0.nombre ?? $0.uid) },
                          uniquingKeysWith: { first, _ in first })
    }

    private func mapear(_ dto: TransaccionDTO, nombres: [String: String]) -> Movimiento? {
        guard let tipoStr = dto.tipo else { return nil }
        let tipo: TipoMovimiento = tipoStr == "ingreso" ? .ingreso : .gasto
        let monto = Int(((dto.monto ?? 0) * 100).rounded())
        let fecha = parseDate(dto.fecha)
        let hora = parseHora(dto.fecha ?? dto.createdAt)
        // Un ingreso puede venir de una ficha del padrón o de alguien sin ficha.
        let nombreMiembro = dto.memberUid.flatMap { nombres[$0] }
        let nombreAportante = nombreMiembro ?? dto.aportanteNombre
        let persona: String? = tipo == .ingreso ? nombreAportante : dto.beneficiario
        let cat = dto.categoria ?? ""
        let catCompleta = dto.subcategoria.map { "\(cat) · \($0)" } ?? cat

        return Movimiento(
            id: dto.uid,
            tipo: tipo,
            categoria: cat,
            persona: persona,
            folio: dto.folio ?? dto.uid,
            metodo: dto.metodoPago ?? "Efectivo",
            monto: monto,
            hora: hora,
            fecha: fecha,
            registradoPor: dto.registradoPor ?? "",
            miembro: nombreAportante,
            categoriaCompleta: catCompleta,
            nota: dto.concepto,
            // sinDepositar e incluidoEnCorte requieren join con corte_movimientos (pendiente)
            sinDepositar: tipo == .ingreso,
            comprobante: dto.comprobantePath,
            auditoria: [],
            pagadoA: dto.beneficiario,
            rfc: dto.beneficiarioRfc,
            notasAuditoria: dto.notas,
            marcadoPendiente: dto.estado == "pendiente",
            incluidoEnCorte: false,
            darConstanciaAnual: (dto.emitirConstancia ?? 0) != 0,
            repiteMensual: false,
            memberUid: dto.memberUid,
            subcategoria: dto.subcategoria,
            aportanteNombre: dto.aportanteNombre
        )
    }

    /// `folioSeq` no nulo solo al crear: es el número que acaba de reservar el
    /// servidor. Al actualizar se omite, para que una edición nunca renumere un
    /// movimiento ya emitido.
    private func toInsert(_ m: Movimiento, folioSeq: Int? = nil) -> TransaccionInsert {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]
        return TransaccionInsert(
            uid: m.id.isEmpty ? UUID().uuidString : m.id,
            churchId: churchIdActivo,
            // El vínculo con el miembro y el desglose de categoría viajan en el
            // propio movimiento. Antes iban a `nil` fijo, y como `actualizar`
            // reusa este DTO, cualquier edición borraba en Supabase el
            // `member_uid`, la subcategoría y el comprobante de la fila.
            // (Sigue pendiente resolver el member por nombre al crear.)
            memberUid: m.memberUid,
            tipo: m.tipo == .ingreso ? "ingreso" : "gasto",
            categoria: m.categoria,
            subcategoria: m.subcategoria,
            comprobantePath: m.comprobante,
            aportanteNombre: m.aportanteNombre,
            concepto: m.nota,
            fecha: df.string(from: m.fecha),
            monto: Double(m.monto) / 100.0,
            metodoPago: m.metodo,
            beneficiario: m.pagadoA,
            beneficiarioRfc: m.rfc,
            emitirConstancia: m.darConstanciaAnual ? 1 : 0,
            estado: m.marcadoPendiente ? "pendiente" : "aprobado",
            notas: m.notasAuditoria,
            registradoPor: m.registradoPor,
            folio: folioSeq.map(String.init) ?? m.folio,
            folioSeq: folioSeq ?? Int(m.folio)
        )
    }

    private func parseDate(_ text: String?) -> Date {
        guard let text else { return Date() }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: text) { return d }
        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: text) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: text) { return d }
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: text) ?? Date()
    }

    private func parseHora(_ text: String?) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: parseDate(text))
    }
}
