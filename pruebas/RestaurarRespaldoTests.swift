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

    /// **Restaurar deja todo encolado para volver a subirlo.**
    ///
    /// Sin esto, restaurar solo arregla el aparato: el servidor sigue con lo
    /// que tuviera y la primera sincronización deshace la restauración. Pasó en
    /// el aparato el 7 de septiembre de 2026, después de borrarlo todo y
    /// recuperarlo.
    func testRestaurarDejaLoRecuperadoEnLaColaDeSubida() async throws {
        try escribirIglesia("Con cola")
        let cola = BaseLocal.compartida.cola
        try await cola.write { db in
            try db.execute(sql: "delete from movimiento")
            let obligatorias = try Row.fetchAll(db, sql: "select * from pragma_table_info('movimiento')")
                .filter { ($0["notnull"] as Int? ?? 0) == 1 && $0["dflt_value"] == nil }
                .compactMap { $0["name"] as String? }
            let valores = obligatorias.map { c -> String in
                switch c {
                case "id":    return "'m-vuelve'"
                case "monto": return "100"
                default:      return "'x'"
                }
            }
            try db.execute(sql: """
                insert into movimiento (\(obligatorias.joined(separator: ", ")))
                values (\(valores.joined(separator: ", ")))
                """)
        }

        let paquete = try await Respaldo.crear()
        defer { try? FileManager.default.removeItem(at: paquete) }

        // Se borra y se vacía la cola, como habría quedado tras subir la baja.
        try await cola.write { db in
            try db.execute(sql: "update movimiento set borrado = 1")
            try db.execute(sql: "delete from outbox")
        }

        _ = try await Respaldo.restaurar(paquete)

        let encolado = try await cola.read { db in
            try Bool.fetchOne(db, sql: """
                select count(*) > 0 from outbox
                where entidad = 'movimiento' and registroId = 'm-vuelve'
                  and operacion = 'actualizar'
                """) ?? false
        }
        XCTAssertTrue(encolado,
                      "### se recuperó en el teléfono y nadie iba a contárselo al servidor")
    }

    /// **El ciclo entero con contraseña**, que es lo que las pruebas de
    /// `RespaldoCifrado` no cubren: allí se cifran bytes de mentira; aquí se
    /// respalda la base de verdad, se estropea y se recupera.
    func testUnRespaldoProtegidoSeCreaYSeRestaura() async throws {
        try escribirIglesia("Con contraseña")
        let paquete = try await Respaldo.crear(protegidoCon: "la de Iván")
        defer { try? FileManager.default.removeItem(at: paquete) }

        // Deja de ser un zip, y se nota en el nombre y en el contenido.
        XCTAssertEqual(paquete.pathExtension, "tamiobk")
        XCTAssertTrue(Respaldo.pideContrasena(paquete))

        try escribirIglesia("Cambiada después")
        _ = try await Respaldo.restaurar(paquete, contrasena: "la de Iván")
        XCTAssertEqual(try nombreDeLaIglesia(), "Con contraseña")
    }

    /// Y sin la contraseña no se abre, ni siquiera para mirarlo.
    func testSinLaContrasenaNoSeAbreElPaquete() async throws {
        try escribirIglesia("Protegida")
        let paquete = try await Respaldo.crear(protegidoCon: "correcta")
        defer { try? FileManager.default.removeItem(at: paquete) }

        do {
            _ = try await Respaldo.inspeccionar(paquete, contrasena: "equivocada")
            XCTFail("### abrió un respaldo protegido con otra contraseña")
        } catch {
            XCTAssertEqual(error as? RespaldoCifrado.Fallo, .contrasenaIncorrecta)
        }
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

/// **La medición de la Zona de riesgo.**
///
/// La fila decía "La base ya está compacta" siempre, sin haber mirado nada.
/// Estas pruebas cuidan que lo que diga ahora sea lo que hay: si el número no
/// se puede confiar, la frase de antes era igual de útil y más corta.
@MainActor
final class CompactacionTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(BaseLocal.compartida.enMemoria, "sin base de disco no hay nada que medir")
    }

    private func sembrarMovimiento(id: String, borrado: Bool) async throws {
        try await BaseLocal.compartida.cola.write { db in
            let obligatorias = try Row.fetchAll(db, sql: "select * from pragma_table_info('movimiento')")
                .filter { ($0["notnull"] as Int? ?? 0) == 1 && $0["dflt_value"] == nil }
                .compactMap { $0["name"] as String? }
            let valores = obligatorias.map { c -> String in
                switch c {
                case "id":      return "'\(id)'"
                case "monto":   return "100"
                case "borrado": return borrado ? "1" : "0"
                default:        return "'x'"
                }
            }
            var columnas = obligatorias
            var vals = valores
            if !columnas.contains("borrado") {
                columnas.append("borrado")
                vals.append(borrado ? "1" : "0")
            }
            try db.execute(sql: """
                insert or replace into movimiento (\(columnas.joined(separator: ", ")))
                values (\(vals.joined(separator: ", ")))
                """)
        }
    }

    func testCuentaLosRegistrosBorradosQueSiguenGuardados() async throws {
        try await BaseLocal.compartida.cola.write { db in
            try db.execute(sql: "delete from movimiento")
            try db.execute(sql: "delete from outbox")
        }
        let medidoAntes = await Compactacion.medir()
        let antes = try XCTUnwrap(medidoAntes)

        try await sembrarMovimiento(id: "c-borrado", borrado: true)
        try await sembrarMovimiento(id: "c-vivo", borrado: false)
        let medidoDespues = await Compactacion.medir()
        let despues = try XCTUnwrap(medidoDespues)

        XCTAssertEqual(despues.filasBorradas, antes.filasBorradas + 1,
                       "### no contó la fila marcada como borrada")
        // **Y NO cuenta como purgable**: se acaba de borrar. Desde que existe
        // la purga, "purgable" son las tres condiciones juntas —borrada, ya
        // subida y de más de `diasParaPurgar`—, y esta solo cumple dos. El mes
        // de margen es lo que permite deshacer un borrado equivocado desde otro
        // aparato.
        XCTAssertEqual(despues.filasPurgables, antes.filasPurgables,
                       "### una baja de hace un segundo no se puede purgar todavía")
    }

    /// La distinción que hace segura la purga: una baja que aún no ha subido no
    /// se puede tocar, porque si se borra el servidor no se entera nunca.
    func testUnaBajaSinSubirNoCuentaComoPurgable() async throws {
        try await BaseLocal.compartida.cola.write { db in
            try db.execute(sql: "delete from movimiento")
            try db.execute(sql: "delete from outbox")
        }
        try await sembrarMovimiento(id: "c-pendiente", borrado: true)
        try await BaseLocal.compartida.cola.write { db in
            var op = OperacionPendiente(id: nil, entidad: "movimiento",
                                        registroId: "c-pendiente",
                                        operacion: OperacionPendiente.Operacion.eliminar.rawValue,
                                        creadoEn: Date().timeIntervalSince1970,
                                        intentos: 0, ultimoError: nil)
            try op.insert(db)
        }
        let medido = await Compactacion.medir()
        let e = try XCTUnwrap(medido)
        XCTAssertEqual(e.filasBorradas, 1)
        XCTAssertEqual(e.filasPurgables, 0,
                       "### purgarla dejaría al servidor sin enterarse de la baja")
    }

    /// El resumen es lo que se lee en pantalla: no puede prometer una limpieza
    /// que todavía no existe.
    func testElResumenNoPrometeLimpiar() async throws {
        let medido = await Compactacion.medir()
        let e = try XCTUnwrap(medido)
        let texto = e.resumen.lowercased()
        for promesa in ["recuperar", "se pueden quitar", "reclaim", "can be removed"] {
            XCTAssertFalse(texto.contains(promesa), "\(promesa) → \(texto)")
        }
        // En los dos idiomas: el simulador corre en inglés y la prueba no
        // puede depender de en cuál esté.
        XCTAssertTrue(texto.contains("la base ocupa") || texto.contains("the database takes"),
                      texto)
    }
}

