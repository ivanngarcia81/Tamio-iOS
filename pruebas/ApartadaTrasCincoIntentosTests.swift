import XCTest
import GRDB
@testable import Tamio

/// **Z1: qué entiende quien lee la pantalla cuando una operación se aparta tras
/// cinco intentos.**
///
/// `maxIntentos = 5` y entonces la operación **se aparta, no se tira**: sigue en
/// la cola, deja de reintentarse en las vueltas automáticas, y el botón de
/// sincronizar a mano la despierta. Lo que el encargo quería saber es qué ve
/// quien mira la app.
///
/// **Por qué se siembra el ESTADO y no se provoca el fallo.** Para que una
/// operación llegue a cinco intentos hace falta que el servidor la rechace
/// cinco veces, y no hay forma limpia de conseguirlo con esta base: `cortes`,
/// `corte_movimientos` y `depositos_bancarios` solo tienen clave ajena sobre
/// `church_id`, que el motor rellena bien siempre. Sembrar `intentos = 5` deja
/// la cola en exactamente el estado que se quiere medir, sin una sola petición
/// de red y sin escribir nada en el servidor. Que cinco fallos lleven ahí ya lo
/// dice el código: `intentos + 1` en el `catch` (`:282`) y
/// `guard op.intentos < maxIntentos` (`:271`).
///
/// **Limpia lo que siembra**, en `tearDown` y por su `registroId`, que lleva
/// una marca para poder encontrarlo.
@MainActor
final class ApartadaTrasCincoIntentosTests: XCTestCase {

    private let marca = "qa-apartada-"
    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    override func tearDown() async throws {
        try? await cola.write { db in
            try db.execute(sql: "delete from outbox where registroId like ?",
                           arguments: ["\(self.marca)%"])
        }
        await MotorSincronizacion.compartido.recontarPendientes()
    }

    private func sembrarApartada(entidad: String) async throws -> String {
        let id = "\(marca)\(entidad)-\(UUID().uuidString.prefix(8))"
        try await cola.write { db in
            try db.execute(sql: """
                insert into outbox (entidad, registroId, operacion, creadoEn,
                                    intentos, ultimoError)
                values (?, ?, 'actualizar', ?, ?, ?)
                """, arguments: [entidad, id, Date().timeIntervalSince1970,
                                 MotorSincronizacion.maxIntentos,
                                 "duplicate key value violates unique constraint"])
        }
        return id
    }

    // MARK: - Lo que la app SÍ dice

    func testLaAppDiceCuantasSeApartaronYQueDijoElServidor() async throws {
        let motor = MotorSincronizacion.compartido
        await motor.recontarPendientes()
        let antes = motor.atascadas

        _ = try await sembrarApartada(entidad: "acta")
        await motor.recontarPendientes()

        XCTAssertEqual(motor.atascadas, antes + 1, "no se contó como apartada")
        print("QA-APARTADA: atascadas=\(motor.atascadas) · " +
              "pendientes=\(motor.pendientes) · «\(motor.pendientesLegible)»")
        print("QA-APARTADA-ERROR: «\(motor.ultimoErrorDeSubida ?? "nil")»")

        // El error del servidor se conserva, que es de donde salen la tabla y
        // el id para ir a mirar.
        XCTAssertNotNil(motor.ultimoErrorDeSubida)
        XCTAssertTrue(motor.ultimoErrorDeSubida?.contains("duplicate key") ?? false)
    }

