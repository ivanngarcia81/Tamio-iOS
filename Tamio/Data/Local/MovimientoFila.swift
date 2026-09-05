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
    /// Los tres valores de `transactions.estado`. Era un booleano
    /// `marcadoPendiente`, y por eso "devolver al tesorero" no tenía dónde
    /// escribirse.
    var estadoRevision: String
    var incluidoEnCorte: Bool
    var darConstanciaAnual: Bool
    var repiteMensual: Bool
    /// Qué serie recurrente generó este movimiento, si lo generó alguna. Es lo
    /// que permite cambiarle el importe a toda una renta o retirarla entera.
    var recurrenteId: String?
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
        estadoRevision = m.estadoRevision.rawValue
        incluidoEnCorte = m.incluidoEnCorte
        darConstanciaAnual = m.darConstanciaAnual
        repiteMensual = m.repiteMensual
        recurrenteId = m.recurrenteId
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
            estadoRevision: EstadoRevision(rawValue: estadoRevision) ?? .aprobado,
            incluidoEnCorte: incluidoEnCorte,
            darConstanciaAnual: darConstanciaAnual,
            repiteMensual: repiteMensual,
            recurrenteId: recurrenteId,
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

// MARK: - Depósitos

/// Un corte tal y como vive en SQLite. Espejo de `cortes` de Supabase, más dos
/// campos de borrador —`periodo` y `ficha`— que allí no tienen columna porque
/// pertenecen a `depositos_bancarios`, la fila que solo nace cuando el dinero
/// llega al banco.
struct CorteFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "corte"

    var id: String
    var titulo: String
    var descripcion: String
    var estado: String
    var cuenta: String
    var fecha: String
    var periodo: String
    var ficha: String?
    var depositoId: String?
    var registradoPor: String
    var dobleFirmaPedida: Bool
    var segundaFirma: String?
    var segundaFirmaRol: String?
    var segundaFirmaEn: String?
    var segundaFirmaModo: String?
    var segundaConteo: Int?
    var actualizadoEn: String?
    var borrado: Bool

    /// Los estados de Supabase, que no son los de la app: allí un corte está
    /// "abierto" o "cerrado", aquí `pendiente` o `depositado`.
    static let abierto = "abierto"
    static let depositado = "depositado"

    /// Corte vacío con solo su id, para rellenarlo campo a campo al bajarlo.
    init(id: String) {
        self.id = id
        titulo = ""; descripcion = ""; estado = Self.abierto
        cuenta = ""; fecha = ""; periodo = ""
        ficha = nil; depositoId = nil; registradoPor = ""
        dobleFirmaPedida = false
        segundaFirma = nil; segundaFirmaRol = nil
        segundaFirmaEn = nil; segundaFirmaModo = nil; segundaConteo = nil
        actualizadoEn = nil; borrado = false
    }

    init(_ c: Corte, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = c.id
        titulo = c.titulo
        descripcion = c.descripcion
        estado = c.estado == .depositado ? Self.depositado : Self.abierto
        cuenta = c.registro.cuenta
        fecha = c.registro.fecha
        periodo = c.registro.periodo
        // El recibo NO vive aquí: vive en el depósito, que es la fila que nace
        // al ir al banco. La columna `ficha` de la v4 se queda sin uso —era el
        // borrador de cuando el corte guardaba el nombre del archivo— y no se
        // borra porque una migración destructiva por un campo muerto no vale
        // la pena; ninguna lectura la mira.
        ficha = nil
        depositoId = nil
        registradoPor = c.registradoPor
        dobleFirmaPedida = c.dobleFirmaPedida
        segundaFirma = c.segundaFirma
        segundaFirmaRol = c.segundaFirmaRol
        segundaFirmaEn = c.segundaFirmaEn
        segundaFirmaModo = c.segundaFirmaModo
        segundaConteo = c.segundaConteo
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    /// El corte SIN sus movimientos: los resuelve el repositorio desde la tabla
    /// puente. Aquí no se guarda ninguna copia que pueda quedarse vieja.
    var corte: Corte {
        Corte(
            id: id,
            titulo: titulo,
            descripcion: descripcion,
            estado: estado == Self.depositado ? .depositado : .pendiente,
            movimientos: [],
            registro: RegistroDeposito(cuenta: cuenta, fecha: fecha, periodo: periodo),
            registradoPor: registradoPor,
            dobleFirmaPedida: dobleFirmaPedida,
            segundaFirma: segundaFirma,
            segundaFirmaRol: segundaFirmaRol,
            segundaFirmaEn: segundaFirmaEn,
            segundaFirmaModo: segundaFirmaModo,
            segundaConteo: segundaConteo
        )
    }
}

