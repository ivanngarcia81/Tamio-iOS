import XCTest
import GRDB
@testable import Tamio

/// **La base en memoria es muda: caza el peor fallo que puede tener la app.**
///
/// `BaseLocal.init` abre `tamio.sqlite`; si el archivo no abre o si `migrate`
/// lanza, se cae a una base EN MEMORIA y sigue. La app funciona toda la tarde
/// —se dan de alta ingresos, se cierra un corte, se firma un acta— y al cerrarla
/// no queda nada. `enMemoria` existe, pero solo lo miran `Respaldo`,
/// `Compactacion` y `BorradoMasivo` para lanzar `sinBase`: **ninguna pantalla se
/// lo enseña al usuario**, así que la tesorera ni sabe que está trabajando sobre
/// arena, ni puede respaldar para salvar lo del día.
///
/// **Cómo se corre** — dos pasadas sobre el MISMO contenedor del simulador:
///
///     xcodebuild ... -only-testing:TamioTests/BaseMuda/test1_sembrarYDecirDonde test
///     # el shell corrompe el archivo que la prueba imprimió
///     xcodebuild ... -only-testing:TamioTests/BaseMuda/test2_seguirAhi test
///
/// La segunda pasada es la que falla hoy: la fila no está y `enMemoria` es
/// verdadero sin que nada lo diga.
final class BaseMuda: XCTestCase {

    static let marca = "prueba-base-muda"

    var ruta: String {
        let carpeta = try! FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
        return carpeta.appendingPathComponent("tamio.sqlite").path
    }

    /// Pasada 1: la base sana. Escribe una fila y dice dónde está el archivo.
    func test1_sembrarYDecirDonde() throws {
        let base = BaseLocal.compartida
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

    /// Pasada 2, con el archivo estropeado. Lo que la tesorera da por hecho:
    /// que lo que anotó ayer sigue ahí y que la base es la de siempre.
    func test2_seguirAhi() throws {
        let base = BaseLocal.compartida
        let n = (try? base.cola.read { try Int.fetchOne($0, sql:
            "SELECT count(*) FROM movimiento WHERE id = ?", arguments: [Self.marca]) }) ?? 0
        print("EN-MEMORIA:\(base.enMemoria) FILAS:\(n)")
        XCTAssertFalse(base.enMemoria,
                       "La app está trabajando sobre una base en memoria y no lo dice en ninguna pantalla")
        XCTAssertEqual(n, 1, "El movimiento sembrado ayer ya no está")
    }

    /// **Y encima no se puede respaldar.** Es lo que convierte un mal día en
    /// una pérdida: la única salida —sacar un respaldo antes de cerrar— es la
    /// que `enMemoria` bloquea.
    func test3_niSiquieraSePuedeRespaldar() async {
        guard BaseLocal.compartida.enMemoria else {
            return XCTSkip0("solo aplica con la base caída")
        }
        do {
            _ = try await Respaldo.crear()
            XCTFail("debería haber lanzado sinBase")
        } catch {
            print("RESPALDO-FALLA:\(error)")
        }
    }

    private func XCTSkip0(_ m: String) { print("SKIP:\(m)") }
}
