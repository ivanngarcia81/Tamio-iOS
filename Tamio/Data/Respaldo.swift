import Foundation
import GRDB

/// **El respaldo completo: la base y los recibos, en un archivo.**
///
/// El botón "Respaldar ahora" no respaldaba nada. En el iPad escribía "Hoy
/// 9:41" en la línea de al lado y en el teléfono estaba apagado, los dos justo
/// debajo de un texto que dice que un respaldo es lo único que puede devolver
/// lo que se pierda.
///
/// Tres decisiones que no son obvias:
///
/// - **La base se copia con `VACUUM INTO`, no con `FileManager.copyItem`.**
///   SQLite en modo WAL guarda los últimos cambios en un archivo `-wal` aparte;
///   copiar solo `tamio.sqlite` daría un respaldo sin lo más reciente, que es
///   exactamente lo que más falta hace recuperar. `VACUUM INTO` escribe una
///   copia limpia y consistente en un solo archivo, con el WAL ya incorporado.
/// - **Van los recibos del banco.** Son la única prueba de que el dinero llegó
///   a la cuenta y algunos ni siquiera han subido todavía: un respaldo sin
///   ellos deja fuera lo que no se puede volver a fotografiar.
/// - **Se escribe un manifiesto.** Nombre de la iglesia, fecha y cuántos
///   movimientos, aportantes y depósitos trae. Es lo que tendrá que leer la
///   restauración para poder enseñar QUÉ contiene el paquete antes de
///   reemplazar nada: la app web descubrió que un "¿seguro?" genérico no deja
///   ver que el archivo elegido es de otra congregación.
enum Respaldo {

    struct Manifiesto: Codable {
        let version: Int
        let iglesia: String
        let creadoEn: String
        let app: String
        let movimientos: Int
        let aportantes: Int
        let depositos: Int
        let recibos: Int
    }

    enum Fallo: LocalizedError {
        case sinBase
        case noSePudoEmpaquetar
        case sinManifiesto
        case versionDesconocida(Int)
        case masNuevoQueLaApp

        var errorDescription: String? {
            switch self {
            case .sinBase:
                return L.t("La base de datos de este aparato no está disponible.",
                           "This device's database isn't available.")
            case .noSePudoEmpaquetar:
                return L.t("No se pudo armar el archivo de respaldo.",
                           "The backup file couldn't be created.")
            case .sinManifiesto:
                return L.t("Ese archivo no es un respaldo de Tamio: le falta el manifiesto.",
                           "That file isn't a Tamio backup: the manifest is missing.")
            case .versionDesconocida(let v):
                return L.t("El respaldo es de un formato que esta versión no conoce (v\(v)).",
                           "The backup uses a format this version doesn't know (v\(v)).")
            case .masNuevoQueLaApp:
                return L.t("El respaldo se hizo con una versión más nueva de Tamio. Actualiza la app antes de restaurarlo.",
                           "The backup was made with a newer version of Tamio. Update the app before restoring it.")
            }
        }
    }

