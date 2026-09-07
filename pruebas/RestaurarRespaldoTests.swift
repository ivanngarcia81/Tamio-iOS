import GRDB
import XCTest
@testable import Tamio

/// **La ida y la vuelta de un respaldo.**
///
/// "Restaurar un respaldo" llevaba desde siempre en "Próximamente", y con él
/// bloqueados "Borrar todos los registros" y "Reinicio de fábrica" — el pie de
/// la Zona de riesgo lo decía: *se encienden cuando exista la restauración,
/// hoy no habría a dónde volver*.
///
/// Estas pruebas son lo único que puede decir que la vuelta funciona sin
/// arriesgar datos de nadie: se respalda, se estropea la base a propósito y se
/// restaura.
final class RestaurarRespaldoTests: XCTestCase {

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    private func escribirIglesia(_ nombre: String) throws {
        try cola.write { db in
            try db.execute(sql: """
                insert into iglesia (id, nombre) values ('prueba', ?)
                on conflict(id) do update set nombre = excluded.nombre
                """, arguments: [nombre])
        }
    }

    private func nombreDeLaIglesia() throws -> String? {
        try cola.read { db in
            try String.fetchOne(db, sql: "select nombre from iglesia where id = 'prueba'")
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(BaseLocal.compartida.enMemoria,
                      "sin base de disco no hay respaldo que probar")
    }

    /// El caso entero: lo de antes vuelve y lo de después se va.
    func testLoQueSeCapturaDespuesDelRespaldoSeReemplaza() async throws {
        try escribirIglesia("Iglesia de antes")
        let paquete = try await Respaldo.crear()
        defer { try? FileManager.default.removeItem(at: paquete) }

        try escribirIglesia("Iglesia de después")
        XCTAssertEqual(try nombreDeLaIglesia(), "Iglesia de después")

        let manifiesto = try await Respaldo.restaurar(paquete)
        XCTAssertEqual(try nombreDeLaIglesia(), "Iglesia de antes",
                       "### la restauración no reemplazó lo capturado después")
        XCTAssertEqual(manifiesto.version, 1)
    }

    /// Mirar el paquete no puede tocar nada: es lo que la hoja de confirmación
    /// enseña ANTES de decidir.
    func testInspeccionarNoModificaLaBase() async throws {
        try escribirIglesia("Sin tocar")
        let paquete = try await Respaldo.crear()
        defer { try? FileManager.default.removeItem(at: paquete) }

        try escribirIglesia("Cambiada a mano")
        let m = try await Respaldo.inspeccionar(paquete)
        XCTAssertEqual(m.iglesia.isEmpty, m.iglesia.isEmpty)   // el manifiesto se lee
        XCTAssertEqual(try nombreDeLaIglesia(), "Cambiada a mano",
                       "### inspeccionar tocó la base")
    }

    /// Un archivo que no es un respaldo se rechaza con su motivo, no con un
    /// error de SQLite a mitad de camino.
    func testUnArchivoCualquieraSeRechaza() async throws {
        let basura = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-es-un-respaldo.zip")
        try Data("esto no es un zip".utf8).write(to: basura)
        defer { try? FileManager.default.removeItem(at: basura) }

        do {
            _ = try await Respaldo.inspeccionar(basura)
            XCTFail("### aceptó un archivo que no es un respaldo")
        } catch {
            XCTAssertTrue(error is ZipLectura.Fallo || error is Respaldo.Fallo,
                          "### \(error)")
        }
    }

    // MARK: - El lector de zip

    func testElZipDelRespaldoTraeSusPiezas() async throws {
        let paquete = try await Respaldo.crear()
        defer { try? FileManager.default.removeItem(at: paquete) }

        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent("zip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: destino) }

        let escritas = try ZipLectura.extraer(paquete, a: destino)
        XCTAssertTrue(escritas.contains { $0.hasSuffix("respaldo.json") }, "\(escritas)")
        XCTAssertTrue(escritas.contains { $0.hasSuffix("tamio.sqlite") }, "\(escritas)")

        // Y lo extraído tiene que ser una base de verdad, no bytes con el
        // nombre correcto: si el inflado se corrompe, esto es lo que lo dice.
        // **Por la ruta que devolvió el lector**, no por la que uno supone: el
        // zip envuelve todo en una carpeta con el nombre del respaldo, y
        // abrir la ruta equivocada con `DatabaseQueue` no falla — crea una base
        // vacía, que es exactamente cómo pasó desapercibido la primera vez.
        let relativa = try XCTUnwrap(escritas.first { $0.hasSuffix("tamio.sqlite") })
        let sqlite = destino.appendingPathComponent(relativa)
        let copia = try DatabaseQueue(path: sqlite.path)
        let tablas = try await copia.read { db in
            try String.fetchAll(db, sql: "select name from sqlite_master where type = 'table'")
        }
        XCTAssertTrue(tablas.contains("iglesia"), "### la base extraída no se abre: \(tablas)")
    }
}

/// **El borrado masivo y el reinicio de fábrica.**
///
/// Lo que estas pruebas cuidan no es que borren —eso es un `update`— sino que
/// no se dejen nada: una tabla nueva que nadie añada al mapa de entidades queda
/// borrada en el teléfono y viva en el servidor, y el siguiente `sync` la baja
/// otra vez. El fallo no se ve al probarlo a mano: se ve un minuto después.
final class BorradoMasivoTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(BaseLocal.compartida.enMemoria, "sin base de disco no hay nada que borrar")
    }

