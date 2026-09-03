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
            case tipo, categoria, concepto, fecha, monto, estado, notas, folio
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
        try await supabase
            .from("transactions")
            .insert(toInsert(nuevo))
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

    func siguienteFolio() async -> String {
        struct FolioRow: Decodable {
            let folioSeq: Int?
            enum CodingKeys: String, CodingKey { case folioSeq = "folio_seq" }
        }
        let rows: [FolioRow]? = try? await supabase
            .from("transactions")
            .select("folio_seq")
            .eq("church_id", value: churchIdActivo)
            .eq("deleted", value: false)
            .order("folio_seq", ascending: false)
            .limit(1)
            .execute()
            .value
        let max = rows?.first?.folioSeq ?? 0
        return String(max + 1)
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
        let nombreMiembro = dto.memberUid.flatMap { nombres[$0] }
        let persona: String? = tipo == .ingreso ? nombreMiembro : dto.beneficiario
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
            miembro: nombreMiembro,
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
            repiteMensual: false
        )
    }

    private func toInsert(_ m: Movimiento) -> TransaccionInsert {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]
        return TransaccionInsert(
            uid: m.id.isEmpty ? UUID().uuidString : m.id,
            churchId: churchIdActivo,
            memberUid: nil,     // resolución de member por nombre pendiente
            tipo: m.tipo == .ingreso ? "ingreso" : "gasto",
            categoria: m.categoria,
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
            folio: m.folio,
            folioSeq: Int(m.folio)
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
