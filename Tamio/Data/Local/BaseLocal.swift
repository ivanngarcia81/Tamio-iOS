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
                t.column("marcadoPendiente", .boolean).notNull().defaults(to: false)
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
                t.column("moneda", .text).notNull().defaults(to: "USD")
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
        m.registerMigration("v3_aportantes") { db in
            // Espejo de `members`. Ojo: aquí NO se guardan los aportes de cada
            // persona. Un aporte no es una entidad aparte: es un ingreso de
            // `movimiento` que lleva su `memberUid`. Guardarlos dos veces sería
            // pedir que se contradigan.
            try db.create(table: "aportante") { t in
                t.primaryKey("id", .text)
                t.column("nombre", .text).notNull()
                t.column("estado", .text).notNull().defaults(to: "activo")
                t.column("telefono", .text).notNull().defaults(to: "")
                t.column("correo", .text).notNull().defaults(to: "")
                t.column("nacimiento", .text).notNull().defaults(to: "")
                t.column("direccion", .text).notNull().defaults(to: "")
                t.column("estadoCivil", .text).notNull().defaults(to: "")
                t.column("idFiscal", .text).notNull().defaults(to: "")
                t.column("miembroDesde", .text).notNull().defaults(to: "")
                t.column("congregaDesde", .text).notNull().defaults(to: "")
                t.column("frecuencia", .text).notNull().defaults(to: "ocasional")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_aportante_borrado", on: "aportante",
                          columns: ["borrado"])
        }

        // **Depósitos.** Dos tablas y no una, igual que en Supabase: el corte
        // no contiene dinero, contiene punteros a movimientos que ya viven en
        // `movimiento`. Guardar aquí una copia del importe sería pedir que se
        // contradigan, como ya pasó cuando el corte llevaba sus propios
        // `MovimientoCaja`.
        m.registerMigration("v4_cortes") { db in
            // Espejo de `cortes`.
            try db.create(table: "corte") { t in
                t.primaryKey("id", .text)
                t.column("titulo", .text).notNull().defaults(to: "")
                t.column("descripcion", .text).notNull().defaults(to: "")
                t.column("estado", .text).notNull().defaults(to: "abierto")
                t.column("cuenta", .text).notNull().defaults(to: "")
                t.column("fecha", .text).notNull().defaults(to: "")
                // `periodo` y `ficha` NO tienen columna en `cortes`: en Supabase
                // viven en `depositos_bancarios`, que solo existe cuando el
                // corte ya se depositó. Aquí se guardan como borrador para que
                // el tesorero pueda fijarlos ANTES de ir al banco; al depositar
                // pasarán a su fila definitiva. Hasta entonces no suben.
                t.column("periodo", .text).notNull().defaults(to: "")
                t.column("ficha", .text)
                t.column("depositoId", .text)
                t.column("registradoPor", .text).notNull().defaults(to: "")
                // Doble conteo: el asistente cuenta el mismo dinero por su lado
                // y firma que le sale igual. `segundaConteo` es SU importe, no
                // una copia del total, para poder compararlos.
                t.column("dobleFirmaPedida", .boolean).notNull().defaults(to: false)
                t.column("segundaFirma", .text)
                t.column("segundaFirmaRol", .text)
                t.column("segundaFirmaEn", .text)
                t.column("segundaFirmaModo", .text)
                t.column("segundaConteo", .integer)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_corte_estado", on: "corte",
                          columns: ["estado", "borrado"])

            // Espejo de `corte_movimientos`: la agrupación pura. Dos columnas
            // útiles y nada más — sin monto, sin categoría, sin copia de nada.
            try db.create(table: "corteMovimiento") { t in
                t.primaryKey("id", .text)
                t.column("corteId", .text).notNull()
                t.column("movimientoId", .text).notNull()
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_corteMov_corte", on: "corteMovimiento",
                          columns: ["corteId", "borrado"])
            // **La misma regla que impone Postgres** con `idx_corte_movs_tx_vivo`:
            // un movimiento vivo pertenece a UN corte, nunca a dos. Sin esto el
            // teléfono aceptaría offline lo que el servidor va a rechazar al
            // sincronizar — depositar el mismo diezmo dos veces.
            try db.execute(sql: """
                create unique index idx_corteMov_movVivo
                on corteMovimiento (movimientoId) where borrado = 0
                """)
        }

        // **El depósito bancario: el acto de llevar el dinero al banco.**
        // Entidad aparte del corte, igual que en Supabase: el corte agrupa
        // dinero y puede existir semanas; el depósito solo existe si alguien
        // fue al banco, y trae el recibo.
        m.registerMigration("v5_depositos") { db in
            try db.create(table: "deposito") { t in
                t.primaryKey("id", .text)
                t.column("fecha", .text).notNull().defaults(to: "")
                t.column("periodo", .text).notNull().defaults(to: "")
                t.column("monto", .integer).notNull().defaults(to: 0)
                t.column("cuenta", .text).notNull().defaults(to: "")
                t.column("referencia", .text).notNull().defaults(to: "")
                // El recibo va en DOS columnas y no en una. `archivoLocal` se
                // escribe siempre, antes de tocar la red: depositar sin señal
                // no puede perder la foto. `comprobantePath` solo aparece
                // cuando la subida al bucket ha salido bien, así que mientras
                // sea nulo la sincronización sabe que le queda trabajo.
                t.column("archivoLocal", .text)
                t.column("comprobantePath", .text)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            // Los recibos que aún no han subido: es lo que barre el motor.
            try db.create(index: "idx_deposito_sinSubir", on: "deposito",
                          columns: ["comprobantePath"])
        }

        // **El estado de revisión deja de ser un booleano.** `marcadoPendiente`
        // solo sabía decir "espera visto bueno" o "no", así que devolver un
        // movimiento al tesorero no tenía dónde escribirse y la bandeja hacía
        // lo mismo que aprobar. Los tres valores son los de `transactions.estado`.
        m.registerMigration("v6_estadoRevision") { db in
            try db.alter(table: "movimiento") { t in
                t.add(column: "estadoRevision", .text).notNull().defaults(to: "aprobado")
            }
            try db.execute(sql: """
                update movimiento set estadoRevision = 'pendiente' where marcadoPendiente = 1
                """)
            // La columna vieja se queda muerta pero con valor por omisión: sin
            // eso, un INSERT que ya no la menciona fallaría por NOT NULL.
            try db.execute(sql: """
                update movimiento set marcadoPendiente = 0 where marcadoPendiente is null
                """)
        }
        // **Las categorías que se inventa la iglesia.** La tabla existe en
        // Supabase desde antes que esta app —`categorias_custom`, con datos—
        // y aquí no se miraba: Ajustes enseñaba una lista escrita a mano en la
        // vista, distinta en el iPhone y en el iPad, y ninguna de las dos
        // coincidía con el catálogo que de verdad ofrecen los formularios.
        m.registerMigration("v7_categoriasCustom") { db in
            try db.create(table: "categoriaCustom") { t in
                t.primaryKey("id", .text)
                t.column("tipo", .text).notNull().defaults(to: "gasto")
                t.column("nombre", .text).notNull().defaults(to: "")
                t.column("color", .text).notNull().defaults(to: "")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **Los permisos del rol Tesorería, en el espejo local.** Existen en
        // Supabase desde la migración 49 y la app los ignoraba: los dos
        // interruptores de "Acceso y áreas" eran `@State` que no salían de la
        // pantalla, así que apagarlos no le quitaba nada a nadie.
        //
        // Los valores por omisión son los del servidor. Bajan como el resto de
        // la iglesia, pero NO suben con ella: los escribe un RPC que solo
        // acepta al administrador.
        m.registerMigration("v8_permisosTesoreria") { db in
            try db.alter(table: "iglesia") { t in
                t.add(column: "tesoreroVePadron", .boolean).notNull().defaults(to: false)
                t.add(column: "tesoreroPuedeEliminar", .boolean).notNull().defaults(to: true)
            }
        }

        // **El plan y la suscripción, en el espejo local.** Las tres columnas
        // existen en `iglesias` y las dos filas de Ajustes decían "Completo" y
        // "Cortesía" escritas a mano, pasara lo que pasara. Solo bajan: el
        // plan lo administra el servidor.
        m.registerMigration("v9_planSuscripcion") { db in
            try db.alter(table: "iglesia") { t in
                t.add(column: "plan", .text).notNull().defaults(to: "")
                t.add(column: "subEstado", .text).notNull().defaults(to: "")
                t.add(column: "subVence", .text).notNull().defaults(to: "")
            }
        }

        // **El saldo de apertura.** Era un `@State` de Ajustes que se perdía al
        // salir de la pantalla. La columna de Supabase se creó el 2026-09-04.
        m.registerMigration("v10_saldoInicial") { db in
            try db.alter(table: "iglesia") { t in
                t.add(column: "saldoInicial", .integer).notNull().defaults(to: 0)
            }
        }

        // **Correo y teléfono del tesorero y del pastor.** En el iPad esas
        // cuatro filas existían desde el principio, pero eran texto fijo:
        // parecían campos editables y no había dónde guardar nada. Las
        // columnas de Supabase se crearon el 2026-09-04.
        m.registerMigration("v11_contactoPersonas") { db in
            try db.alter(table: "iglesia") { t in
                t.add(column: "tesoreroCorreo", .text).notNull().defaults(to: "")
                t.add(column: "tesoreroTelefono", .text).notNull().defaults(to: "")
                t.add(column: "pastorCorreo", .text).notNull().defaults(to: "")
                t.add(column: "pastorTelefono", .text).notNull().defaults(to: "")
            }
        }


        // **El periodo contable pasa de texto escrito a clave.** Se guardaba
        // "Agosto 2026", que es lo que viajaba a `depositos_bancarios.periodo`
        // — y la app web agrupa el estado financiero por `"YYYY-MM"`. Un
        // depósito registrado desde el teléfono no salía en ningún reporte de
        // la web, y quedaba con clave distinta según el idioma en que
        // estuviera el aparato al registrarlo.
        //
        // Se reescriben las filas ya guardadas: lo que no se reconozca se
        // queda como está, porque un periodo ilegible es mejor que uno
        // inventado.
        m.registerMigration("v12_periodoClave") { db in
            for tabla in ["corte", "deposito"] {
                let filas = try Row.fetchAll(db, sql: "SELECT id, periodo FROM \(tabla)")
                for fila in filas {
                    let id: String = fila["id"]
                    let periodo: String = fila["periodo"] ?? ""
                    guard !periodo.isEmpty,
                          let clave = Fechas.claveDePeriodoEscrito(periodo),
                          clave != periodo else { continue }
                    try db.execute(sql: "UPDATE \(tabla) SET periodo = ? WHERE id = ?",
                                   arguments: [clave, id])
                }
            }
        }


        // **Y la fecha, por lo mismo.** `cortes.fecha` y
        // `depositos_bancarios.fecha` guardaban "Lunes 17 de agosto": una
        // frase en una columna de fecha, donde el resto de las filas de
        // Supabase están en ISO. Así no se puede ordenar ni comparar, y la app
        // web hace las dos cosas con ella.
        m.registerMigration("v13_fechaClave") { db in
            for tabla in ["corte", "deposito"] {
                let filas = try Row.fetchAll(db, sql: "SELECT id, fecha FROM \(tabla)")
                for fila in filas {
                    let id: String = fila["id"]
                    let fecha: String = fila["fecha"] ?? ""
                    guard !fecha.isEmpty, Fechas.desdeTexto(fecha) == nil,
                          let d = Fechas.desdeSemilla(fecha) else { continue }
                    try db.execute(sql: "UPDATE \(tabla) SET fecha = ? WHERE id = ?",
                                   arguments: [Fechas.claveDia(d), id])
                }
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
            try db.execute(sql: "delete from aportante")
            try db.execute(sql: "delete from categoriaCustom")
        }
    }
}