    /// **Y lo que NO dice: «Sin subir» las mete dentro del total.** La fila de
    /// Ajustes · Sincronización enseña `pendientesLegible`, que es «N cambios»
    /// a secas (`MotorSincronizacion:147`): una operación apartada se cuenta
    /// ahí igual que una que acaba de entrar y espera turno. Quien lee no puede
    /// distinguir «tres cambios subiendo» de «tres cambios que no van a subir».
    ///
    /// El número de apartadas sí aparece, pero en OTRO renglón —la línea de
    /// estado, que pasa a decir «N cambios no pudieron subir: …»
    /// (`:224-230`)—, y solo cuando el motor está en reposo.
    func testSinSubirNoDistingueLoApartadoDeLoQueEsperaTurno() async throws {
        let motor = MotorSincronizacion.compartido
        _ = try await sembrarApartada(entidad: "acta")
        await motor.recontarPendientes()

        XCTAssertGreaterThan(motor.atascadas, 0)
        // La frase que se lee en la fila «Sin subir» no menciona lo apartado.
        let frase = motor.pendientesLegible
        print("QA-APARTADA-FRASE: «Sin subir» dice «\(frase)» con " +
              "\(motor.atascadas) apartadas de \(motor.pendientes)")
        XCTAssertFalse(frase.lowercased().contains("no pud"), """
            «Sin subir» ya distingue lo apartado. Si es así, esto está \
            arreglado y hay que reescribir esta prueba al revés.
            """)
    }

    // MARK: - El hallazgo: 15 de 17 entidades no lo enseñan en su fila

    /// **`subida(_:_:)` existe para todas y la interfaz solo pregunta por dos.**
    ///
    /// El motor sabe decir, por entidad y por id, si algo está `.alDia`,
    /// `.enCola` o `.noSubio` —y `.noSubio` es el rojo que el propio comentario
    /// describe como «alguien tiene que mirarlo»—. El reparto de `subir(_:)`
    /// atiende **17 entidades**. Pero solo dos pantallas preguntan:
    /// `MovimientosView:872` y `EditarRecurrenteView:169`.
    ///
    /// Así que un acta, una carta, un corte, un depósito, un miembro o un
    /// aportante que no haya podido subir **no se ve en su propia fila**: la app
    /// dice cuántas y qué dijo el servidor del ÚLTIMO, y no hay forma de llegar
    /// a las demás. Es lo que el encargo describía como «no hay lista de qué
    /// quedó fuera», y el dato para hacerla ya está en `seRindieron`.
    func testElEstadoPorFilaSeCalculaParaTodasYSoloSeEnsenaEnDos() async throws {
        let motor = MotorSincronizacion.compartido

        // Un acta apartada: el motor lo sabe…
        let idActa = try await sembrarApartada(entidad: "acta")
        await motor.recontarPendientes()
        XCTAssertEqual(motor.subida("acta", idActa), .noSubio, """
            El motor no sabe decir que esta acta se apartó, así que el hueco \
            sería más grande que el de presentación.
            """)

        // …y un movimiento apartado también, que es una de las dos que SÍ se
        // pintan. El contraste es el hallazgo: el dato es el mismo y solo una
        // de las dos llega a la pantalla.
        let idMov = try await sembrarApartada(entidad: "movimiento")
        await motor.recontarPendientes()
        XCTAssertEqual(motor.subida("movimiento", idMov), .noSubio)

        print("QA-APARTADA-FILA: el motor devuelve .noSubio para «acta» y para " +
              "«movimiento»; la interfaz solo pregunta por movimiento y " +
              "movimientoRecurrente")

        // Y una que no está en la cola sigue estando al día: control positivo,
        // porque sin él `.noSubio` podría ser lo que devuelve siempre.
        XCTAssertEqual(motor.subida("acta", "\(marca)inexistente"), .alDia,
                       "devuelve .noSubio para algo que no está en la cola")
    }

    /// Despertar las apartadas no borra nada: pone `intentos` a cero y las deja
    /// en la cola. Se comprueba sobre la sembrada, sin llamar a `sincronizar`
    /// —que saldría a la red—.
    func testDespertarNoTiraLaOperacion() async throws {
        let motor = MotorSincronizacion.compartido
        let id = try await sembrarApartada(entidad: "acta")
        await motor.recontarPendientes()
        let pendientesAntes = motor.pendientes

        try await cola.write { db in
            try db.execute(sql: "update outbox set intentos = 0 where intentos >= ?",
                           arguments: [MotorSincronizacion.maxIntentos])
        }
        await motor.recontarPendientes()

        XCTAssertEqual(motor.pendientes, pendientesAntes,
                       "despertar las apartadas perdió operaciones de la cola")
        XCTAssertEqual(motor.subida("acta", id), .enCola,
                       "tras despertarla debería estar en cola, no apartada")
    }
}
