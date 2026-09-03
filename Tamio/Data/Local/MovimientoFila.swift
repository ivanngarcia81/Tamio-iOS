import Foundation
import GRDB

/// Un movimiento tal y como vive en SQLite. Existe aparte de `Movimiento`
/// porque la fila guarda cosas que la pantalla no conoce —si el folio es
/// provisional, la marca de tiempo del servidor, el borrado lógico— y porque
/// `Movimiento` arrastra el rastro de auditoría, que no se persiste todavía.
struct MovimientoFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "movimiento"

    var id: String
    var tipo: String
    var categoria: String
    var subcategoria: String?
    var persona: String?
    var folio: String
    var folioSeq: Int?
    var metodo: String
    var monto: Int
    var hora: String
    var fecha: Double
    var registradoPor: String
    var miembro: String?
    var memberUid: String?
    var aportanteNombre: String?
    var categoriaCompleta: String
    var nota: String?
    var sinDepositar: Bool
    var comprobante: String?
    var pagadoA: String?
    var rfc: String?
    var notasAuditoria: String?
    var marcadoPendiente: Bool
    var incluidoEnCorte: Bool
    var darConstanciaAnual: Bool
    var repiteMensual: Bool
    var actualizadoEn: String?
    var folioProvisional: Bool
    var borrado: Bool

    // MARK: - Conversión

    init(_ m: Movimiento, folioProvisional: Bool = false,
         actualizadoEn: String? = nil, borrado: Bool = false) {
        id = m.id
        tipo = m.tipo == .ingreso ? "ingreso" : "gasto"
        categoria = m.categoria
        subcategoria = m.subcategoria
        persona = m.persona
        folio = m.folio
        folioSeq = Int(m.folio)
        metodo = m.metodo
        monto = m.monto
        hora = m.hora
        fecha = m.fecha.timeIntervalSince1970
        registradoPor = m.registradoPor
        miembro = m.miembro
        memberUid = m.memberUid
        aportanteNombre = m.aportanteNombre
        categoriaCompleta = m.categoriaCompleta
        nota = m.nota
        sinDepositar = m.sinDepositar
        comprobante = m.comprobante
        pagadoA = m.pagadoA
        rfc = m.rfc
        notasAuditoria = m.notasAuditoria
        marcadoPendiente = m.marcadoPendiente
        incluidoEnCorte = m.incluidoEnCorte
        darConstanciaAnual = m.darConstanciaAnual
        repiteMensual = m.repiteMensual
        self.actualizadoEn = actualizadoEn
        self.folioProvisional = folioProvisional
        self.borrado = borrado
    }

    var movimiento: Movimiento {
        Movimiento(
            id: id,
            tipo: tipo == "ingreso" ? .ingreso : .gasto,
            categoria: categoria,
            persona: persona,
            // Un folio que aún no ha pasado por el contador del servidor se
            // enseña marcado, para que nadie lo apunte como definitivo.
            folio: folioProvisional ? "P-\(folio)" : folio,
            metodo: metodo,
            monto: monto,
            hora: hora,
            fecha: Date(timeIntervalSince1970: fecha),
            registradoPor: registradoPor,
            miembro: miembro,
            categoriaCompleta: categoriaCompleta,
            nota: nota,
            sinDepositar: sinDepositar,
            comprobante: comprobante,
            auditoria: [],
            pagadoA: pagadoA,
            rfc: rfc,
            notasAuditoria: notasAuditoria,
            marcadoPendiente: marcadoPendiente,
            incluidoEnCorte: incluidoEnCorte,
            darConstanciaAnual: darConstanciaAnual,
            repiteMensual: repiteMensual,
            memberUid: memberUid,
            subcategoria: subcategoria,
            aportanteNombre: aportanteNombre
        )
    }
}

/// Una operación pendiente de subir.
struct OperacionPendiente: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "outbox"

    enum Operacion: String, Codable {
        case crear, actualizar, eliminar
    }

    var id: Int64?
    var entidad: String
    var registroId: String
    var operacion: String
    var creadoEn: Double
    var intentos: Int
    var ultimoError: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
