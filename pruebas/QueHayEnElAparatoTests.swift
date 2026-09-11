import XCTest
import GRDB
@testable import Tamio

/// **Qué hay de verdad en la base local del iPad.**
///
/// `PDFDeVerdadTests` falló con «no hay ningún acta» y «no hay ningún periodo
/// contable». Eso puede ser dos cosas muy distintas —el aparato no tiene esos
/// datos, o la sincronización no había corrido cuando la prueba miró— y la
/// diferencia decide si es entorno o hallazgo. Esta prueba no afirma nada:
/// cuenta y lo imprime.
final class QueHayEnElAparatoTests: XCTestCase {

    func testInventarioDeLaBaseLocal() async throws {
        print("BASE en memoria (o sea, CAÍDA): \(BaseLocal.compartida.enMemoria)")

        // Se le da tiempo a la sincronización, que es asíncrona y arranca con
        // la app: sin esto se mide una base que todavía no ha bajado nada.
        let motor = MotorSincronizacion.compartido
        print("ANTES · estado: \(motor.estadoLegible) · pendientes: \(motor.pendientesLegible)")
        await motor.sincronizar(reintentarLoAtascado: false)
        print("DESPUÉS · estado: \(motor.estadoLegible) · pendientes: \(motor.pendientesLegible)")

        // **Los nombres de las tablas se LEEN del esquema, no se adivinan.**
        // La primera versión de esta prueba los puso a mano y las nueve
        // consultas fallaron; el centinela decía -2 y eso se lee como "vacío".
        let tablas = (try? await BaseLocal.compartida.cola.read { db in
            try String.fetchAll(db, sql: """
                select name from sqlite_master
                where type='table' and name not like 'sqlite_%'
                  and name not like 'grdb_%' order by name
            """)
        }) ?? []
        print("TABLAS (\(tablas.count)):")
        for t in tablas {
            let n = (try? await BaseLocal.compartida.cola.read { db in
                try Int.fetchOne(db, sql: "select count(*) from \"\(t)\"") ?? -1
            }) ?? -2
            print("  \(t.padding(toLength: 26, withPad: " ", startingAt: 0)) \(n)")
        }
    }
}
