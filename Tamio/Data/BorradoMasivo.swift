import Foundation
import GRDB

/// **Las dos operaciones de la Zona de riesgo que no se podían encender.**
///
/// El pie de esa pantalla lo decía: *"Borrar y reiniciar se encienden cuando
/// exista la restauración: hoy no habría a dónde volver"*. Ya existe
/// (`Respaldo.restaurar`), así que aquí está lo que hacen.
///
/// Son dos cosas distintas y conviene no confundirlas:
///
/// - **Borrar los registros** se PROPAGA. Marca cada fila como borrada y encola
///   su baja, igual que borrar un movimiento a mano, así que el resto de los
///   aparatos de la iglesia se enteran. La configuración se conserva.
/// - **El reinicio de fábrica** es de ESTE aparato y no viaja. Vacía la base,
///   las carpetas y las preferencias, y cierra la sesión: la app queda como
///   recién instalada. Lo que hay en el servidor sigue ahí y vuelve a bajar en
///   cuanto alguien entre.
enum BorradoMasivo {

    /// **Tabla local → entidad de sincronización.** Sale de leer qué encola
    /// cada repositorio, no de suponerlo: `OfflineMovimientosRepository` encola
    /// "movimiento", `ServiciosRepository` encola "culto" para la tabla
    /// `servicio`, y así. Escribir mal una sola deja filas borradas en el
    /// teléfono que el siguiente `sync` vuelve a bajar.
    static let entidades: [String: String] = [
        "movimiento":           "movimiento",
        // La misma tabla que usan Aportantes y Membresía, y la misma fila
        // remota (`members`): con encolar una entidad basta.
        "aportante":            "aportante",
        "parentesco":           "parentesco",
        "servicio":             "culto",
        "servicioAsistencia":   "asistencia",
        "servicioPuesto":       "puesto",
        "servicioOrden":        "orden",
        "agenda":               "evento",
        "acta":                 "acta",
        "carta":                "carta",
        "registro":             "apunte",
        "corte":                "corte",
        "corteMovimiento":      "corteMovimiento",
        "deposito":             "deposito",
        "categoriaCustom":      "categoriaCustom",
        "movimientoRecurrente": "movimientoRecurrente",
    ]

    /// Tablas que se borran pero no viajan: hoy nadie las sube. Están aquí
    /// escritas para que la prueba que comprueba la cobertura pueda distinguir
    /// "no viaja" de "se me olvidó".
    static let soloLocales: Set<String> = ["trasladoSalida", "plantilla"]

    /// La configuración de la iglesia, que el borrado conserva a propósito: el
    /// membrete, las firmas y los permisos no son registros.
    static let seConserva: Set<String> = ["iglesia", "outbox", "syncEstado"]

    /// **Borra todos los registros y encola sus bajas.**
    ///
    /// Borrado lógico, como el de una fila suelta: un `DELETE` de verdad no se
    /// puede sincronizar, porque no queda nada que contarle al servidor.
    /// Devuelve cuántas filas se dieron de baja.
    @discardableResult
    static func borrarRegistros() async throws -> Int {
        let base = BaseLocal.compartida
        guard !base.enMemoria else { throw Respaldo.Fallo.sinBase }

        return try await base.cola.write { db in
            var total = 0
            for tabla in try tablasConBorrado(db) {
                guard !seConserva.contains(tabla) else { continue }
                let ids = try String.fetchAll(db, sql: """
                    select id from "\(tabla)" where borrado = 0
                    """)
                guard !ids.isEmpty else { continue }
                try db.execute(sql: "update \"\(tabla)\" set borrado = 1 where borrado = 0")
                total += ids.count

                guard let entidad = entidades[tabla] else { continue }
                for id in ids {
                    // Se limpia lo que hubiera pendiente de esa fila antes de
                    // encolar la baja: subir una creación y acto seguido su
                    // borrado es trabajo doble para dejar lo mismo.
                    try OperacionPendiente
                        .filter(Column("entidad") == entidad && Column("registroId") == id)
                        .deleteAll(db)
                    var op = OperacionPendiente(
                        id: nil, entidad: entidad, registroId: id,
                        operacion: OperacionPendiente.Operacion.eliminar.rawValue,
                        creadoEn: Date().timeIntervalSince1970,
                        intentos: 0, ultimoError: nil)
                    try op.insert(db)
                }
            }
            return total
        }
    }

    /// **Reinicio de fábrica.** Este aparato y nada más.
    ///
    /// No encola nada, y es la diferencia con lo de arriba: el que reinicia
    /// quiere dejar el teléfono limpio —lo presta, lo devuelve, lo cambia—, no
    /// vaciarle las cuentas a la congregación entera desde su pantalla.
    @MainActor
    static func reinicioDeFabrica() async throws {
        try BaseLocal.compartida.limpiar()

        // Las carpetas de archivos, que no viven en la base.
        let fm = FileManager.default
        for carpeta in [FirmasLocales.carpeta, RecibosLocales.carpeta] {
            guard let carpeta,
                  let archivos = try? fm.contentsOfDirectory(at: carpeta,
                                                             includingPropertiesForKeys: nil)
            else { continue }
            for a in archivos { try? fm.removeItem(at: a) }
        }
        FirmasLocales.compartidas.releer()
        await LogoIglesia.compartido.quitarLocal()

        // Las preferencias de este aparato: el tema, el idioma, el candado y la
        // fecha del último respaldo. Se borran por prefijo conocido y no
        // vaciando el dominio entero, que se llevaría por delante lo que
        // guardan las SDK de Apple y de Supabase.
        for clave in PreferenciasApp.claves + ["respaldo.ultimo"] {
            UserDefaults.standard.removeObject(forKey: clave)
        }

        await ConfiguracionIglesiaViewModel.compartido.recargar()
    }

    /// Las tablas del esquema que llevan borrado lógico. **Se le pregunta a la
    /// base**, no se escriben a mano: es lo mismo que hace `BaseLocal.limpiar`,
    /// y por lo mismo — una tabla nueva no puede quedarse fuera por olvido.
    static func tablasConBorrado(_ db: Database) throws -> [String] {
        try String.fetchAll(db, sql: """
            select m.name from sqlite_master m
            where m.type = 'table'
              and m.name not like 'sqlite_%' and m.name not like 'grdb_%'
              and exists (select 1 from pragma_table_info(m.name) c where c.name = 'borrado')
            order by m.name
            """)
    }
}