/// **La purga: lo único de la app que borra de verdad.**
///
/// Tres condiciones la hacen segura, y cada una tiene aquí su prueba. Se
/// escriben porque el fallo de cualquiera de ellas es silencioso: no se ve al
/// probarlo a mano, se ve semanas después cuando falta algo.
@MainActor
final class PurgaTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(BaseLocal.compartida.enMemoria, "sin base de disco no hay nada que purgar")
    }

    private func hace(_ dias: Int) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(dias) * 24 * 3600))
    }

    /// Siembra un movimiento con el estado que se quiera probar.
    private func sembrar(id: String, borrado: Bool, actualizado: String) async throws {
        try await BaseLocal.compartida.cola.write { db in
            let obligatorias = try Row.fetchAll(db, sql: "select * from pragma_table_info('movimiento')")
                .filter { ($0["notnull"] as Int? ?? 0) == 1 && $0["dflt_value"] == nil }
                .compactMap { $0["name"] as String? }
            var columnas = obligatorias
            var valores = obligatorias.map { c -> String in
                switch c {
                case "id":    return "'\(id)'"
                case "monto": return "100"
                default:      return "'x'"
                }
            }
            for (col, val) in [("borrado", borrado ? "1" : "0"),
                               ("actualizadoEn", "'\(actualizado)'")]
            where !columnas.contains(col) {
                columnas.append(col); valores.append(val)
            }
            try db.execute(sql: """
                insert or replace into movimiento (\(columnas.joined(separator: ", ")))
                values (\(valores.joined(separator: ", ")))
                """)
        }
    }

    private func existe(_ id: String) async throws -> Bool {
        try await BaseLocal.compartida.cola.read { db in
            try Bool.fetchOne(db, sql: "select count(*) > 0 from movimiento where id = ?",
                              arguments: [id]) ?? false
        }
    }

    private func limpiar() async throws {
        try await BaseLocal.compartida.cola.write { db in
            try db.execute(sql: "delete from movimiento")
            try db.execute(sql: "delete from outbox")
        }
    }

    /// Lo viejo y ya subido se va.
    func testSeVaLoBorradoHaceMasDeUnMes() async throws {
        try await limpiar()
        try await sembrar(id: "p-viejo", borrado: true, actualizado: hace(40))
        _ = try await Compactacion.purgar()
        let sigue = try await existe("p-viejo")
        XCTAssertFalse(sigue, "### debería haberse ido")
    }

    /// **Lo recién borrado se queda**: es el mes de margen para deshacer un
    /// borrado equivocado desde otro aparato.
    func testSeQuedaLoBorradoAyer() async throws {
        try await limpiar()
        try await sembrar(id: "p-nuevo", borrado: true, actualizado: hace(2))
        _ = try await Compactacion.purgar()
        let sigue = try await existe("p-nuevo")
        XCTAssertTrue(sigue, "### se llevó por delante el margen para deshacer")
    }

    /// **Lo vivo no se toca**, por viejo que sea.
    func testNoSeVaLoQueNoEstaBorrado() async throws {
        try await limpiar()
        try await sembrar(id: "p-vivo", borrado: false, actualizado: hace(500))
        _ = try await Compactacion.purgar()
        let sigue = try await existe("p-vivo")
        XCTAssertTrue(sigue, "### borró una fila viva")
    }

    /// **Y lo que aún no ha subido tampoco**, aunque sea antiguo: borrarlo
    /// aquí sería la forma de que el servidor no se entere nunca de la baja.
    func testNoSeVaLoQueNoHaSubido() async throws {
        try await limpiar()
        try await sembrar(id: "p-pendiente", borrado: true, actualizado: hace(90))
        try await BaseLocal.compartida.cola.write { db in
            var op = OperacionPendiente(id: nil, entidad: "movimiento",
                                        registroId: "p-pendiente",
                                        operacion: OperacionPendiente.Operacion.eliminar.rawValue,
                                        creadoEn: Date().timeIntervalSince1970,
                                        intentos: 0, ultimoError: nil)
            try op.insert(db)
        }
        _ = try await Compactacion.purgar()
        let sigue = try await existe("p-pendiente")
        XCTAssertTrue(sigue, "### el servidor no se habría enterado nunca de esa baja")
    }

    /// **El Registro no se purga jamás**: es la constancia de qué pasó con cada
    /// cosa, y sus apuntes son justo lo que hace falta cuando alguien pregunta
    /// meses después por algo que ya no está.
    func testLaBitacoraNoSePurga() async throws {
        // La fecha se calcula FUERA del bloque: dentro es un contexto sin
        // actor y `hace` vive en el principal.
        let hace400 = hace(400)
        try await BaseLocal.compartida.cola.write { db in
            try db.execute(sql: "delete from registro")
            // `creadoEn` es obligatoria y no tiene valor por omisión.
            try db.execute(sql: """
                insert into registro (id, borrado, actualizadoEn, creadoEn)
                values ('r-viejo', 1, ?, ?)
                """, arguments: [hace400, hace400])
        }
        _ = try await Compactacion.purgar()
        let sigue = try await BaseLocal.compartida.cola.read { db in
            try Bool.fetchOne(db, sql: "select count(*) > 0 from registro where id = 'r-viejo'") ?? false
        }
        XCTAssertTrue(sigue, "### se borró un apunte de la bitácora")
        XCTAssertTrue(Compactacion.nuncaSePurga.contains("registro"))
    }

    /// La cuenta que se enseña y lo que se borra tienen que ser lo mismo. Si
    /// discrepan, el número de la pantalla es una promesa que no se cumple.
    func testLoQueSeAnunciaEsLoQueSeVa() async throws {
        try await limpiar()
        try await sembrar(id: "p-1", borrado: true, actualizado: hace(40))
        try await sembrar(id: "p-2", borrado: true, actualizado: hace(40))
        try await sembrar(id: "p-3", borrado: true, actualizado: hace(2))

        let medido = await Compactacion.medir()
        let antes = try XCTUnwrap(medido)
        let purga = try await Compactacion.purgar()
        XCTAssertEqual(purga.filas, antes.filasPurgables,
                       "### se anunciaron \(antes.filasPurgables) y se fueron \(purga.filas)")
    }
}

