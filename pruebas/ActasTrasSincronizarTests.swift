import XCTest
import GRDB
@testable import Tamio

/// **¿Las actas no se leen, o es que todavía no habían bajado?**
///
/// `PDFDeVerdadTests` dijo `QA-ACTAS:0` con **siete** filas en la tabla `acta`,
/// y eso parece el caso del folio B7 de §0.0 —un filtro que tira el dato al
/// leer—. Pero hay una explicación más aburrida: la sincronización es asíncrona
/// y arranca con la app, así que la primera corrida pudo medir una base que
/// todavía no había bajado nada.
///
/// Aquí se sincroniza PRIMERO y se pregunta DESPUÉS, con el conteo de la tabla
/// al lado como control.
final class ActasTrasSincronizarTests: XCTestCase {

    func testLeerActasYPeriodosDespuesDeSincronizar() async throws {
        await MotorSincronizacion.compartido.sincronizar(reintentarLoAtascado: false)

        let enTabla = (try? await BaseLocal.compartida.cola.read { db in
            try Int.fetchOne(db, sql: "select count(*) from acta") ?? -1
        }) ?? -2
        let porRepo = (try? await repositorioActas().lista().count) ?? -2
        print("ACTAS · tabla=\(enTabla)  repositorio=\(porRepo)")

        // **El filtro de `lista()` es `borrado == false`.** Si seis de las
        // siete están marcadas como borradas, el repositorio acierta y no hay
        // nada que arreglar — que es la lección de B7 en §0.0, al revés.
        let borradas = (try? await BaseLocal.compartida.cola.read { db in
            try Int.fetchOne(db, sql: "select count(*) from acta where borrado = 1") ?? -1
        }) ?? -2
        print("ACTAS · borradas=\(borradas)  vivas=\(enTabla - max(borradas,0))")

        let movs = (try? await BaseLocal.compartida.cola.read { db in
            try Int.fetchOne(db, sql: "select count(*) from movimiento") ?? -1
        }) ?? -2
        let periodos = await repositorioReportes().periodos()
        print("PERIODOS · movimientos en tabla=\(movs)  periodos=\(periodos.count) [\(periodos.map(\.clave).joined(separator: ","))]")

        if enTabla > 0 && porRepo == 0 {
            print("### HALLAZGO: hay \(enTabla) actas en la tabla y el repositorio devuelve 0")
        } else if enTabla > 0 && porRepo == enTabla {
            print("SIN HALLAZGO: el repositorio las lee; el 0 de antes era la sincronización sin correr")
        }
        if movs > 0 && periodos.isEmpty {
            print("### HALLAZGO: hay \(movs) movimientos y ningún periodo contable")
        } else if movs > 0 && !periodos.isEmpty {
            print("SIN HALLAZGO en periodos: el 0 de antes era la sincronización sin correr")
        }
    }
}
