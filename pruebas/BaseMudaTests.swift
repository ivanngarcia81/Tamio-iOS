import XCTest
import GRDB
@testable import Tamio

/// **La base local cuando el archivo no abre: las dos salidas y cuál toca.**
///
/// `BaseLocal.init` abre `tamio.sqlite`; si algo falla hay dos caminos, y la
/// diferencia entre ellos es lo único delicado de esta zona:
///
/// - **El archivo está dañado** —SQLite no lo reconoce como base—: se aparta con
///   su fecha y se empieza una limpia. No se pierde nada que no estuviera ya
///   perdido (nadie puede leer ese archivo) y la app vuelve a guardar.
/// - **Cualquier otra cosa** —una migración que lanza, permisos, el aparato
///   bloqueado, el disco lleno—: se trabaja en memoria y **nada se guarda**,
///   pero el archivo NO se toca. Apartarlo ahí sería el desastre: una migración
///   rota es un fallo nuestro, y apartar por eso borraría los datos de todo el
///   que instale esa versión, en cada arranque.
///
/// Las dos avisan, y no con el mismo texto ni el mismo color: eso lo comprueba
/// `BaseCaidaUITests`.
///
/// **Cómo se corre la parte que necesita un archivo roto** — dos pasadas sobre
/// el MISMO contenedor, con el shell estropeándolo entre una y otra:
///
///     xcodebuild ... -only-testing:TamioTests/BaseMuda/test1_sembrarYDecirDonde test
///     # el shell pone a cero los primeros 4 KB del archivo que imprimió
///     xcodebuild ... -only-testing:TamioTests/BaseMuda/test2_seEmpezoDeCeroYSeGuardaOtraVez test
final class BaseMuda: XCTestCase {

    static let marca = "prueba-base-muda"

    var carpeta: URL {
        try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }
    var ruta: String { carpeta.appendingPathComponent("tamio.sqlite").path }

    /// **Las dos pasadas SALTAN si el contenedor no está como cada una espera**,
    /// en vez de fallar. Sin esto, correr la suite entera con la base sana deja
    /// la pasada 2 en rojo siempre, y una suite que siempre tiene un rojo es una
    /// suite que se deja de mirar.
    ///
    /// Pasada 1: la base sana. Escribe una fila y dice dónde está el archivo.
    func test1_sembrarYDecirDonde() throws {
        let base = BaseLocal.compartida
        try XCTSkipUnless(BaseLocal.caida == nil,
                          "la pasada 1 pide una base sana, y esta ya venía rota")
        XCTAssertFalse(base.enMemoria, "la pasada 1 tiene que correr sobre la base de archivo")
        try base.cola.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO movimiento
                (id, tipo, categoria, folio, metodo, monto, hora, fecha, registradoPor,
                 categoriaCompleta, sinDepositar, marcadoPendiente, incluidoEnCorte,
                 darConstanciaAnual, repiteMensual, folioProvisional, borrado)
                VALUES (?, 'ingreso', 'Diezmo', 'P-1', 'Efectivo', 196000, '10:00', ?,
                        'prueba', 'Diezmo', 1, 0, 1, 0, 0, 1, 0)
                """, arguments: [Self.marca, Date().timeIntervalSince1970])
        }
        let n = try base.cola.read { try Int.fetchOne($0, sql:
            "SELECT count(*) FROM movimiento WHERE id = ?", arguments: [Self.marca]) } ?? 0
        XCTAssertEqual(n, 1)
        print("RUTA:\(ruta)")
    }

    /// **Pasada 2, con el archivo estropeado: la app tiene que volver a
    /// guardar.**
    ///
    /// Lo que se perdió se perdió —el archivo no lo abre nadie— y eso no se
    /// puede arreglar desde aquí; lo que sí se puede es que la tesorera no pase
    /// la tarde capturando sobre arena. Antes se quedaba en memoria: trabajaba
    /// hasta la noche y al cerrar no quedaba nada.
    func test2_seEmpezoDeCeroYSeGuardaOtraVez() throws {
        let base = BaseLocal.compartida
        try XCTSkipIf(BaseLocal.caida == nil,
                      "la pasada 2 pide el archivo ya estropeado: ver la receta de la cabecera")
        let caida = try XCTUnwrap(BaseLocal.caida)
        print("CAIDA:\(caida.que) MOTIVO:\(caida.motivo)")

        guard case .seEmpezoDeCero(let apartadoEn) = caida.que else {
            return XCTFail("con el archivo dañado hay que empezar de cero, no quedarse en memoria")
        }
        XCTAssertFalse(base.enMemoria, "se empezó de cero pero se sigue en memoria")

        // **La dañada se guarda, no se borra**: es lo único de lo que se podría
        // rescatar algo.
        let apartada = carpeta.appendingPathComponent(apartadoEn)
        XCTAssertTrue(FileManager.default.fileExists(atPath: apartada.path),
                      "la base dañada no se conservó")

        // La fila de ayer no está —no puede estar— pero lo que se escriba HOY sí
        // se queda, que es lo que se estaba perdiendo.
        let viejas = try base.cola.read { try Int.fetchOne($0, sql:
            "SELECT count(*) FROM movimiento WHERE id = ?", arguments: [Self.marca]) } ?? 0
        XCTAssertEqual(viejas, 0)
        try base.cola.write { db in
            try db.execute(sql: "INSERT INTO syncEstado (entidad, cursor) VALUES ('prueba', 'x')")
        }
        let escrito = try base.cola.read { try String.fetchOne($0, sql:
            "SELECT cursor FROM syncEstado WHERE entidad = 'prueba'") }
        XCTAssertEqual(escrito, "x", "la base nueva tampoco guarda")

        // Y con base viva se puede respaldar, que es la salida de emergencia que
        // la caída a memoria dejaba cerrada con llave.
        XCTAssertFalse(base.enMemoria)
    }

    /// **El límite del arreglo, que es lo que hace que no sea peligroso.**
    ///
    /// Solo se aparta el archivo cuando SQLite dice que no es una base
    /// (`SQLITE_NOTADB`, `SQLITE_CORRUPT`). Un error de migración —el caso que
    /// más miedo da, porque es culpa nuestra y le pasaría a TODOS los aparatos a
    /// la vez— tiene que quedarse en memoria y no tocar el archivo.
    func testUnaMigracionRotaNoApartaElArchivo() throws {
        // Se reproduce el error tal cual lo lanzaría una migración mal escrita.
        let cola = try DatabaseQueue()
        var migrador = DatabaseMigrator()
        migrador.registerMigration("v_rota") { db in
            try db.execute(sql: "select columna_que_no_existe from tabla_que_no_existe")
        }
        var errorDeMigracion: Error?
        do { try migrador.migrate(cola) } catch { errorDeMigracion = error }
        let e = try XCTUnwrap(errorDeMigracion) as? DatabaseError
        print("MIGRACION-ROTA:\(String(describing: e?.resultCode))")
        XCTAssertNotEqual(e?.resultCode, .SQLITE_NOTADB)
        XCTAssertNotEqual(e?.resultCode, .SQLITE_CORRUPT)
    }
}
