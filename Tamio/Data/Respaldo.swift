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

        var errorDescription: String? {
            switch self {
            case .sinBase:
                return L.t("La base de datos de este aparato no está disponible.",
                           "This device's database isn't available.")
            case .noSePudoEmpaquetar:
                return L.t("No se pudo armar el archivo de respaldo.",
                           "The backup file couldn't be created.")
            }
        }
    }

    /// Arma el paquete y devuelve su URL, lista para la hoja de compartir.
    ///
    /// Se hace fuera del hilo principal: `VACUUM INTO` y comprimir una carpeta
    /// con fotos tardan lo suyo, y bloquear la interfaz en el botón que dice
    /// "tarda unos segundos" sería quedarse corto.
    static func crear() async throws -> URL {
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

        return try comprimir(carpeta, nombre: nombre)
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
