import XCTest
import GRDB
@testable import Tamio

/// **La v26, sobre una base que ya existía.**
///
/// Se migra hasta la v25, se siembra como sembraba la versión vieja —dejando
/// que sean las OMISIONES DE LA COLUMNA las que pongan "Pastor", "Tesorero" y
/// "Secretario", que es exactamente lo que pasaba en los aparatos— y solo
/// entonces se corre la v26.
final class CargosSinSembrarTests: XCTestCase {

    private func baseHastaV25() throws -> DatabaseQueue {
        let cola = try DatabaseQueue()
        var m = BaseLocal.migrador
        try m.migrate(cola, upTo: "v25_logo")
        return cola
    }

    func testLaSemillaSeVaciaYLoEscritoAManoNo() throws {
        let cola = try baseHastaV25()

        try cola.write { db in
            // Sin tocar los cargos: los pone la columna, como antes.
            try db.execute(sql: "INSERT INTO iglesia (id) VALUES ('sembrada')")
            // Y una iglesia que SÍ eligió cargos distintos.
            try db.execute(sql: """
                INSERT INTO iglesia (id, pastorCargo, tesoreroCargo, secretarioCargo)
                VALUES ('elegidos', 'Pastor asociado', 'Tesorera', 'Secretaria de actas')
                """)
        }

        // La premisa, comprobada y no supuesta: antes de la v26 la fila
        // sembrada trae los tres literales españoles.
        let antes = try cola.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM iglesia WHERE id = 'sembrada'")!
        }
        XCTAssertEqual(antes["pastorCargo"], "Pastor")
        XCTAssertEqual(antes["tesoreroCargo"], "Tesorero")
        XCTAssertEqual(antes["secretarioCargo"], "Secretario")

        var m = BaseLocal.migrador
        try m.migrate(cola)

        let sembrada = try cola.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM iglesia WHERE id = 'sembrada'")!
        }
        XCTAssertEqual(sembrada["pastorCargo"], "",
                       "### la semilla del pastor sigue puesta")
        XCTAssertEqual(sembrada["tesoreroCargo"], "",
                       "### la semilla del tesorero sigue puesta")
        XCTAssertEqual(sembrada["secretarioCargo"], "",
                       "### la semilla de la secretaria sigue puesta")

        let elegidos = try cola.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM iglesia WHERE id = 'elegidos'")!
        }
        XCTAssertEqual(elegidos["pastorCargo"], "Pastor asociado",
                       "### se llevó por delante un cargo escrito a mano")
        XCTAssertEqual(elegidos["tesoreroCargo"], "Tesorera")
        XCTAssertEqual(elegidos["secretarioCargo"], "Secretaria de actas")
    }

    /// Un cargo vacío no se imprime vacío: se traduce al leerlo.
    func testUnCargoVacioSeImprimeTraducido() {
        var c = ConfiguracionIglesia()
        c.pastorNombre = "Samuel Ríos"
        c.tesoreroNombre = "Iván García"
        c.secretarioNombre = "Lucía Márquez"

        XCTAssertEqual(c.pastorCargo, "", "### el modelo volvió a sembrar")
        XCTAssertEqual(c.tesoreroCargo, "")
        XCTAssertEqual(c.secretarioCargo, "")

        let cargos = c.firmantes.map(\.cargo)
        XCTAssertFalse(cargos.contains(""), "### un firmante sin cargo en el PDF")
        XCTAssertEqual(cargos, [Catalogos.Cargos.omision(.pastor),
                                Catalogos.Cargos.omision(.tesorero),
                                Catalogos.Cargos.omision(.secretaria)])
    }

    /// Lo que baja del servidor con la semilla vieja se trata como hueco; lo
    /// demás se respeta tal cual.
    func testLaBajadaNoRevivelaSemilla() {
        XCTAssertEqual(Catalogos.Cargos.sinSemilla("Secretario"), "")
        XCTAssertEqual(Catalogos.Cargos.sinSemilla("Tesorero"), "")
        XCTAssertEqual(Catalogos.Cargos.sinSemilla("Pastor"), "")
        XCTAssertEqual(Catalogos.Cargos.sinSemilla(nil), "")
        XCTAssertEqual(Catalogos.Cargos.sinSemilla("Tesorera"), "Tesorera")
        XCTAssertEqual(Catalogos.Cargos.sinSemilla("  Pastor asociado "), "Pastor asociado")
    }
}
