import XCTest
import Supabase
import GRDB
@testable import Tamio

/// **Z1: morir entre el envío y la respuesta.** Es lo que el `upsert` existe
/// para cubrir y lo que ninguna prueba había provocado.
///
/// **No se mata la app, y no hace falta.** Matarla en el microsegundo exacto no
/// se puede pedir a XCUITest, y además el proceso de pruebas moriría con ella.
/// Pero la caída no tiene más consecuencia que UNA: el servidor ya escribió y
/// la fila de `outbox` **no llegó a borrarse**, porque el borrado va después del
/// `try await subir(op)` (`MotorSincronizacion:274`). Ese estado se reproduce
/// exacto volviendo a encolar la operación, y entonces la pregunta que importa
/// se puede contestar: **¿el reintento crea una segunda fila, o actualiza la
/// misma?**
///
/// Esta prueba **escribe en la base de la iglesia**: crea un movimiento, lo
/// sube y lo da de baja al acabar. Va marcado `registradoPor = "prueba-aparato"`
/// para poder encontrarlo, como manda el traspaso. **El folio que consume no se
/// recupera** — eso es el precio de esta medida y conviene saberlo antes de
/// correrla.
final class ReintentoTrasCaidaTests: XCTestCase {

    /// **La columna es `concepto`, no `nota`.** El `nota` del modelo es
    /// `transactions.concepto` en el servidor; `transactions.notas` existe y es
    /// OTRA cosa —las notas de auditoría—. Pedir `nota` da un 42703 con la
    /// pista puesta: «Perhaps you meant to reference the column
    /// transactions.notas», que apunta a la columna equivocada de las dos.
    private struct FilaRemota: Decodable {
        let uid: String
        let folio: String?
        let deleted: Bool?
        let concepto: String?
    }

    private func remotas(uid: String) async throws -> [FilaRemota] {
        try await supabase.from("transactions")
            .select("uid,folio,deleted,concepto").eq("uid", value: uid).execute().value
    }

    /// Por CONCEPTO y no por uid: es lo que caza un duplicado que haya entrado
    /// con otro uid, que es justo el fallo que se busca.
    private func remotas(concepto: String) async throws -> [FilaRemota] {
        try await supabase.from("transactions")
            .select("uid,folio,deleted,concepto")
            .eq("concepto", value: concepto).execute().value
    }

    private var cola: DatabaseQueue { BaseLocal.compartida.cola }

    /// Vuelve a poner la operación en la cola: el estado exacto en que la deja
    /// una caída después de que el servidor haya escrito.
    private func reencolarComoSiHubieraMuerto(_ id: String) async throws {
        try await cola.write { db in
            try db.execute(sql: """
                insert into outbox (entidad, registroId, operacion, creadoEn, intentos)
                values ('movimiento', ?, 'crear', ?, 0)
                """, arguments: [id, Date().timeIntervalSince1970])
        }
    }

