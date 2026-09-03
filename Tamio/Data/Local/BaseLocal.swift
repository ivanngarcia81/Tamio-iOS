import Foundation
import GRDB

/// La base de datos del teléfono.
///
/// **Es la fuente de verdad de la app.** La UI lee siempre de aquí, haya red o
/// no; la sincronización la rellena por detrás. Antes cada pantalla consultaba
/// Supabase directamente, así que sin señal no se podía ni leer lo ya
/// capturado ni escribir nada nuevo.
final class BaseLocal {

    /// Instancia única. Si el archivo no se puede abrir se cae a una base en
    /// memoria: la app sigue usable durante la sesión (aunque no persista)
    /// en vez de reventar en el arranque.
    static let compartida = BaseLocal()

    let cola: DatabaseQueue
    /// Verdadero si se está trabajando sobre la base de emergencia en memoria.
    private(set) var enMemoria = false

    private init() {
        let fm = FileManager.default
        let carpeta = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                  appropriateFor: nil, create: true)
        if let carpeta {
            let ruta = carpeta.appendingPathComponent("tamio.sqlite").path
            if let cola = try? DatabaseQueue(path: ruta),
               (try? Self.migrador.migrate(cola)) != nil {
                self.cola = cola
                return
            }
        }
        // swiftlint:disable:next force_try — una base en memoria no puede fallar.
        self.cola = try! DatabaseQueue()
        try? Self.migrador.migrate(self.cola)
        enMemoria = true
    }

    // MARK: - Esquema

    private static var migrador: DatabaseMigrator {
        var m = DatabaseMigrator()

        m.registerMigration("v1_movimientos") { db in
            // Espejo de `transactions`. Los nombres siguen al modelo de la app,
            // no a los de Supabase: la traducción vive en un solo sitio (la
            // sincronización), no repartida por las pantallas.
            try db.create(table: "movimiento") { t in
                t.primaryKey("id", .text)
                t.column("tipo", .text).notNull()
                t.column("categoria", .text).notNull()
                t.column("subcategoria", .text)
                t.column("persona", .text)
                t.column("folio", .text).notNull()
                t.column("folioSeq", .integer)
                t.column("metodo", .text).notNull()
                t.column("monto", .integer).notNull()
                t.column("hora", .text).notNull()
                t.column("fecha", .double).notNull()
                t.column("registradoPor", .text).notNull()
                t.column("miembro", .text)
                t.column("memberUid", .text)
                t.column("aportanteNombre", .text)
                t.column("categoriaCompleta", .text).notNull()
                t.column("nota", .text)
                t.column("sinDepositar", .boolean).notNull()
                t.column("comprobante", .text)
                t.column("pagadoA", .text)
                t.column("rfc", .text)
                t.column("notasAuditoria", .text)
                t.column("marcadoPendiente", .boolean).notNull()
                t.column("incluidoEnCorte", .boolean).notNull()
                t.column("darConstanciaAnual", .boolean).notNull()
                t.column("repiteMensual", .boolean).notNull()
                // Marca del servidor, para saber qué es más reciente al bajar.
                t.column("actualizadoEn", .text)
                // El folio aún no lo ha dado el servidor: se enseña como
                // provisional y cambiará al sincronizar.
                t.column("folioProvisional", .boolean).notNull().defaults(to: false)
                // Borrado lógico, igual que en Supabase.
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_movimiento_tipo", on: "movimiento",
                          columns: ["tipo", "borrado"])

            // Cola de salida: lo que este aparato ha cambiado y aún no ha
            // llegado al servidor. Sobrevive a cerrar la app, que es el punto.
            try db.create(table: "outbox") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("entidad", .text).notNull()
                t.column("registroId", .text).notNull()
                t.column("operacion", .text).notNull()
                t.column("creadoEn", .double).notNull()
                t.column("intentos", .integer).notNull().defaults(to: 0)
                t.column("ultimoError", .text)
            }
            try db.create(index: "idx_outbox_registro", on: "outbox",
                          columns: ["entidad", "registroId"])

            // Hasta dónde se ha bajado de cada entidad.
            try db.create(table: "syncEstado") { t in
                t.primaryKey("entidad", .text)
                t.column("cursor", .text)
            }
        }

        m.registerMigration("v2_iglesia") { db in
            // Una fila por iglesia: el membrete y las firmas de los documentos.
            try db.create(table: "iglesia") { t in
                t.primaryKey("id", .text)
                t.column("nombre", .text).notNull().defaults(to: "")
                t.column("direccion", .text).notNull().defaults(to: "")
                t.column("ciudad", .text).notNull().defaults(to: "")
                t.column("estado", .text).notNull().defaults(to: "")
                t.column("pais", .text).notNull().defaults(to: "")
                t.column("codigoPostal", .text).notNull().defaults(to: "")
                t.column("idFiscal", .text).notNull().defaults(to: "")
                t.column("telefono", .text).notNull().defaults(to: "")
                t.column("correo", .text).notNull().defaults(to: "")
                t.column("moneda", .text).notNull().defaults(to: "MXN")
                t.column("pieInstitucional", .text).notNull().defaults(to: "")
                t.column("pastorNombre", .text).notNull().defaults(to: "")
                t.column("pastorCargo", .text).notNull().defaults(to: "Pastor")
                t.column("tesoreroNombre", .text).notNull().defaults(to: "")
                t.column("tesoreroCargo", .text).notNull().defaults(to: "Tesorero")
                t.column("secretarioNombre", .text).notNull().defaults(to: "")
                t.column("secretarioCargo", .text).notNull().defaults(to: "Secretario")
                t.column("imprimirFirmas", .boolean).notNull().defaults(to: true)
                t.column("actualizadoEn", .text)
            }
        }
        return m
    }

    /// Vacía todo lo descargado. Se usa al cerrar sesión: los datos de una
    /// iglesia no pueden quedarse en el aparato para el siguiente que entre.
    func limpiar() throws {
        try cola.write { db in
            try db.execute(sql: "delete from movimiento")
            try db.execute(sql: "delete from outbox")
            try db.execute(sql: "delete from syncEstado")
            try db.execute(sql: "delete from iglesia")
        }
    }
}