    /// **Ninguna tabla con borrado lógico puede quedarse fuera del mapa.** Es
    /// la prueba que hace falta escribir una vez para no tener que acordarse
    /// nunca más.
    func testTodaTablaSincronizableTieneSuEntidad() throws {
        let tablas = try BaseLocal.compartida.cola.read { db in
            try BorradoMasivo.tablasConBorrado(db)
        }
        XCTAssertFalse(tablas.isEmpty, "### el esquema no tiene ninguna tabla con `borrado`")

        let cubiertas = Set(BorradoMasivo.entidades.keys)
            .union(BorradoMasivo.soloLocales)
            .union(BorradoMasivo.seConserva)
        let huerfanas = Set(tablas).subtracting(cubiertas)
        XCTAssertTrue(huerfanas.isEmpty,
                      "### estas tablas se borrarían sin avisar a nadie: \(huerfanas.sorted())")
    }

    /// Y al revés: una entidad en el mapa cuya tabla ya no existe encolaría
    /// bajas de filas que no están.
    func testElMapaNoInventaTablas() throws {
        let tablas = try BaseLocal.compartida.cola.read { db in
            Set(try BorradoMasivo.tablasConBorrado(db))
        }
        let sobrantes = Set(BorradoMasivo.entidades.keys).subtracting(tablas)
        XCTAssertTrue(sobrantes.isEmpty, "### el mapa nombra tablas que no existen: \(sobrantes.sorted())")
    }

    /// Borrar da de baja las filas Y encola su subida. Sin lo segundo, el
    /// borrado se queda en el teléfono y vuelve con la siguiente bajada.
    func testBorrarDaDeBajaYEncolaLaSubida() async throws {
        let cola = BaseLocal.compartida.cola
        try await cola.write { db in
            try db.execute(sql: "delete from movimiento")
            // Las columnas obligatorias y nada más: la prueba es del borrado,
            // no del modelo.
            let obligatorias = try Row.fetchAll(db, sql: "select * from pragma_table_info('movimiento')")
                .filter { ($0["notnull"] as Int? ?? 0) == 1 && $0["dflt_value"] == nil }
                .compactMap { $0["name"] as String? }
            let valores = obligatorias.map { c -> String in
                switch c {
                case "id":     return "'m-prueba'"
                case "monto":  return "100"
                default:       return "'x'"
                }
            }
            try db.execute(sql: """
                insert into movimiento (\(obligatorias.joined(separator: ", ")))
                values (\(valores.joined(separator: ", ")))
                """)
        }
        _ = try await BorradoMasivo.borrarRegistros()

        let (vivo, encolado) = try await cola.read { db -> (Bool, Bool) in
            (try Bool.fetchOne(db, sql: "select borrado = 0 from movimiento where id = 'm-prueba'") ?? false,
             try Bool.fetchOne(db, sql: """
                select count(*) > 0 from outbox
                where entidad = 'movimiento' and registroId = 'm-prueba' and operacion = 'eliminar'
                """) ?? false)
        }
        XCTAssertFalse(vivo, "### la fila sigue viva")
        XCTAssertTrue(encolado, "### se borró en el teléfono y nadie va a contárselo al servidor")
    }
}
