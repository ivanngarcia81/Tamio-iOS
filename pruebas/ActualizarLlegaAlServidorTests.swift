import XCTest
import Supabase
@testable import Tamio

/// **La vuelta que cierra la anterior.**
///
/// `CorreccionLlegaAlServidorTests` deja la fila en el servidor con
/// `estado = 'aprobado'`, y eso NO demuestra lo que hay que demostrar: una fila
/// que sube ya aprobada da el mismo resultado final que una que sube pendiente
/// y luego se ACTUALIZA. El tramo sin probar es el segundo —el `UPDATE`—, que
/// es justo donde el 10-sep se encontró que `updated_at` no se movía.
///
/// Aquí la prueba consulta el servidor ELLA MISMA entre las dos
/// sincronizaciones, así que la distinción queda escrita en el resultado y no
/// depende de que alguien mire la base a tiempo.
final class ActualizarLlegaAlServidorTests: XCTestCase {

    private struct FilaRemota: Decodable { let uid: String; let estado: String? }

    private func estadoRemoto(_ uid: String) async throws -> String? {
        let filas: [FilaRemota] = try await supabase.from("transactions")
            .select("uid,estado").eq("uid", value: uid).execute().value
        return filas.first?.estado
    }

    func testElUpdateDeUnaCorreccionLlegaAlServidor() async throws {
        XCTAssertFalse(ModoRevision.sinLogin,
                       "con el modo revisión encendido no se toca Supabase")

        let movimientos = OfflineMovimientosRepository()
        let bandeja = RevisarCalculado()
        let motor = MotorSincronizacion.compartido

        let id = UUID().uuidString
        let marca = "QAUPD\(Int(Date().timeIntervalSince1970) % 1_000_000)"
        let m = Movimiento(
            id: id, tipo: .gasto, categoria: "Limpieza",
            persona: "Prueba de aparato", folio: marca, metodo: "Efectivo",
            monto: 9_99, hora: "10:00", fecha: Date(),
            registradoPor: "prueba-aparato", miembro: nil,
            categoriaCompleta: "Limpieza",
            nota: marca, sinDepositar: false,
            comprobante: nil, auditoria: [],
            pagadoA: "Proveedor de prueba", estadoRevision: .pendiente,
            incluidoEnCorte: false, darConstanciaAnual: false,
            repiteMensual: false)
        try await movimientos.crear(m)
        print("QA2-UID:\(id)")

        // 1. Sube como PENDIENTE. Si esto no es "pendiente", lo de abajo no
        //    mide el UPDATE y hay que decirlo en vez de dar por bueno el final.
        await motor.sincronizar()
        let trasCrear = try await estadoRemoto(id)
        print("QA2-REMOTO-TRAS-CREAR:\(trasCrear ?? "«no está»")")
        XCTAssertEqual(trasCrear, "pendiente",
                       "la fila no llegó al servidor como pendiente: la prueba del UPDATE no sería concluyente")

        // 2. La corrección, y su subida. ESTE es el tramo que se prueba.
        await bandeja.aprobar(id: "tx-\(id)-vistoBueno")
        await motor.sincronizar()

        let trasAprobar = try await estadoRemoto(id)
        print("QA2-REMOTO-TRAS-APROBAR:\(trasAprobar ?? "«no está»")")
        XCTAssertEqual(trasAprobar, "aprobado",
                       "el UPDATE de la corrección NO llegó al servidor")

        // 3. Y la vuelta contraria, que es la que usa «devolver» en la bandeja.
        await bandeja.devolver(id: "tx-\(id)-vistoBueno")
        await motor.sincronizar()
        let trasDevolver = try await estadoRemoto(id)
        print("QA2-REMOTO-TRAS-DEVOLVER:\(trasDevolver ?? "«no está»")")
        XCTAssertEqual(trasDevolver, "rechazado",
                       "devolver no llegó al servidor")
    }
}
