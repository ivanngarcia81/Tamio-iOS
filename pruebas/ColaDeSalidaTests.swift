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

        XCTAssertEqual(try await ordenDeSubida(), ["miembro", "movimiento"],
                       "el alta se encoló primero, así que tiene que salir primera")

        var corregida = m
        corregida.telefono = "555 1234"
        try await padron.guardar(corregida)

        XCTAssertEqual(try await ordenDeSubida(), ["miembro", "movimiento"],
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
        let alta = try await XCTUnwrap(cola().first)

        try await movimientos.eliminar(id: "mov-3")

        let operaciones = try await operacionesDe("movimiento")
        XCTAssertEqual(operaciones.count, 1)
        XCTAssertEqual(operaciones.first?.operacion,
                       OperacionPendiente.Operacion.eliminar.rawValue,
                       "la baja releva al alta")
        XCTAssertEqual(operaciones.first?.creadoEn, alta.creadoEn,
                       "pero se queda en el turno que ya tenía")
    }
}
