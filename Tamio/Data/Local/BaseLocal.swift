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

        // **Un recurrente no es un movimiento: es la regla que los crea.**
        //
        // Por eso tabla propia y no una columna más en `movimiento`. Lo que
        // había —`repiteMensual`, un booleano— no sabía desde qué mes se
        // repite ni cuál fue el último generado, así que no podía generar
        // nada; y como la columna no viajaba a Supabase, se borraba sola al
        // bajar el movimiento.
        //
        // Espejo de `movimientos_recurrentes`. `recurrenteId` en `movimiento`
        // es el vínculo de vuelta: por él se sabe qué movimientos salieron de
        // una serie, para poder cambiarles el importe o retirarlos todos.
        m.registerMigration("v14_recurrentes") { db in
            try db.create(table: "movimientoRecurrente") { t in
                t.primaryKey("id", .text)
                t.column("tipo", .text).notNull()
                t.column("categoria", .text).notNull()
                t.column("subcategoria", .text)
                t.column("nota", .text)
                t.column("monto", .integer).notNull()
                t.column("metodo", .text).notNull()
                t.column("pagadoA", .text)
                t.column("rfc", .text)
                // Día del mes; se ajusta en meses cortos al materializar.
                t.column("dia", .integer).notNull().defaults(to: 1)
                // "YYYY-MM", las dos. Claves estables: se comparan como texto
                // y viajan así a Supabase.
                t.column("mesInicio", .text).notNull()
                t.column("ultimoMesGenerado", .text)
                // Parar no es borrar: el historial ya generado se queda.
                t.column("activo", .boolean).notNull().defaults(to: true)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "idx_recurrente_activo", on: "movimientoRecurrente",
                          columns: ["activo", "borrado"])

            try db.alter(table: "movimiento") { t in
                t.add(column: "recurrenteId", .text)
            }
            try db.create(index: "idx_movimiento_recurrente", on: "movimiento",
                          columns: ["recurrenteId"])
        }

        // **El padrón no estrena tabla, y no hay nada que diseñar: se copia.**
        //
        // Dos cosas que había que mirar antes de escribir una sola columna, y
        // que cambian el trabajo entero:
        //
        // 1. `aportante` ES la fila de la persona. Su migración v3 ya se
        //    presenta como "Espejo de `members`", y `Aportante.estado` es del
        //    tipo `EstadoMiembro`, el enum del padrón. Una tabla `miembro`
        //    aparte serían dos verdades sobre la misma persona: cambiar un
        //    teléfono en Tesorería no lo cambiaría en Secretaría, y al primer
        //    traslado nadie sabría cuál de las dos filas manda.
        //
        // 2. **`public.members` ya tiene todas estas columnas.** El padrón
        //    completo —bautismos con su fecha, ministerios, cargos,
        //    instrumentos, habilidades, disponibilidad, iglesia anterior,
        //    baja con motivo, historial de estados y notas de seguimiento—
        //    existe en el servidor desde antes que esta app. Lo que faltaba
        //    era el lado local.
        //
        // Por eso los nombres y las formas son las del servidor y no las que
        // uno elegiría de cero. **Las listas van como texto con un array JSON
        // dentro** (`'[]'` por defecto, igual que allí) y no como tabla de
        // etiquetas: una tabla se consultaría mejor, pero obligaría a traducir
        // en cada subida y cada bajada, y un espejo que traduce deja de ser un
        // espejo — es el sitio donde los dos lados empiezan a discrepar. El
        // padrón son cientos de filas, no cientos de miles: filtrar por
        // ministerio se hace en memoria y se nota cero.
        //
        // Lo único que no se copia es `created_at`, que nadie lee.
        //
        // **`activo` sí se copia, y por poco no lo hace.** Parecía redundante
        // con `estado_membresia` —dos banderas para el mismo hecho— hasta ver
        // el código del app web, que es quien escribió esta tabla: dar de baja
        // es `activo = 0` + `fecha_baja` + `motivo_baja`, y `estado_membresia`
        // NI SE TOCA. Ver `docs/PADRON-WEB.md`.
        //
        // Aquí solo se abre el sitio. Membresía sigue sirviéndose de
        // `MockMembresiaRepository` hasta que exista el repositorio que lea
        // esto: una migración no cambia lo que se ve.
        m.registerMigration("v15_padron") { db in
            try db.alter(table: "aportante") { t in
                // Vida espiritual. Los booleanos viajan a Postgres como 0/1,
                // que es como están declarados allí.
                t.add(column: "bautizadoAgua", .boolean).notNull().defaults(to: false)
                t.add(column: "fechaBautismoAgua", .text).notNull().defaults(to: "")
                t.add(column: "bautizadoEspiritu", .boolean).notNull().defaults(to: false)
                t.add(column: "fechaBautismoEspiritu", .text).notNull().defaults(to: "")
                t.add(column: "cursoMembresia", .boolean).notNull().defaults(to: false)

                // Servicio y habilidades. Arrays JSON en texto, como el
                // servidor. La hoja de alta ya los junta y los parte por su
                // cuenta con comas: eso se va, porque un ministerio propio
                // puede llamarse "Niños, preescolar" y una coma de dato no se
                // distingue de una de separador.
                t.add(column: "ministerios", .text).notNull().defaults(to: "[]")
                t.add(column: "ministeriosInteres", .text).notNull().defaults(to: "[]")
                t.add(column: "cargos", .text).notNull().defaults(to: "[]")
                t.add(column: "instrumentos", .text).notNull().defaults(to: "[]")
                t.add(column: "habilidades", .text).notNull().defaults(to: "[]")
                t.add(column: "etiquetas", .text).notNull().defaults(to: "[]")
                t.add(column: "disponibilidad", .text).notNull().defaults(to: "")
                t.add(column: "interesServir", .boolean).notNull().defaults(to: false)

                // Procedencia y salida. **La baja necesita fecha y motivo**:
                // sin ellos, dentro de dos años una etiqueta gris no dice qué
                // pasó con esa persona. La hoja ya los pedía y no tenían dónde
                // caer.
                //
                // Y `activo` es LA bandera de la baja, no un duplicado de
                // `estado_membresia`: quien está de baja conserva el estado que
                // tenía —hay una fila así en la base ahora mismo, "enProceso"
                // con `activo = 0`— y la etiqueta que se enseña se deriva del
                // motivo. Sin esta columna, una baja hecha desde el teléfono
                // dejaría a la persona contada como activa en el app web.
                t.add(column: "activo", .boolean).notNull().defaults(to: true)
                t.add(column: "iglesiaAnterior", .text).notNull().defaults(to: "")
                t.add(column: "fechaBaja", .text).notNull().defaults(to: "")
                t.add(column: "motivoBaja", .text).notNull().defaults(to: "")

                // **El historial de estados es lo que hoy la ficha se inventa**
                // en "Movimientos de membresía" ("Alta como miembro", "Recibido
                // por traslado"), construido al vuelo en cada guardado y
                // perdido al siguiente. Array JSON, como en el servidor.
                t.add(column: "historialEstados", .text).notNull().defaults(to: "[]")

                // Seguimiento pastoral: cada llamada, visita u oración con su
                // fecha. Va en la fila y no en tabla propia por lo mismo que
                // las listas — así está en `members`.
                t.add(column: "seguimientoNotas", .text).notNull().defaults(to: "[]")
                t.add(column: "seguimientoRevisadoEn", .text).notNull().defaults(to: "")

                // Lo que la secretaria anota y no cabe en ningún campo. Existe
                // en `members` desde el principio; en el aparato, no.
                t.add(column: "notas", .text).notNull().defaults(to: "")
            }

            // **Lo que el enum viejo dejó escrito en `estado`.** Esta app
            // guardaba ahí "baja", "traslado", "nuevo" y "recibido", que el
            // servidor no lee. Una "baja" sí era una baja: pasa a `activo = 0`,
            // sin fecha ni motivo porque nunca los tuvo. "traslado" era un
            // traslado EN CURSO —la persona seguía en el padrón esperando la
            // carta— y "nuevo" y "recibido" eran personas activas con una
            // etiqueta de más: los tres vuelven a "activo".
            try db.execute(sql: "update aportante set activo = 0, estado = 'activo' where estado = 'baja'")
            try db.execute(sql: "update aportante set estado = 'activo' where estado in ('traslado', 'nuevo', 'recibido')")

            // **Los parentescos ya se editaban y no se guardaban en ninguna
            // parte**: `AportanteFila.aportante(...)` devuelve `familia: []`
            // fijo, así que el "Añadir pariente" de la ficha duraba lo que la
            // sesión. Espejo de `parentescos`, que también existe ya.
            //
            // Tabla y no columna porque un parentesco es de DOS personas: la
            // misma fila la lee el marido y la mujer, y guardarlo en la ficha
            // de cada uno sería la misma relación escrita dos veces, libre de
            // contradecirse. Se guarda UNA fila y la otra ficha la lee al
            // revés, con `Parentescos.inverso`.
            //
            // **Los dos extremos son personas del padrón, y no hay columna de
            // nombre.** El nombre se lee de la ficha del otro. Aquí llegué a
            // poner una: venía de que la hoja de alta ofrecía escribir el
            // nombre de un pariente que no congrega, y eso no se puede
            // sostener —la relación existiría solo en un lado, y la ficha del
            // pariente no podría enseñarla—. Se arregló la hoja, no la tabla.
            //
            // `tipo` guarda la CLAVE del catálogo (`conyuge`, `padre`, `hijo`…),
            // nunca la etiqueta traducida. Ver `docs/PADRON-WEB.md`.
            try db.create(table: "parentesco") { t in
                t.primaryKey("id", .text)
                t.column("miembroId", .text).notNull().indexed()
                t.column("parienteId", .text).notNull().indexed()
                t.column("tipo", .text).notNull().defaults(to: "otro")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            // La misma relación entre las mismas dos personas, una sola vez.
            try db.create(index: "idx_parentesco_par", on: "parentesco",
                          columns: ["miembroId", "parienteId"], unique: true)
            try db.create(index: "idx_parentesco_borrado", on: "parentesco",
                          columns: ["borrado"])
        }

        // **La asistencia, que es de donde salen los números que la ficha
        // finge.** `rachaSinAsistir`, `ultimaVisita`, `enRoster` y el % de la
        // gráfica son hoy cadenas escritas a mano; aquí está su fuente.
        //
        // Espejo de `servicios` y `servicio_asistencia`, que ya existen en el
        // servidor. Dos tablas y no una porque son dos cosas: el culto —con su
        // fecha, quién dirige, quién predica— y quién vino a él.
        //
        // Lo que NO se copia: `asistentes` y `ausentes` de `servicios`. El
        // propio web las marca como legado —"versiones previas guardaban
        // nombres; el roster nuevo vive en servicio_asistencia por ID"— y las
        // escribe como "[]". Copiar una columna muerta es invitar a que
        // alguien la crea viva.
        //
        // `visitantes` sí, porque no es legado: son las personas SIN ficha que
        // vinieron, con nombre y teléfono. Quien tiene ficha va en la otra
        // tabla, aunque sea visitante recurrente.
        m.registerMigration("v16_asistencia") { db in
            try db.create(table: "servicio") { t in
                t.primaryKey("id", .text)
                t.column("fecha", .text).notNull().indexed()   // "YYYY-MM-DD"
                t.column("tipo", .text).notNull().defaults(to: "dominical")
                t.column("dirige", .text).notNull().defaults(to: "")
                t.column("predica", .text).notNull().defaults(to: "")
                t.column("tituloMensaje", .text).notNull().defaults(to: "")
                t.column("textoBiblico", .text).notNull().defaults(to: "")
                t.column("resumenMensaje", .text).notNull().defaults(to: "")
                t.column("participaciones", .text).notNull().defaults(to: "[]")
                t.column("temaEscuela", .text).notNull().defaults(to: "")
                t.column("maestroEscuela", .text).notNull().defaults(to: "")
                t.column("visitantes", .text).notNull().defaults(to: "[]")
                // Conteos de cabeza: los que se cuentan sin lista.
                t.column("ninos", .integer).notNull().defaults(to: 0)
                t.column("jovenes", .integer).notNull().defaults(to: 0)
                t.column("adultos", .integer).notNull().defaults(to: 0)
                t.column("eventos", .text).notNull().defaults(to: "")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }

            // Una fila por persona y culto. **La asistencia se guarda por
            // PERSONA aunque se tome por familia**: la racha, la última visita
            // y el "cuatro servicios sin asistir" son de cada uno, y guardarlo
            // por familia taparía al hijo que lleva dos meses sin venir, que
            // es justo lo que el seguimiento existe para no perder.
            //
            // `razon` y `seguimiento` solo significan algo cuando `presente`
            // es falso; el web los limpia al marcar presente y aquí igual.
            //
            // `nombreSnapshot` no es un duplicado por descuido: la lista de un
            // culto de hace dos años tiene que seguir diciendo el nombre que
            // la persona tenía entonces.
            try db.create(table: "servicioAsistencia") { t in
                t.primaryKey("id", .text)
                t.column("servicioId", .text).notNull().indexed()
                t.column("miembroId", .text).notNull().indexed()
                t.column("presente", .boolean).notNull().defaults(to: false)
                t.column("razon", .text).notNull().defaults(to: "")
                t.column("razonOtra", .text).notNull().defaults(to: "")
                t.column("seguimiento", .boolean).notNull().defaults(to: false)
                t.column("nombreSnapshot", .text).notNull().defaults(to: "")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            // La misma persona una vez por culto. El web guarda por
            // diferencias sobre esta pareja para conservar el uid entre
            // guardados; sin el índice, dos guardados seguidos la duplicarían.
            try db.create(index: "idx_asistencia_unica", on: "servicioAsistencia",
                          columns: ["servicioId", "miembroId"], unique: true)
        }

        // Las dos hijas del culto: **quién hace qué** y **en qué orden**.
        // Espejo de `servicio_puestos` y `servicio_orden`, que ya existen.
        //
        // Tablas y no columnas JSON dentro de `servicio` —al contrario que
        // `participaciones` o `visitantes`— porque así están allí, y porque un
        // puesto apunta a una PERSONA del padrón: con `member_uid` se puede
        // preguntar en qué sirvió alguien el año pasado, y con una lista de
        // nombres dentro de una columna, no.
        //
        // `nombre` convive con `miembroId` a propósito, como en el servidor:
        // quien toca el bajo un domingo puede ser el primo del baterista, que
        // no tiene ficha. Y si la tiene, el nombre guardado es el que tenía
        // entonces.
        m.registerMigration("v17_puestosYOrden") { db in
            try db.create(table: "servicioPuesto") { t in
                t.primaryKey("id", .text)
                t.column("servicioId", .text).notNull().indexed()
                t.column("puesto", .text).notNull().defaults(to: "")
                t.column("nombre", .text).notNull().defaults(to: "")
                t.column("miembroId", .text)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "servicioOrden") { t in
                t.primaryKey("id", .text)
                t.column("servicioId", .text).notNull().indexed()
                // El orden lo da esta columna, no el orden de inserción: dos
                // aparatos que añaden un punto a la vez tienen que poder
                // ponerse de acuerdo en dónde va.
                t.column("posicion", .integer).notNull().defaults(to: 0)
                t.column("hora", .text).notNull().defaults(to: "")
                t.column("titulo", .text).notNull().defaults(to: "")
                t.column("encargado", .text).notNull().defaults(to: "")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **La agenda, espejo de `public.agenda`.** La pantalla existía desde
        // el principio pero corría sobre `MockAgendaRepository`: no había
        // tabla, no había cola de salida y crear una actividad solo la metía
        // en un array que se perdía al recargar. La tabla del web ya estaba
        // puesta y con datos.
        //
        // Las columnas son las suyas, con dos diferencias que conviene saber:
        //
        // `completado` no existe allá. El web lo dice con `estado`, que tiene
        // cinco valores —borrador, programada, confirmada, completada,
        // cancelada—; aquí se deriva de él al leer y se escribe de vuelta como
        // `completada`. Guardar los dos habría dejado que se contradijeran.
        //
        // `recurrencia`, `excepciones` y `recordatorios` viajan como el JSON
        // que son, sin interpretarlos: el iOS todavía no repite series, y
        // parsear para volver a serializar solo añade sitios donde perder
        // datos que el web sí sabe leer.
        m.registerMigration("v18_agenda") { db in
            try db.create(table: "agenda") { t in
                t.primaryKey("id", .text)
                t.column("fecha", .text).notNull().indexed()   // "YYYY-MM-DD"
                t.column("nombre", .text).notNull().defaults(to: "")
                t.column("tipo", .text).notNull().defaults(to: "otra")
                t.column("tipoPersonalizado", .text).notNull().defaults(to: "")
                t.column("horaInicio", .text)
                t.column("horaFin", .text)
                t.column("diaCompleto", .boolean).notNull().defaults(to: false)
                t.column("lugar", .text).notNull().defaults(to: "")
                t.column("descripcion", .text).notNull().defaults(to: "")
                // El responsable puede ser alguien del padrón o texto libre,
                // como en el web: una actividad la puede llevar quien no tiene
                // ficha todavía.
                t.column("miembroId", .text)
                t.column("responsablePersona", .text).notNull().defaults(to: "")
                t.column("responsableMinisterio", .text).notNull().defaults(to: "")
                t.column("invitado", .text).notNull().defaults(to: "")
                t.column("contacto", .text).notNull().defaults(to: "")
                t.column("estado", .text).notNull().defaults(to: "programada")
                t.column("recurrencia", .text).notNull().defaults(to: #"{"tipo":"ninguna"}"#)
                t.column("excepciones", .text).notNull().defaults(to: "[]")
                t.column("recordatorios", .text).notNull().defaults(to: "[]")
                t.column("esFechaImportante", .boolean).notNull().defaults(to: false)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **Las actas, espejo de `public.actas`.** Mismo caso que la agenda:
        // la pantalla llevaba desde el principio con `MockActasRepository` y
        // sus cuatro actas escritas, mientras la tabla del web ya existía.
        //
        // Los nombres, columna a columna, son los del web. Las listas de
        // nombres —presentes, ausentes, invitados— y las de mociones y
        // acuerdos viajan como el JSON que son allá.
        //
        // `firmas` se guarda aunque el iOS todavía recoja las suyas en
        // `FirmasLocales`: si no estuviera, bajar un acta firmada desde el web
        // perdería las firmas al volver a subirla.
        m.registerMigration("v19_actas") { db in
            try db.create(table: "acta") { t in
                t.primaryKey("id", .text)
                t.column("folio", .text).notNull().defaults(to: "")
                t.column("tipo", .text).notNull().defaults(to: "otra")
                t.column("titulo", .text).notNull().defaults(to: "")
                t.column("fecha", .text).notNull().indexed()   // "YYYY-MM-DD"
                t.column("horaInicio", .text)
                t.column("horaCierre", .text)
                t.column("lugar", .text).notNull().defaults(to: "")
                t.column("preside", .text).notNull().defaults(to: "")
                t.column("secretario", .text).notNull().defaults(to: "")
                t.column("testigo", .text).notNull().defaults(to: "")
                t.column("presentes", .text).notNull().defaults(to: "[]")
                t.column("ausentes", .text).notNull().defaults(to: "[]")
                t.column("invitados", .text).notNull().defaults(to: "[]")
                t.column("quorum", .integer).notNull().defaults(to: 0)
                t.column("agenda", .text).notNull().defaults(to: "")
                t.column("resumen", .text).notNull().defaults(to: "")
                t.column("mociones", .text).notNull().defaults(to: "[]")
                t.column("acuerdos", .text).notNull().defaults(to: "[]")
                t.column("estado", .text).notNull().defaults(to: "borrador")
                t.column("confidencial", .boolean).notNull().defaults(to: false)
                t.column("fechaAprobacion", .text)
                t.column("firmas", .text).notNull().defaults(to: "[]")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **Las cartas, espejo de `public.cartas`.** Igual que agenda y actas:
        // la pantalla existía, la tabla del web también, y en medio no había
        // nada. `emitirCarta()` metía una fila de cuatro campos en un array.
        //
        // `historialEstados` se guarda aunque el iOS todavía no lo enseñe, por
        // lo mismo que `firmas` en las actas: bajar una carta con historial y
        // volver a subirla sin él lo borraría.
        m.registerMigration("v20_cartas") { db in
            try db.create(table: "carta") { t in
                t.primaryKey("id", .text)
                t.column("folio", .text).notNull().defaults(to: "")
                t.column("tipo", .text).notNull().defaults(to: "personalizada")
                t.column("fechaEmision", .text).notNull().indexed()   // "YYYY-MM-DD"
                t.column("lugarEmision", .text).notNull().defaults(to: "")
                t.column("miembroId", .text)
                t.column("destinatarioTipo", .text).notNull().defaults(to: "")
                t.column("destinatarioNombre", .text).notNull().defaults(to: "")
                t.column("destinatarioDireccion", .text).notNull().defaults(to: "")
                t.column("asunto", .text).notNull().defaults(to: "")
                t.column("saludo", .text).notNull().defaults(to: "")
                t.column("cuerpoHtml", .text).notNull().defaults(to: "")
                t.column("despedida", .text).notNull().defaults(to: "")
                t.column("firmas", .text).notNull().defaults(to: "[]")
                t.column("observaciones", .text).notNull().defaults(to: "")
                t.column("estado", .text).notNull().defaults(to: "borrador")
                t.column("historialEstados", .text).notNull().defaults(to: "[]")
                t.column("entregadaA", .text).notNull().defaults(to: "")
                t.column("fechaEntrega", .text)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **El registro, espejo de `public.registro`.** La quinta y última de
        // Secretaría. Aquí estaba también la fila de Mensajes del hub: no
        // estaba pendiente, estaba retirada —el web la sustituyó por esta
        // tabla el 26 de agosto de 2026— y se quitó.
        //
        // `datos` guarda las piezas del texto en JSON y `cuerpo` solo lo usan
        // las notas: la frase se compone al leer, que es la razón por la que
        // esta tabla existe. Ver `TipoSuceso`.
        m.registerMigration("v21_registro") { db in
            try db.create(table: "registro") { t in
                t.primaryKey("id", .text)
                t.column("tipo", .text).notNull().defaults(to: "nota")
                t.column("area", .text).notNull().defaults(to: "general")
                t.column("datos", .text).notNull().defaults(to: "{}")
                t.column("cuerpo", .text).notNull().defaults(to: "")
                t.column("quien", .text).notNull().defaults(to: "")
                // ISO 8601 con hora: aquí el instante importa, no solo el día.
                t.column("creadoEn", .text).notNull().indexed()
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **Las plantillas de carta, espejo de `public.plantillas`.** La última
        // de Secretaría. La lista de plantillas se dibujaba de `TipoPlantilla.
        // allCases` —quince casos escritos en un `enum`— mientras la iglesia
        // tenía sus once en la base: cambiar el texto de una plantilla desde el
        // web no llegaba al teléfono, y cinco de las quince ni existen allá.
        //
        // El cuerpo viene en HTML y con variables `{{miembro_nombre}}`. Se
        // guarda tal cual: interpretarlo al bajar sería perder lo que el web
        // sabe leer, y quien lo tenga que enseñar decide cómo.
        m.registerMigration("v22_plantillas") { db in
            try db.create(table: "plantilla") { t in
                t.primaryKey("id", .text)
                t.column("nombre", .text).notNull().defaults(to: "")
                t.column("tipo", .text).notNull().defaults(to: "personalizada")
                t.column("asunto", .text).notNull().defaults(to: "")
                t.column("saludo", .text).notNull().defaults(to: "")
                t.column("cuerpoHtml", .text).notNull().defaults(to: "")
                t.column("despedida", .text).notNull().defaults(to: "")
                t.column("activa", .boolean).notNull().defaults(to: true)
                t.column("predeterminada", .boolean).notNull().defaults(to: false)
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **El traslado de salida, para saber quién está en curso.** No es la
        // tabla entera del web —el expediente tiene veinte columnas, folio
        // propio, carta enganchada e historial de estados— sino lo que el
        // teléfono necesita para no mentir: de quién es, en qué punto va y a
        // dónde. El expediente se lleva en el escritorio, que es donde se
        // aprueba y se firma.
        m.registerMigration("v23_traslados") { db in
            try db.create(table: "trasladoSalida") { t in
                t.primaryKey("id", .text)
                t.column("miembroId", .text)
                t.column("folio", .text).notNull().defaults(to: "")
                t.column("fechaSolicitud", .text).notNull().defaults(to: "")
                t.column("iglesiaDestino", .text).notNull().defaults(to: "")
                t.column("estado", .text).notNull().defaults(to: "borrador")
                t.column("actualizadoEn", .text)
                t.column("borrado", .boolean).notNull().defaults(to: false)
            }
        }

        // **El folio de un documento lo da el servidor.** Cartas y actas lo
        // calculaban en el cliente, y así nacieron las cuatro actas con el
        // folio ACTA-2026-001 que hay en la base de la iglesia: dos aparatos
        // sin sincronizar calculan el mismo número. El contador de Postgres lo
        // entrega y lo reserva en un solo statement (migración
        // `20260907_folios_por_serie_y_anio`), como ya hacían los movimientos.
        //
        // Mientras el documento no ha subido lleva un folio PROVISIONAL, y esta
        // columna es la que lo dice. Es lo mismo que `movimiento.folioProvisional`
        // y por la misma razón: un número que todavía puede cambiar no se
        // imprime ni se cita.
        m.registerMigration("v24_folioProvisional") { db in
            for tabla in ["carta", "acta"] {
                try db.alter(table: tabla) { t in
                    t.add(column: "folioProvisional", .boolean).notNull().defaults(to: false)
                }
            }
        }

        return m
    }

    /// Vacía todo lo descargado. Se usa al cerrar sesión: los datos de una
    /// iglesia no pueden quedarse en el aparato para el siguiente que entre.
    ///
    /// **Se borran TODAS las tablas, sin lista a mano.** Aquí había una lista
    /// escrita tabla por tabla, y las que llegaron después —corte,
    /// corteMovimiento, deposito— se quedaron fuera: los cortes y depósitos
    /// de una iglesia seguían en el aparato después de cerrar sesión.
    /// Preguntarle al esquema qué tablas hay hace imposible olvidarse de la
    /// siguiente. Solo se salva `grdb_migrations`: borrarla haría que la
    /// próxima apertura intentara crear tablas que ya existen.
    func limpiar() throws {
        try cola.write { db in
            let tablas = try String.fetchAll(db, sql: """
                select name from sqlite_master
                where type = 'table'
                  and name not like 'sqlite_%'
                  and name not like 'grdb_%'
                """)
            for tabla in tablas {
                try db.execute(sql: "delete from \"\(tabla)\"")
            }
        }
        // Los recibos que aún no habían subido se quedaban en Application
        // Support sin ninguna fila que los nombrara: la foto del depósito de
        // una iglesia, huérfana, al alcance del siguiente que entre.
        if let carpeta = RecibosLocales.carpeta {
            try? FileManager.default.removeItem(at: carpeta)
        }
    }
}