/// **El respaldo protegido con contraseña.**
///
/// Es lo único que sale del aparato —a Archivos, a iCloud, a un correo— y
/// hasta hoy salía en claro con la contabilidad entera dentro.
final class RespaldoCifradoTests: XCTestCase {

    private let zipFalso = Data("PK\u{03}\u{04} esto hace de paquete".utf8)

    func testLaIdaYLaVuelta() throws {
        let cifrado = try RespaldoCifrado.cifrar(zipFalso, con: "una buena")
        XCTAssertNotEqual(cifrado, zipFalso, "### salió en claro")
        XCTAssertEqual(try RespaldoCifrado.descifrar(cifrado, con: "una buena"), zipFalso)
    }

    /// La contraseña equivocada se reconoce como tal, no como bytes raros:
    /// AES-GCM comprueba su etiqueta antes de devolver nada.
    func testLaContrasenaEquivocadaNoAbre() throws {
        let cifrado = try RespaldoCifrado.cifrar(zipFalso, con: "la buena")
        XCTAssertThrowsError(try RespaldoCifrado.descifrar(cifrado, con: "otra")) { error in
            XCTAssertEqual(error as? RespaldoCifrado.Fallo, .contrasenaIncorrecta)
        }
    }

    /// **Se reconoce por la marca, no por la extensión**: el nombre lo puede
    /// cambiar cualquiera al guardarlo, y un respaldo protegido que llegue
    /// llamándose `.zip` tiene que seguir pidiendo su contraseña.
    func testSeReconoceUnPaqueteProtegido() throws {
        XCTAssertFalse(RespaldoCifrado.estaCifrado(zipFalso))
        XCTAssertTrue(RespaldoCifrado.estaCifrado(try RespaldoCifrado.cifrar(zipFalso, con: "x")))
    }

