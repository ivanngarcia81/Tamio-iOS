import XCTest
import GRDB
@testable import Tamio

/// **La cola de salida: el orden en que sale y lo que pasa cuando algo no sale.**
///
/// Todo lo de aquí es local —cola, `syncEstado`— y no llama al motor: sin sesión
/// no habría a dónde subir, y correr la sincronización de verdad contra un
/// contenedor con sesión es justo lo que no se hace en este repo.
///
/// Corre contra la base del contenedor, no una en memoria, que es donde vive el
/// `outbox` de verdad.
@MainActor
final class ColaDeSalidaTests: XCTestCase {

    private let movimientos = OfflineMovimientosRepository()
    private let padron = OfflineMembresiaRepository()

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertFalse(BaseLocal.compartida.enMemoria,
                       "La base tenía que abrir EN DISCO: en memoria no se prueba nada de esto")
        try BaseLocal.compartida.limpiar()
    }

    // MARK: - Ayudas

    private func cola() async throws -> [OperacionPendiente] {
        try await BaseLocal.compartida.cola.read { db in
            try OperacionPendiente.order(Column("creadoEn")).fetchAll(db)
        }
    }

    /// El orden en que `subirPendientes` las mandaría, que es lo que se prueba.
    ///
    /// **Sin los apuntes del registro**: dar de baja un movimiento anota además
    /// un `apunte`, que es correcto y no tiene nada que ver con lo de aquí.
    private func ordenDeSubida() async throws -> [String] {
        try await cola().map(\.entidad).filter { $0 != "apunte" }
    }

    private func operacionesDe(_ entidad: String) async throws -> [OperacionPendiente] {
        try await cola().filter { $0.entidad == entidad }
    }

    @discardableResult
    private func sembrarMovimiento(id: String = "mov-1") async throws -> Movimiento {
        let m = Movimiento(id: id, tipo: .ingreso, categoria: "Diezmo", persona: "María",
                           folio: "1042", metodo: "Efectivo", monto: 125_000, hora: "11:20",
                           fecha: Date(), registradoPor: "Tesorero", miembro: "María",
                           categoriaCompleta: "Diezmo · Sobre", nota: "Ofrenda del domingo",
                           sinDepositar: true, comprobante: nil, auditoria: [])
        try await movimientos.crear(m)
        return m
    }

    // MARK: - Que editar algo no lo mande al final de la cola

    /// **El alta tiene que salir antes que lo que se encoló después de ella,
    /// aunque se corrija.**
    ///
    /// Antes no: `encolar` relevaba la operación anterior con una fecha nueva,
    /// así que corregir una ficha que todavía esperaba turno la mandaba al
    /// final. El `update` de otra entidad sobre la MISMA fila de `members`
    /// —`aportante` y `miembro` son las dos caras— salía primero, contra un
    /// `uid` que allá no existía todavía.
    func testCorregirNoMandaElAltaAlFinalDeLaCola() async throws {
        let m = Miembro(id: "p-1", nombre: "Ana Torres")
        try await padron.guardar(m)
        try await sembrarMovimiento()

        let alEncolar = try await ordenDeSubida()
        XCTAssertEqual(alEncolar, ["miembro", "movimiento"],
                       "el alta se encoló primero, así que tiene que salir primera")

        var corregida = m
        corregida.telefono = "555 1234"
        try await padron.guardar(corregida)

        let trasCorregir = try await ordenDeSubida()
        XCTAssertEqual(trasCorregir, ["miembro", "movimiento"],
                       "corregir la ficha no puede colocar el alta detrás de lo que vino después")
    }

    /// La otra mitad del mismo `encolar`, que se toca a la vez y no puede
    /// romperse: un alta que aún no ha salido y se edita **sigue siendo un
    /// alta**. Mandar `update` de algo que allá no existe no actualiza nada.
    func testUnAltaEditadaSigueSiendoUnAlta() async throws {
        let m = Miembro(id: "p-2", nombre: "Pedro Salas")
        try await padron.guardar(m)

        var corregida = m
        corregida.correo = "pedro@ejemplo.mx"
        try await padron.guardar(corregida)

        let operaciones = try await operacionesDe("miembro")
        XCTAssertEqual(operaciones.count, 1, "una sola operación pendiente por registro")
        XCTAssertEqual(operaciones.first?.operacion,
                       OperacionPendiente.Operacion.crear.rawValue)
    }

    /// Y que conservar la fecha no impida que la operación NUEVA sea la que
    /// vale: lo que se releva es el turno, no el contenido.
    func testRelevarConservaElTurnoPeroNoLaOperacionVieja() async throws {
        try await sembrarMovimiento(id: "mov-3")
        let alCrear = try await cola()
        let alta = try XCTUnwrap(alCrear.first)

        try await movimientos.eliminar(id: "mov-3")

        let operaciones = try await operacionesDe("movimiento")
        XCTAssertEqual(operaciones.count, 1)
        XCTAssertEqual(operaciones.first?.operacion,
                       OperacionPendiente.Operacion.eliminar.rawValue,
                       "la baja releva al alta")
        XCTAssertEqual(operaciones.first?.creadoEn, alta.creadoEn,
                       "pero se queda en el turno que ya tenía")
    }

    // MARK: - Que alguien lea `intentos`

    /// Siembra una operación que ya se rindió, sin pasar por la red.
    private func sembrarAtascada(intentos: Int, error: String) async throws {
        _ = try await BaseLocal.compartida.cola.write { db in
            var op = OperacionPendiente(id: nil, entidad: "carta", registroId: "car-1",
                                        operacion: OperacionPendiente.Operacion.crear.rawValue,
                                        creadoEn: Date().timeIntervalSince1970,
                                        intentos: intentos, ultimoError: error)
            try op.insert(db)
        }
    }

    /// **El motor tiene que ENTERARSE de que algo se rindió.**
    ///
    /// Es el bug entero: `intentos` y `ultimoError` se escribían y no los leía
    /// nadie, así que una operación que no podía salir se reintentaba en cada
    /// vuelta mientras la pantalla decía que todo estaba sincronizado.
    func testUnaOperacionRendidaSeCuentaYTraeSuError() async throws {
        try await sembrarAtascada(intentos: MotorSincronizacion.maxIntentos,
                                  error: "duplicate key value violates unique constraint")

        await MotorSincronizacion.compartido.recontarPendientes()

        XCTAssertEqual(MotorSincronizacion.compartido.pendientes, 1)
        XCTAssertEqual(MotorSincronizacion.compartido.atascadas, 1,
                       "la que se rindió tiene que contarse aparte")
        XCTAssertEqual(MotorSincronizacion.compartido.ultimoErrorDeSubida,
                       "duplicate key value violates unique constraint",
                       "y hay que poder saber QUÉ dijo el servidor")
    }

    /// Y la otra mitad: una que falló un par de veces sigue siendo normal. Si
    /// contara como atascada, la primera vez sin cobertura la app diría que hay
    /// cambios que no pudieron subir cuando solo hacía falta esperar.
    func testUnaQueFalloPocasVecesNoSeDaPorPerdida() async throws {
        try await sembrarAtascada(intentos: MotorSincronizacion.maxIntentos - 1,
                                  error: "The Internet connection appears to be offline.")

        await MotorSincronizacion.compartido.recontarPendientes()

        XCTAssertEqual(MotorSincronizacion.compartido.pendientes, 1)
        XCTAssertEqual(MotorSincronizacion.compartido.atascadas, 0)
        XCTAssertNil(MotorSincronizacion.compartido.ultimoErrorDeSubida)
    }

    /// Con la cola limpia no puede quedar rastro de la vuelta anterior: el
    /// motor es un singleton y sus contadores viven entre pruebas.
    func testConLaColaVaciaNoQuedaNadaAtascado() async throws {
        try await sembrarAtascada(intentos: MotorSincronizacion.maxIntentos, error: "algo")
        await MotorSincronizacion.compartido.recontarPendientes()
        XCTAssertEqual(MotorSincronizacion.compartido.atascadas, 1)

        try BaseLocal.compartida.limpiar()
        await MotorSincronizacion.compartido.recontarPendientes()

        XCTAssertEqual(MotorSincronizacion.compartido.pendientes, 0)
        XCTAssertEqual(MotorSincronizacion.compartido.atascadas, 0)
        XCTAssertNil(MotorSincronizacion.compartido.ultimoErrorDeSubida)
    }

    // MARK: - Hasta dónde puede llegar el cursor de una bajada

    /// Sin huecos, el cursor llega hasta la última fila del lote, que es lo que
    /// hacía siempre y sigue estando bien.
    func testSinHuecosElCursorLlegaHastaElFinal() {
        var a = MotorSincronizacion.AvanceCursor()
        a.aplicada("2026-09-08T10:00:00Z")
        a.aplicada("2026-09-08T11:00:00Z")
        a.aplicada("2026-09-08T12:00:00Z")
        XCTAssertEqual(a.cursor, "2026-09-08T12:00:00Z")
    }

    /// **Lo que estaba roto.** Una fila saltada por tener algo pendiente de
    /// subir no se aplicaba y el cursor pasaba por encima igual, así que esa
    /// versión del servidor no se volvía a pedir nunca —la consulta es `>`—.
    /// Ahora el cursor se planta en el hueco.
    func testElCursorSePlantaEnElPrimerHueco() {
        var a = MotorSincronizacion.AvanceCursor()
        a.aplicada("2026-09-08T10:00:00Z")
        a.saltada()
        a.aplicada("2026-09-08T12:00:00Z")
        XCTAssertEqual(a.cursor, "2026-09-08T10:00:00Z",
                       "lo de después del hueco se aplica, pero no se da por leído")
    }

    /// Si el hueco es la primera fila no hay nada nuevo que dar por leído, y el
    /// cursor se queda como estaba: `nil` significa "no guardes ninguno".
    func testUnHuecoEnLaPrimeraFilaNoMueveElCursor() {
        var a = MotorSincronizacion.AvanceCursor()
        a.saltada()
        a.aplicada("2026-09-08T12:00:00Z")
        XCTAssertNil(a.cursor)
    }

    /// Una fila sin `updated_at` no puede servir de marca: guardarla como
    /// cursor sería guardar nulo y volver a bajarlo todo desde el principio.
    func testUnaFilaSinMarcaNoMueveElCursor() {
        var a = MotorSincronizacion.AvanceCursor()
        a.aplicada("2026-09-08T10:00:00Z")
        a.aplicada(nil)
        XCTAssertEqual(a.cursor, "2026-09-08T10:00:00Z")
    }
}