    func testElReintentoTrasUnaCaidaNoDuplicaLaFila() async throws {
        XCTAssertFalse(ModoRevision.sinLogin,
                       "con el modo revisión encendido no se toca Supabase")

        let movimientos = OfflineMovimientosRepository()
        let motor = MotorSincronizacion.compartido
        let id = UUID().uuidString
        let marca = "QA-CAIDA-\(Int(Date().timeIntervalSince1970) % 1_000_000)"

        let m = Movimiento(
            id: id, tipo: .gasto, categoria: "Limpieza",
            persona: "Prueba de aparato", folio: "", metodo: "Efectivo",
            monto: 1_23, hora: "10:00", fecha: Date(),
            registradoPor: "prueba-aparato", miembro: nil,
            categoriaCompleta: "Limpieza", nota: marca, sinDepositar: false,
            comprobante: nil, auditoria: [],
            pagadoA: "Proveedor de prueba", estadoRevision: .aprobado,
            incluidoEnCorte: false, darConstanciaAnual: false,
            repiteMensual: false)
        try await movimientos.crear(m)
        print("QA-CAIDA-UID:\(id) · marca=\(marca)")


        // 1 · **La subida que SÍ llega, esperándola.** Una sola llamada a
        //     `sincronizar()` no basta: la app sincroniza al arrancar y
        //     `sincronizar()` se da la vuelta en la primera línea si ya está en
        //     marcha (`guard estado != .sincronizando`). La primera versión de
        //     esta prueba daba por subida la fila y no estaba: el movimiento se
        //     quedó local, el `eliminar` lo relevó en la cola, y al servidor no
        //     llegó nada. Es el aviso del LEEME —«sincronizar ANTES de
        //     mirar»— con una vuelta más: hay que sincronizar hasta que se vea.
        var trasPrimera: [FilaRemota] = []
        for intento in 0..<8 {
            await motor.sincronizar()
            trasPrimera = try await remotas(uid: id)
            if !trasPrimera.isEmpty { break }
            print("QA-CAIDA-ESPERANDO: intento \(intento + 1), aún no está arriba")
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        XCTAssertEqual(trasPrimera.count, 1,
                       "la fila no llegó al servidor: el resto no mediría nada")
        try XCTSkipIf(trasPrimera.isEmpty,
                      "sin la fila arriba no hay reintento que medir")
        let folioPrimero = trasPrimera.first?.folio
        print("QA-CAIDA-TRAS-PRIMERA: filas=\(trasPrimera.count) folio=\(folioPrimero ?? "nil")")

        // 2 · El estado que deja la caída: el servidor ya escribió y la
        //     operación sigue en la cola.
        try await reencolarComoSiHubieraMuerto(id)
        await motor.recontarPendientes()
        XCTAssertGreaterThan(motor.pendientes, 0, "no se reencoló nada")

        // 3 · El reintento. ESTO es lo que se mide.
        await motor.sincronizar()

        let porUid = try await remotas(uid: id)
        let porNota = try await remotas(concepto: marca)
        print("QA-CAIDA-TRAS-REINTENTO: por uid=\(porUid.count) · por nota=\(porNota.count) · " +
              "folios=\(porNota.compactMap(\.folio))")

        XCTAssertEqual(porUid.count, 1, "el uid se duplicó, que no debería poder pasar")
        XCTAssertEqual(porNota.count, 1, """
            El reintento creó una SEGUNDA fila para el mismo apunte \
            (\(porNota.count) con la marca \(marca)). El `upsert onConflict: \
            "uid"` existe justo para que esto no pase: si hay dos, el reintento \
            entró con un uid nuevo.
            """)

        // 4 · Y el folio no se gasta dos veces. `MotorSincronizacion:903` dice
        //     que el número queda reservado y no se pide otro en el reintento;
        //     esto lo comprueba.
        XCTAssertEqual(porUid.first?.folio, folioPrimero, """
            El folio cambió entre la primera subida y el reintento \
            (\(folioPrimero ?? "nil") → \(porUid.first?.folio ?? "nil")): el \
            reintento pidió un número nuevo y el anterior se perdió.
            """)

        // 5 · La cola queda limpia: el reintento sí borró su operación.
        await motor.recontarPendientes()
        print("QA-CAIDA-COLA-FINAL: pendientes=\(motor.pendientes) atascadas=\(motor.atascadas)")

        // **La limpieza va aquí y se ESPERA.** El primer intento la puso en un
        // `defer` con un `Task {}` suelto: eso no se espera, el proceso de
        // pruebas se acaba antes y la baja se queda sin sincronizar. Lo que dejó
        // en el aparato fue una fila local borrada con un `eliminar` en la cola.
        try await movimientos.eliminar(id: id)
        for _ in 0..<6 {
            await motor.sincronizar()
            let fin = try await remotas(uid: id)
            if fin.first?.deleted == true { break }
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        let fin = try await remotas(uid: id)
        print("QA-CAIDA-LIMPIEZA: borrado=\(fin.first?.deleted.map(String.init) ?? "«no está»")")
        XCTAssertTrue(fin.isEmpty || fin.first?.deleted == true,
                      "lo que sembró esta prueba se quedó vivo en el servidor")
    }
}