    /// Arma el paquete y devuelve su URL, lista para la hoja de compartir.
    ///
    /// Se hace fuera del hilo principal: `VACUUM INTO` y comprimir una carpeta
    /// con fotos tardan lo suyo, y bloquear la interfaz en el botón que dice
    /// "tarda unos segundos" sería quedarse corto.
    static func crear(protegidoCon contrasena: String? = nil) async throws -> URL {
        let base = BaseLocal.compartida
        guard !base.enMemoria else { throw Fallo.sinBase }

        let fm = FileManager.default
        let nombre = "tamio-\(CSV.fecha(Date()))"
        let carpeta = fm.temporaryDirectory.appendingPathComponent(nombre, isDirectory: true)
        // Si quedó uno de un intento anterior, fuera: mezclar dos respaldos en
        // la misma carpeta daría un paquete con recibos de dos momentos.
        try? fm.removeItem(at: carpeta)
        try fm.createDirectory(at: carpeta, withIntermediateDirectories: true)

        let destino = carpeta.appendingPathComponent("tamio.sqlite")
        // `writeWithoutTransaction` y no `write`: SQLite rechaza un VACUUM
        // dentro de una transacción ("cannot VACUUM from within a
        // transaction"), y `write` abre una siempre. No se pierde nada por
        // ello: `VACUUM INTO` toma su propia instantánea coherente.
        try await base.cola.writeWithoutTransaction { db in
            // La ruta va entre comillas simples y con las internas duplicadas:
            // el directorio temporal lleva el identificador del contenedor y no
            // se puede meter en el SQL sin escapar.
            let ruta = destino.path.replacingOccurrences(of: "'", with: "''")
            try db.execute(sql: "vacuum into '\(ruta)'")
        }
        let conteos = try await base.cola.read { db -> (Int, Int, Int) in
            (try Int.fetchOne(db, sql: "select count(*) from movimiento where borrado = 0") ?? 0,
             try Int.fetchOne(db, sql: "select count(*) from aportante where borrado = 0") ?? 0,
             try Int.fetchOne(db, sql: "select count(*) from deposito where borrado = 0") ?? 0)
        }

        // Las firmas, junto a los recibos. La app web anotó justo esto como
        // fallo suyo: la firma quedaba fuera del paquete, y restaurar en otra
        // máquina dejaba todos los documentos sin firmar y sin avisar.
        if let origen = await FirmasLocales.carpeta,
           let archivos = try? fm.contentsOfDirectory(at: origen, includingPropertiesForKeys: nil),
           !archivos.isEmpty {
            let dir = carpeta.appendingPathComponent("firmas", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for archivo in archivos {
                try? fm.copyItem(at: archivo, to: dir.appendingPathComponent(archivo.lastPathComponent))
            }
        }

        var recibos = 0
        if let origen = RecibosLocales.carpeta,
           let archivos = try? fm.contentsOfDirectory(at: origen, includingPropertiesForKeys: nil),
           !archivos.isEmpty {
            let dir = carpeta.appendingPathComponent("recibos", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for archivo in archivos {
                try? fm.copyItem(at: archivo, to: dir.appendingPathComponent(archivo.lastPathComponent))
                recibos += 1
            }
        }

        let iglesia = await ConfiguracionIglesiaViewModel.compartido.config.nombre
        let manifiesto = Manifiesto(
            version: 1,
            iglesia: iglesia,
            creadoEn: ISO8601DateFormatter().string(from: Date()),
            app: VersionApp.completa,
            movimientos: conteos.0, aportantes: conteos.1, depositos: conteos.2,
            recibos: recibos)
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        try codificador.encode(manifiesto)
            .write(to: carpeta.appendingPathComponent("respaldo.json"))

        let zip = try comprimir(carpeta, nombre: nombre)
        guard let contrasena, !contrasena.isEmpty else { return zip }

        // **Con contraseña, el paquete deja de ser un zip.** Se cifra entero y
        // se le cambia la extensión: un archivo que ya no se abre con doble
        // clic no debe llamarse `.zip`, o el primer chasco lo llevará quien
        // intente abrirlo justo el día que hace falta.
        let cifrado = try RespaldoCifrado.cifrar(try Data(contentsOf: zip), con: contrasena)
        let salida = zip.deletingPathExtension().appendingPathExtension("tamiobk")
        try? FileManager.default.removeItem(at: salida)
        try cifrado.write(to: salida, options: .atomic)
        try? FileManager.default.removeItem(at: zip)
        return salida
    }

    /// Comprime una carpeta en un `.zip` **sin librerías**.
    ///
    /// `NSFileCoordinator` con la opción `.forUploading` entrega una copia
    /// comprimida de un directorio: es el mismo mecanismo que usa el sistema
    /// para adjuntar una carpeta en Mail. Se copia fuera del bloque porque el
    /// archivo que da vive solo mientras dura el coordinador.
    private static func comprimir(_ carpeta: URL, nombre: String) throws -> URL {
        let fm = FileManager.default
        let salida = fm.temporaryDirectory.appendingPathComponent("\(nombre).zip")
        try? fm.removeItem(at: salida)

        var error: NSError?
        var fallo: Error?
        NSFileCoordinator().coordinate(readingItemAt: carpeta,
                                       options: [.forUploading],
                                       error: &error) { temporal in
            do { try fm.copyItem(at: temporal, to: salida) } catch { fallo = error }
        }
        if let fallo { throw fallo }
        if error != nil { throw Fallo.noSePudoEmpaquetar }
        // La carpeta suelta ya no hace falta: lo que se comparte es el zip.
        try? fm.removeItem(at: carpeta)
        return salida
    }

    // MARK: - Restaurar

    /// **Lee el paquete sin tocar nada.** Es lo que la hoja de confirmación
    /// enseña antes de reemplazar: de qué iglesia es, de cuándo y qué trae.
    ///
    /// Existe separado de `restaurar` a propósito, y es la razón por la que
    /// `crear` escribe un manifiesto: la app web descubrió que un "¿seguro?"
    /// genérico no deja ver que el archivo elegido es de otra congregación.
    static func inspeccionar(_ paquete: URL, contrasena: String? = nil) async throws -> Manifiesto {
        let carpeta = try desempaquetar(paquete, contrasena: contrasena)
        defer { try? FileManager.default.removeItem(at: carpeta) }
        return try leerManifiesto(carpeta)
    }

    /// **Reemplaza el contenido de la base por el del respaldo.**
    ///
    /// No sustituye el archivo `tamio.sqlite`, que es lo primero que uno
    /// piensa: hay una `DatabaseQueue` abierta encima de él durante toda la
    /// vida de la app —`BaseLocal.compartida.cola` es `let`— y cambiar el
    /// archivo por debajo de un handle abierto es la forma de quedarse sin las
    /// dos bases. Se hace con `ATTACH` y una transacción: o entra todo, o no
    /// entra nada y el aparato se queda como estaba.
    ///
    /// **Tabla por tabla y columna por columna, no `select *`.** Un respaldo de
    /// hace dos versiones tiene menos columnas que la base de hoy; copiar por
    /// posición pondría el teléfono de una persona en su dirección. Se cruzan
    /// los nombres y lo que no venga en el respaldo se queda con su valor por
    /// omisión, que es lo que hizo la migración cuando esa columna nació.
    ///
    /// Al revés no vale: si el respaldo trae migraciones que esta app no
    /// conoce, se rechaza. Restaurar quitando columnas es perder datos sin
    /// decirlo.
    static func restaurar(_ paquete: URL, contrasena: String? = nil) async throws -> Manifiesto {
        let base = BaseLocal.compartida
        guard !base.enMemoria else { throw Fallo.sinBase }

        let carpeta = try desempaquetar(paquete, contrasena: contrasena)
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let manifiesto = try leerManifiesto(carpeta)

        let sqlite = carpeta.appendingPathComponent("tamio.sqlite")
        guard FileManager.default.fileExists(atPath: sqlite.path) else {
            throw Fallo.sinManifiesto
        }
        try comprobarMigraciones(sqlite)

        try await base.cola.writeWithoutTransaction { db in
            try db.execute(sql: "attach database ? as respaldo", arguments: [sqlite.path])
            do {
                try db.inTransaction {
                    // El orden no importa porque las claves foráneas se
                    // apagan mientras dura: las tablas se vacían todas antes
                    // de rellenarse, y a media faena cualquier orden viola
                    // alguna referencia.
                    try db.execute(sql: "pragma defer_foreign_keys = on")
                    for tabla in try Self.tablas(db, esquema: "main") {
                        guard try Self.existe(db, tabla: tabla, esquema: "respaldo") else { continue }
                        let columnas = try Self.columnasComunes(db, tabla: tabla)
                        guard !columnas.isEmpty else { continue }
                        let lista = columnas.map { "\"\($0)\"" }.joined(separator: ", ")
                        try db.execute(sql: "delete from main.\"\(tabla)\"")
                        try db.execute(sql: """
                            insert into main."\(tabla)" (\(lista))
                            select \(lista) from respaldo."\(tabla)"
                            """)
                    }
                    // **Y todo lo recuperado se vuelve a encolar.**
                    //
                    // Sin esto, restaurar solo arregla el aparato: el servidor
                    // sigue con lo que tuviera, y la PRIMERA sincronización se
                    // lo baja encima y deshace la restauración. Visto en el
                    // aparato el 7 de septiembre de 2026, después de borrarlo
                    // todo y recuperarlo — el teléfono quedó con sus 28
                    // movimientos y el servidor con los 66 marcados de baja,
                    // esperando a pisárselos.
                    //
                    // Se encola como ACTUALIZACIÓN, no como alta: el servidor
                    // conserva las filas con su `deleted` puesto, así que un
                    // update las resucita sin tocar nada más. Un alta, en
                    // cambio, le pediría al contador de Postgres un folio nuevo
                    // y cada movimiento recuperado cambiaría de número.
                    try Self.reencolar(db)
                    return .commit
                }
            } catch {
                try? db.execute(sql: "detach database respaldo")
                throw error
            }
            try db.execute(sql: "detach database respaldo")
        }

        // Las firmas y los recibos van fuera de la base, así que se copian
        // aparte. **Se añaden, no se reemplazan**: un recibo que este aparato
        // tiene y el respaldo no es una foto que nadie puede volver a hacer.
        copiarCarpeta(carpeta.appendingPathComponent("recibos"), a: RecibosLocales.carpeta)

        // Lo que vive en memoria tiene que enterarse: la configuración de la
        // iglesia y las firmas son singletons y se quedarían con lo de antes.
        await MainActor.run {
            copiarCarpeta(carpeta.appendingPathComponent("firmas"), a: FirmasLocales.carpeta)
            FirmasLocales.compartidas.releer()
        }
        await ConfiguracionIglesiaViewModel.compartido.recargar()
        return manifiesto
    }

    // MARK: - Piezas de la restauración

    private static func desempaquetar(_ paquete: URL, contrasena: String? = nil) throws -> URL {
        // El selector de archivos entrega una URL fuera del sandbox; sin pedir
        // acceso explícito, la lectura falla. Es lo mismo que hace
        // `SupabaseComprobantesStorage.subir`.
        let concedido = paquete.startAccessingSecurityScopedResource()
        defer { if concedido { paquete.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        var origen = paquete
        // **Se mira la MARCA del archivo, no su extensión**: el nombre lo puede
        // cambiar cualquiera al guardarlo, y un respaldo protegido que llegue
        // llamándose `.zip` tiene que seguir pidiendo su contraseña.
        let crudo = try Data(contentsOf: paquete)
        if RespaldoCifrado.estaCifrado(crudo) {
            let claro = try RespaldoCifrado.descifrar(crudo, con: contrasena ?? "")
            origen = fm.temporaryDirectory.appendingPathComponent("abierto-\(UUID().uuidString).zip")
            try claro.write(to: origen, options: .atomic)
        }

        let destino = fm.temporaryDirectory
            .appendingPathComponent("restaurar-\(UUID().uuidString)", isDirectory: true)
        defer { if origen != paquete { try? fm.removeItem(at: origen) } }
        try ZipLectura.extraer(origen, a: destino)
        return raizDelPaquete(destino)
    }

    /// ¿Este paquete pide contraseña? Lo usa la pantalla para preguntarla antes
    /// de intentar nada, en vez de fallar y volver a empezar.
    static func pideContrasena(_ paquete: URL) -> Bool {
        let concedido = paquete.startAccessingSecurityScopedResource()
        defer { if concedido { paquete.stopAccessingSecurityScopedResource() } }
        guard let datos = try? Data(contentsOf: paquete) else { return false }
        return RespaldoCifrado.estaCifrado(datos)
    }

    /// **El zip envuelve todo en una carpeta con su propio nombre.** Es lo que
    /// hace `NSFileCoordinator` al comprimir un directorio —y lo que se ve al
    /// descomprimirlo en cualquier ordenador: sale `tamio-2026-09-07/`, no los
    /// archivos sueltos—, así que buscar `respaldo.json` en la raíz de lo
    /// extraído no encontraba nada. Y el fallo no era ruidoso: la base
    /// inexistente se abría como una base VACÍA, que es lo peor que puede
    /// pasarle a una restauración.
    private static func raizDelPaquete(_ carpeta: URL) -> URL {
        let fm = FileManager.default
        guard let dentro = try? fm.contentsOfDirectory(at: carpeta,
                                                       includingPropertiesForKeys: [.isDirectoryKey]),
              dentro.count == 1,
              (try? dentro[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { return carpeta }
        return dentro[0]
    }

    private static func leerManifiesto(_ carpeta: URL) throws -> Manifiesto {
        let url = carpeta.appendingPathComponent("respaldo.json")
        guard let datos = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(Manifiesto.self, from: datos) else {
            throw Fallo.sinManifiesto
        }
        guard m.version == 1 else { throw Fallo.versionDesconocida(m.version) }
        return m
    }

    /// Que el respaldo no traiga migraciones que esta app no sabe aplicar.
    private static func comprobarMigraciones(_ sqlite: URL) throws {
        let conocidas = Set(BaseLocal.migrador.migrations)
        let cola = try DatabaseQueue(path: sqlite.path)
        let suyas = try cola.read { db -> [String] in
            let hay = try Bool.fetchOne(db, sql: """
                select count(*) > 0 from sqlite_master
                where type = 'table' and name = 'grdb_migrations'
                """) ?? false
            guard hay else { return [] }
            return try String.fetchAll(db, sql: "select identifier from grdb_migrations")
        }
        if !Set(suyas).subtracting(conocidas).isEmpty { throw Fallo.masNuevoQueLaApp }
    }

    /// Deja en la cola una subida por cada fila viva de lo restaurado.
    ///
    /// **La cola del respaldo se tira primero**: viaja dentro del paquete como
    /// una tabla más, y lo que llevara pendiente el aparato el día que se
    /// respaldó no tiene por qué ser lo que hace falta subir hoy.
    ///
    /// Lo que no viaja no se encola: las tablas sin entidad de sincronización
    /// —`trasladoSalida`, `plantilla`— se quedan solo en el aparato, que es
    /// donde ya estaban.
    @discardableResult
    static func reencolar(_ db: Database) throws -> Int {
        try db.execute(sql: "delete from outbox")
        var total = 0
        for (tabla, entidad) in BorradoMasivo.entidades.sorted(by: { $0.key < $1.key }) {
            guard try existe(db, tabla: tabla, esquema: "main") else { continue }
            let ids = try String.fetchAll(db, sql: "select id from \"\(tabla)\" where borrado = 0")
            for id in ids {
                var op = OperacionPendiente(
                    id: nil, entidad: entidad, registroId: id,
                    operacion: OperacionPendiente.Operacion.actualizar.rawValue,
                    creadoEn: Date().timeIntervalSince1970,
                    intentos: 0, ultimoError: nil)
                try op.insert(db)
                total += 1
            }
        }
        return total
    }

    private static func tablas(_ db: Database, esquema: String) throws -> [String] {
        try String.fetchAll(db, sql: """
            select name from \(esquema).sqlite_master
            where type = 'table' and name not like 'sqlite_%' and name not like 'grdb_%'
            """)
    }

    private static func existe(_ db: Database, tabla: String, esquema: String) throws -> Bool {
        try Bool.fetchOne(db, sql: """
            select count(*) > 0 from \(esquema).sqlite_master
            where type = 'table' and name = ?
            """, arguments: [tabla]) ?? false
    }

    private static func columnasComunes(_ db: Database, tabla: String) throws -> [String] {
        let aqui = try String.fetchAll(db, sql: "select name from pragma_table_info(?)",
                                       arguments: [tabla])
        let alla = try String.fetchAll(db, sql: "select name from pragma_table_info(?, 'respaldo')",
                                       arguments: [tabla])
        let disponibles = Set(alla)
        return aqui.filter { disponibles.contains($0) }
    }

    private static func copiarCarpeta(_ origen: URL, a destino: URL?) {
        let fm = FileManager.default
        guard let destino,
              let archivos = try? fm.contentsOfDirectory(at: origen,
                                                         includingPropertiesForKeys: nil) else { return }
        for archivo in archivos {
            let salida = destino.appendingPathComponent(archivo.lastPathComponent)
            try? fm.removeItem(at: salida)
            try? fm.copyItem(at: archivo, to: salida)
        }
    }

    // MARK: - Cuándo fue el último

    /// La fecha del último respaldo hecho desde este aparato. Va en
    /// `UserDefaults` y no en la base: es de este teléfono, no de la iglesia, y
    /// dos aparatos de la misma congregación respaldan por su cuenta.
    ///
    /// Ojo con lo que significa: que el paquete se armó y se ofreció para
    /// guardar. Si quien lo compartió cerró la hoja sin elegir dónde, la app no
    /// se entera — el sistema no lo cuenta. Por eso la fila dice "último
    /// respaldo preparado" y no "guardado".
    private static let clave = "respaldo.ultimo"

    static var ultimo: Date? {
        let t = UserDefaults.standard.double(forKey: clave)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static func anotarHecho() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: clave)
    }

    static var ultimoLegible: String {
        guard let ultimo else { return L.t("Ninguno", "None") }
        let f = DateFormatter()
        f.locale = L.locale
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: ultimo)
    }
}


/// **Los CSV de "Exportar a un archivo".**
///
/// Las columnas son literalmente las de la app web (`movimientosToCsv`), no
/// unas parecidas: el CSV existe para poder abrirlo en Excel, editarlo y
/// volverlo a importar, y dos programas de la misma casa con dos formatos
/// obligarían a elegir cuál de los dos hizo el archivo.
///
/// Los importes van en DECIMALES y no en centavos, también como allí: este
/// archivo lo lee gente.
enum ExportadorMovimientos {

    static let columnas = [
        "fecha", "tipo", "categoria", "concepto", "monto", "metodo_pago",
        "beneficiario", "notas", "hora", "subcategoria", "miembro", "estado",
    ]

    static func csv(_ lista: [Movimiento]) -> URL? {
        // De lo más nuevo a lo más viejo, como la pantalla: un archivo que
        // empieza por el movimiento de hace dos años se lee al revés.
        let filas = lista.sorted { $0.fecha > $1.fecha }.map { m -> [String] in
            // `categoriaCompleta` es "Diezmo · Sobre": la subcategoría es lo
            // que va detrás del punto medio, y va en su propia columna.
            let partes = m.categoriaCompleta.components(separatedBy: " · ")
            let subcategoria = partes.count > 1 ? partes.dropFirst().joined(separator: " · ") : ""
            return [
                CSV.fecha(m.fecha),
                m.tipo == .ingreso ? "ingreso" : "gasto",
                m.categoria,
                m.persona ?? "",
                CSV.importe(m.monto),
                m.metodo,
                m.pagadoA ?? "",
                m.nota ?? "",
                m.hora,
                subcategoria,
                m.miembro ?? "",
                m.estadoRevision.rawValue,
            ]
        }
        return CSV.archivo(nombre: "movimientos-\(CSV.fecha(Date()))",
                           encabezados: columnas, filas: filas)
    }
}


/// **El manifiesto de un respaldo, en una frase.** Es lo que enseña la
/// confirmación antes de reemplazar nada, y lo enseñan las dos pantallas: un
/// "¿seguro?" genérico no deja ver que el archivo elegido es de otra
/// congregación, que es el fallo que la app web ya cometió.
enum ResumenRespaldo {
    static func frase(_ m: Respaldo.Manifiesto) -> String {
        let iso = ISO8601DateFormatter()
        let salida = DateFormatter()
        salida.locale = L.locale
        salida.dateStyle = .medium
        salida.timeStyle = .short
        let cuando = iso.date(from: m.creadoEn).map { salida.string(from: $0) } ?? m.creadoEn
        let iglesia = m.iglesia.isEmpty ? L.t("Sin nombre", "Unnamed") : m.iglesia
        return L.t("""
            \(iglesia) · \(cuando)
            \(m.movimientos) movimientos, \(m.aportantes) aportantes, \(m.depositos) depósitos y \(m.recibos) recibos.

            Se reemplaza todo lo capturado después de esa fecha.
            """, """
            \(iglesia) · \(cuando)
            \(m.movimientos) transactions, \(m.aportantes) contributors, \(m.depositos) deposits, and \(m.recibos) receipts.

            Everything captured after that date will be replaced.
            """)
    }
}