    /// Un paquete sin cifrar pasa de largo: los respaldos de antes se siguen
    /// abriendo sin pedir nada.
    func testUnPaqueteEnClaroSeDevuelveIgual() throws {
        XCTAssertEqual(try RespaldoCifrado.descifrar(zipFalso, con: ""), zipFalso)
    }

    /// Dos respaldos de lo mismo con la misma contraseña no pueden salir
    /// iguales: cada uno lleva su propia sal.
    func testCadaRespaldoLlevaSuSal() throws {
        let a = try RespaldoCifrado.cifrar(zipFalso, con: "igual")
        let b = try RespaldoCifrado.cifrar(zipFalso, con: "igual")
        XCTAssertNotEqual(a, b, "### con la misma sal, dos paquetes iguales se delatan")
        XCTAssertEqual(try RespaldoCifrado.descifrar(a, con: "igual"), zipFalso)
        XCTAssertEqual(try RespaldoCifrado.descifrar(b, con: "igual"), zipFalso)
    }

    func testSinContrasenaNoSeCifra() {
        XCTAssertThrowsError(try RespaldoCifrado.cifrar(zipFalso, con: "")) { error in
            XCTAssertEqual(error as? RespaldoCifrado.Fallo, .contrasenaVacia)
        }
    }
}

/// La clase de protección que la app pide para sus archivos.
final class ProteccionArchivosTests: XCTestCase {

    /// `completeUnlessOpen` y no `complete`: con esta última, al bloquearse el
    /// teléfono un archivo YA abierto deja de poder leerse y la app se queda
    /// escribiendo en el vacío. Y no `completeUntilFirstUserAuthentication`,
    /// que es la de por omisión y la que se quería mejorar.
    func testPideLaClaseCorrecta() {
        XCTAssertEqual(ProteccionArchivos.clase, .completeUnlessOpen)
    }

    /// Aplicarla no puede reventar: en el simulador Data Protection no existe y
    /// `setAttributes` falla en silencio, y aun así la app tiene que arrancar.
    func testAplicarNoLanzaNiEnElSimulador() {
        _ = ProteccionArchivos.aplicar()
    }
}
