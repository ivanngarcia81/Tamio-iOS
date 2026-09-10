import XCTest
@testable import Tamio

/// **La prueba que el §0.-8 dejó pendiente: que una corrección de «Por revisar»
/// LLEGUE AL SERVIDOR.**
///
/// El arreglo de la bandeja se comprobó contra la base local y ahí funciona.
/// Lo que nunca se ejercitó es el tramo siguiente: que el `actualizar` que la
/// corrección dispara salga del aparato y cambie la fila de `transactions`. Es
/// justo el tramo donde el 10-sep se encontró que `updated_at` no se movía.
///
/// **Corre EN EL APARATO, alojada en la app real** (`church.tamio.native`), que
/// es la única forma de tener la sesión de verdad: en un iPhone el llavero NO
/// se comparte entre apps, así que una copia con otro bundle id se quedaría en
/// la pantalla de acceso (el §3 avisa de lo contrario, pero eso vale para el
/// SIMULADOR).
///
/// Imprime `QA-UID:` y `QA-FOLIO:` para poder contrastar la fila en Supabase
/// desde fuera: la prueba dice que el aparato cree haberlo subido, y el
/// `select` es lo que dice que llegó.
final class CorreccionLlegaAlServidorTests: XCTestCase {

    func testUnaCorreccionDeLaBandejaLlegaAlServidor() async throws {
        XCTAssertFalse(ModoRevision.sinLogin,
                       "con el modo revisión encendido no se toca Supabase: esta prueba no mide nada")

        let movimientos = OfflineMovimientosRepository()
        let bandeja = RevisarCalculado()
        let motor = MotorSincronizacion.compartido

        // 1. Un gasto PENDIENTE, con id de verdad (UUID con guiones), que es lo
        //    que la maqueta escondía.
        let id = UUID().uuidString
        let marca = "QA\(Int(Date().timeIntervalSince1970) % 1_000_000)"
        let m = Movimiento(
            id: id, tipo: .gasto, categoria: "Limpieza",
            persona: "Prueba de aparato", folio: marca, metodo: "Efectivo",
            monto: 12_50, hora: "10:00", fecha: Date(),
            registradoPor: "prueba-aparato", miembro: nil,
            categoriaCompleta: "Limpieza",
            nota: marca, sinDepositar: false,
            comprobante: nil, auditoria: [],
            pagadoA: "Proveedor de prueba", estadoRevision: .pendiente,
            incluidoEnCorte: false, darConstanciaAnual: false,
            repiteMensual: false)
        try await movimientos.crear(m)
        print("QA-UID:\(id)")
        print("QA-MARCA:\(marca)")

        let sembrado = try await movimientos.porId(id)
        XCTAssertEqual(sembrado?.estadoRevision, .pendiente,
                       "el gasto no se sembró como pendiente")

        // 2. Subirlo.
        await motor.sincronizar()
        print("QA-ESTADO-TRAS-CREAR:\(await estadoDe(motor))")

        // 3. La corrección: aprobar desde la bandeja, con el id de asunto que
        //    la calculadora construye —`tx-<uuid>-vistoBueno`—, que es
        //    exactamente el que se partía por el primer guion.
        await bandeja.aprobar(id: "tx-\(id)-vistoBueno")

        let corregido = try await movimientos.porId(id)
        XCTAssertEqual(corregido?.estadoRevision, .aprobado,
                       "la aprobación no llegó ni a la base LOCAL")

        // 4. Subir la corrección. Este es el tramo que nunca se había probado.
        await motor.sincronizar()
        print("QA-ESTADO-TRAS-APROBAR:\(await estadoDe(motor))")
        print("QA-FIN:\(id)")
    }

    private func estadoDe(_ motor: MotorSincronizacion) async -> String {
        await MainActor.run { String(describing: motor.estado) }
    }
}
