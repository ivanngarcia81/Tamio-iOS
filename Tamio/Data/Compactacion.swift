import Foundation
import GRDB

/// **Qué ocupa la base y qué hay dentro que ya no se usa.**
///
/// La fila "Compactar base de datos" de la Zona de riesgo decía *"La base ya
/// está compacta"* — siempre, sin haber mirado nada, y sin nada que tocar. La
/// frase podía ser verdad o no serlo; lo que no era es una medición.
///
/// **Lo que sí es cierto es el pie de esa sección**: *"lo que se borra queda
/// marcado hasta que se compacta"*. En Tamio el borrado es lógico —un `DELETE`
/// de verdad no se puede sincronizar, porque no queda nada que contarle al
/// servidor— y **nadie purga nunca**: no hay un solo borrado físico en la app.
/// Además, la bajada guarda las filas que el SERVIDOR marca como borradas, así
/// que la base acumula lo que ya no existe aunque desde este aparato no se
/// borre nada.
///
/// Esto solo mide. Purgar es el paso siguiente y tiene sus propias preguntas
/// —qué se hace con la bitácora del Registro, cuánto tiempo se conserva lo
/// borrado antes de que sea irreversible—, que no se contestan solas.
enum Compactacion {

    struct Estado {
        /// El archivo de la base, con su `-wal` y su `-shm`: los tres son la
        /// base. Mirar solo `tamio.sqlite` da una cifra menor que la real justo
        /// después de escribir mucho, que es cuando a uno le da por mirar.
        let bytesBase: Int64
        /// Filas marcadas como borradas que siguen ocupando sitio.
        let filasBorradas: Int
        /// De esas, las que ya no tienen nada pendiente de subir. Las otras NO
        /// se pueden tocar: purgar una baja que aún no viajó es la forma de que
        /// el servidor no se entere nunca.
        let filasPurgables: Int
        /// Espacio que SQLite ya tiene libre dentro del archivo y que solo un
        /// `VACUUM` devuelve al sistema.
        let bytesLibres: Int64
        /// Recibos de depósito en disco que ninguna fila reclama.
        let recibosHuerfanos: Int
        let bytesRecibosHuerfanos: Int64
        /// **Con qué clase de Data Protection está escrito `tamio.sqlite`.**
        /// `nil` en el simulador, que no la implementa — y por eso esta medida
        /// llevaba meses pendiente de "hacerla en un aparato".
        let proteccion: FileProtectionType?

        var hayAlgoQueLimpiar: Bool {
            filasBorradas > 0 || recibosHuerfanos > 0 || bytesLibres > 64 * 1024
        }
    }

    @MainActor
    static func medir() async -> Estado? {
        let base = BaseLocal.compartida
        guard !base.enMemoria else { return nil }

        let (borradas, purgables, libres, reclamados) = (try? await base.cola.read { db -> (Int, Int, Int64, Set<String>) in
            var borradas = 0
            var purgables = 0
            for tabla in try BorradoMasivo.tablasConBorrado(db) {
                borradas += try Int.fetchOne(db, sql: """
                    select count(*) from "\(tabla)" where borrado = 1
                    """) ?? 0
                // Se cruza por `registroId` y no por entidad: los identificadores
                // son únicos entre tablas, y así la cuenta no depende de que el
                // mapa de entidades esté al día.
                purgables += try Int.fetchOne(db, sql: """
                    select count(*) from "\(tabla)" t
                    where t.borrado = 1
                      and not exists (select 1 from outbox o where o.registroId = t.id)
                    """) ?? 0
            }
            let paginas = try Int.fetchOne(db, sql: "pragma freelist_count") ?? 0
            let tamanoPagina = try Int.fetchOne(db, sql: "pragma page_size") ?? 0
            let reclamados = Set(try String.fetchAll(db, sql: """
                select archivoLocal from deposito where archivoLocal is not null
                """))
            return (borradas, purgables, Int64(paginas * tamanoPagina), reclamados)
        }) ?? (0, 0, 0, [])

        let (huerfanos, bytesHuerfanos) = recibosSueltos(reclamados)
        return Estado(bytesBase: bytesDeLaBase(),
                      filasBorradas: borradas,
                      filasPurgables: purgables,
                      bytesLibres: libres,
                      recibosHuerfanos: huerfanos,
                      bytesRecibosHuerfanos: bytesHuerfanos,
                      proteccion: proteccionDeLaBase())
    }