/// La tabla puente `corte_movimientos`: qué movimiento va en qué corte y nada
/// más. Sin importe, sin categoría — el dinero vive en `movimiento`.
struct CorteMovimientoFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "corteMovimiento"

    var id: String
    var corteId: String
    var movimientoId: String
    var actualizadoEn: String?
    var borrado: Bool
}

/// Un depósito bancario en SQLite. Espejo de `depositos_bancarios`.
struct DepositoFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "deposito"

    var id: String
    var fecha: String
    var periodo: String
    var monto: Int
    var cuenta: String
    var referencia: String
    var archivoLocal: String?
    var comprobantePath: String?
    var actualizadoEn: String?
    var borrado: Bool

    init(_ d: DepositoBancario, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = d.id
        fecha = d.fecha
        periodo = d.periodo
        monto = d.monto
        cuenta = d.cuenta
        referencia = d.referencia
        archivoLocal = d.archivoLocal
        comprobantePath = d.comprobantePath
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    var deposito: DepositoBancario {
        DepositoBancario(id: id, fecha: fecha, periodo: periodo, monto: monto,
                         cuenta: cuenta, referencia: referencia,
                         archivoLocal: archivoLocal, comprobantePath: comprobantePath)
    }
}

// MARK: - Movimientos recurrentes

/// Una definición recurrente en SQLite. Espejo de `movimientos_recurrentes`.
///
/// Guarda los campos del movimiento que va a generar —importe, categoría,
/// método, beneficiario— más los dos que hacen que sea una regla y no un
/// movimiento: desde qué mes se repite y hasta cuál se ha registrado ya.
struct MovimientoRecurrenteFila: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "movimientoRecurrente"

    var id: String
    var tipo: String
    var categoria: String
    var subcategoria: String?
    var nota: String?
    var monto: Int
    var metodo: String
    var pagadoA: String?
    var rfc: String?
    var dia: Int
    /// "YYYY-MM" las dos. Se comparan como texto, que es lo que ordena bien.
    var mesInicio: String
    var ultimoMesGenerado: String?
    var activo: Bool
    var actualizadoEn: String?
    var borrado: Bool

    init(_ r: MovimientoRecurrente, actualizadoEn: String? = nil, borrado: Bool = false) {
        id = r.id
        tipo = r.tipo == .ingreso ? "ingreso" : "gasto"
        categoria = r.categoria
        subcategoria = r.subcategoria
        nota = r.nota
        monto = r.monto
        metodo = r.metodo
        pagadoA = r.pagadoA
        rfc = r.rfc
        dia = r.dia
        mesInicio = r.mesInicio
        ultimoMesGenerado = r.ultimoMesGenerado
        activo = r.activo
        self.actualizadoEn = actualizadoEn
        self.borrado = borrado
    }

    var recurrente: MovimientoRecurrente {
        MovimientoRecurrente(
            id: id,
            tipo: tipo == "ingreso" ? .ingreso : .gasto,
            categoria: categoria,
            subcategoria: subcategoria,
            nota: nota,
            monto: monto,
            metodo: metodo,
            pagadoA: pagadoA,
            rfc: rfc,
            dia: dia,
            mesInicio: mesInicio,
            ultimoMesGenerado: ultimoMesGenerado,
            activo: activo
        )
    }
}