    /// La clase de protección REAL del archivo, preguntada al sistema.
    ///
    /// Es una de las dos medidas que el traspaso lleva pidiendo para poder
    /// decidir sobre el cifrado local (§5, `docs/CIFRADO-LOCAL.md`), y no se
    /// podía tomar en el simulador: allí Data Protection no está implementada y
    /// el atributo viene vacío, que no es lo mismo que "sin protección".
    static func proteccionDeLaBase() -> FileProtectionType? {
        let fm = FileManager.default
        guard let carpeta = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: false),
              let atributos = try? fm.attributesOfItem(
                  atPath: carpeta.appendingPathComponent("tamio.sqlite").path)
        else { return nil }
        return atributos[.protectionKey] as? FileProtectionType
    }

    /// **Huérfano es el que NADIE reclama**, ni siquiera un depósito ya
    /// borrado. Contar como sobrante el recibo de un depósito dado de baja
    /// sería contar de más: mientras su fila siga en la base, ese archivo tiene
    /// dueño, y el papel del banco no se puede volver a fotografiar.
    private static func recibosSueltos(_ reclamados: Set<String>) -> (Int, Int64) {
        let fm = FileManager.default
        guard let carpeta = RecibosLocales.carpeta,
              let archivos = try? fm.contentsOfDirectory(
                  at: carpeta, includingPropertiesForKeys: [.fileSizeKey]) else { return (0, 0) }
        var n = 0
        var bytes: Int64 = 0
        for a in archivos where !reclamados.contains(a.lastPathComponent) {
            n += 1
            bytes += Int64((try? a.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return (n, bytes)
    }

    private static func bytesDeLaBase() -> Int64 {
        let fm = FileManager.default
        guard let carpeta = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: false) else { return 0 }
        return ["tamio.sqlite", "tamio.sqlite-wal", "tamio.sqlite-shm"].reduce(0) { total, nombre in
            let ruta = carpeta.appendingPathComponent(nombre).path
            let bytes = (try? fm.attributesOfItem(atPath: ruta)[.size] as? Int64) ?? 0
            return total + (bytes ?? 0)
        }
    }

    /// La clase de protección, en una frase que diga qué significa. El nombre
    /// crudo (`NSFileProtectionCompleteUntilFirstUserAuthentication`) no le
    /// dice a nadie cuándo se puede leer el archivo, que es la pregunta.
    static func proteccionLegible(_ p: FileProtectionType?) -> String {
        switch p {
        case .some(.complete):
            return L.t("Completa · solo se puede leer con el aparato desbloqueado",
                       "Complete · readable only while the device is unlocked")
        case .some(.completeUnlessOpen):
            return L.t("Completa salvo si ya estaba abierto",
                       "Complete unless already open")
        case .some(.completeUntilFirstUserAuthentication):
            return L.t("Hasta el primer desbloqueo · protegida mientras nadie haya desbloqueado desde que se encendió",
                       "Until first unlock · protected until someone unlocks the device after a reboot")
        case .some(.none):
            return L.t("Ninguna · el archivo se puede leer con el aparato bloqueado",
                       "None · the file can be read while the device is locked")
        default:
            return L.t("No se puede saber aquí · el simulador no implementa Data Protection",
                       "Can't be determined here · the simulator doesn't implement Data Protection")
        }
    }

    static func legible(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: bytes)
    }
}

extension Compactacion.Estado {
    /// La frase que va bajo el título, con lo que se midió y nada más.
    ///
    /// **No promete limpiar**, porque todavía no hay con qué: decir "se pueden
    /// recuperar 3 MB" al lado de una fila sin botón sería cambiar una frase
    /// falsa por otra. Dice lo que hay; el pie de la sección ya explica que lo
    /// borrado queda marcado.
    var resumen: String {
        let tamano = Compactacion.legible(bytesBase)
        guard hayAlgoQueLimpiar else {
            return L.t("La base ocupa \(tamano) y no hay nada guardado de más.",
                       "The database takes \(tamano) and holds nothing extra.")
        }
        var partes: [String] = []
        if filasBorradas > 0 {
            partes.append(filasBorradas == 1
                ? L.t("1 registro borrado sigue guardado",
                      "1 deleted record is still stored")
                : L.t("\(filasBorradas) registros borrados siguen guardados",
                      "\(filasBorradas) deleted records are still stored"))
        }
        if recibosHuerfanos > 0 {
            let peso = Compactacion.legible(bytesRecibosHuerfanos)
            partes.append(recibosHuerfanos == 1
                ? L.t("1 recibo (\(peso)) que ningún depósito reclama",
                      "1 receipt (\(peso)) no deposit claims")
                : L.t("\(recibosHuerfanos) recibos (\(peso)) que ningún depósito reclama",
                      "\(recibosHuerfanos) receipts (\(peso)) no deposit claims"))
        }
        if bytesLibres > 64 * 1024 {
            partes.append(L.t("\(Compactacion.legible(bytesLibres)) libres dentro del archivo",
                              "\(Compactacion.legible(bytesLibres)) free inside the file"))
        }
        return L.t("La base ocupa \(tamano). Dentro: \(partes.joined(separator: ", ")).",
                   "The database takes \(tamano). Inside: \(partes.joined(separator: ", ")).")
    }
}
