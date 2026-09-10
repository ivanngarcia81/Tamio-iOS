import XCTest
@testable import Tamio

/// **La bandeja «Por revisar» con ids de VERDAD, que son UUID.**
///
/// El id de un asunto es `"tx-<id del movimiento>-<tipo>"`, y para deshacerlo
/// `RevisarCalculado.movimiento(de:)` hacía
/// `split(separator: "-", maxSplits: 2)` y se quedaba con `partes[1]`. Con los
/// ids de la maqueta —"1", "207"— eso funciona, y por eso la pantalla parecía
/// sana en modo revisión. Con los de verdad, que
/// `OfflineMovimientosRepository.crear` genera con `UUID().uuidString`, el
/// primer guion del UUID parte el id: `partes[1]` es solo su primer trozo,
/// `porId` no encuentra nada y **todas las acciones de la bandeja se van por el
/// `guard` sin hacer nada y sin decirlo** — aprobar, devolver, revertir y
/// editar.
///
/// Es la trampa que el traspaso lleva avisando desde el §2.2: la maqueta
/// esconde justo lo que hay que probar. Aquí se prueba con el id que la app
/// genera de verdad.
///
/// **Cómo se corre** — con el modo revisión **APAGADO** (que es como se compila
/// la app) y contra la base local. Sin sesión no sube nada: las operaciones se
/// quedan en la cola de salida y el motor no se llama.
final class BandejaConIdReal: XCTestCase {

    let repo = RevisarCalculado()
    let movimientos = OfflineMovimientosRepository()

    /// Un gasto pendiente de visto bueno, **con un id de la forma que la app
    /// genera de verdad**: `UUID().uuidString`, con sus cuatro guiones. Se pasa
    /// hecho en vez de dejar que lo ponga `crear` porque `crear` no lo devuelve
    /// y además reescribe el folio con la secuencia local, así que por folio no
    /// se puede localizar.
    func sembrarGastoPendiente(folio: String) async throws -> Movimiento {
        let id = UUID().uuidString
        let m = Movimiento(
            id: id, tipo: .gasto, categoria: L.t("Limpieza", "Cleaning"),
            persona: "Prueba", folio: folio, metodo: L.t("Efectivo", "Cash"),
            monto: 60_000, hora: "10:00", fecha: Date(),
            registradoPor: "prueba", miembro: nil,
            categoriaCompleta: L.t("Limpieza", "Cleaning"),
            nota: "asunto de prueba", sinDepositar: false,
            comprobante: "prueba.jpg", auditoria: [],
            pagadoA: "Proveedor", estadoRevision: .pendiente,
            incluidoEnCorte: false, darConstanciaAnual: false,
            repiteMensual: false)
        try await movimientos.crear(m)
        let leido = try await movimientos.porId(id)
        let creado = try XCTUnwrap(leido, "el gasto sembrado no está en la base")
        print("ID-REAL:\(creado.id)")
        XCTAssertTrue(creado.id.contains("-"),
                      "el id de verdad tiene que traer guiones, o esta prueba no prueba nada")
        return creado
    }

    func asuntoDe(_ m: Movimiento) async throws -> Revision {
        let asuntos = await repo.asuntos()
        let a = try XCTUnwrap(asuntos.first { $0.id == "tx-\(m.id)-vistoBueno" },
                              "el movimiento sembrado no salió en la bandeja")
        print("ID-ASUNTO:\(a.id)")
        return a
    }

    /// **Aprobar**, que es el botón principal de la bandeja.
    func testAprobarUnAsuntoConIdDeVerdad() async throws {
        let m = try await sembrarGastoPendiente(folio: "P-9001")
        let asunto = try await asuntoDe(m)

        await repo.aprobar(id: asunto.id)

        let despues = try await movimientos.porId(m.id)
        XCTAssertEqual(despues?.estadoRevision, .aprobado,
                       "Aprobar no tocó el movimiento: sigue en «\(despues?.estadoRevision.rawValue ?? "?")»")
        try? await movimientos.eliminar(id: m.id)
    }

    /// **Devolver al tesorero.**
    func testDevolverUnAsuntoConIdDeVerdad() async throws {
        let m = try await sembrarGastoPendiente(folio: "P-9002")
        let asunto = try await asuntoDe(m)

        await repo.devolver(id: asunto.id)

        let despues = try await movimientos.porId(m.id)
        XCTAssertEqual(despues?.estadoRevision, .rechazado,
                       "Devolver no tocó el movimiento: sigue en «\(despues?.estadoRevision.rawValue ?? "?")»")
        try? await movimientos.eliminar(id: m.id)
    }

    /// **Editar: los cinco campos de la hoja que tocan el movimiento.**
    /// `EditarAsuntoView` ofrece concepto, importe, categoría, método, aportante
    /// y fecha; `actualizar` solo escribía `editCategoria`, y ni esa llegaba
    /// porque el `guard` del id la cortaba antes.
    ///
    /// Se conduce por el ViewModel a propósito: es exactamente lo que hace la
    /// hoja al pulsar "Guardar cambios" (`RevisarView:52`).
    func testEditarGuardaLoQueSeEdita() async throws {
        let m = try await sembrarGastoPendiente(folio: "P-9003")
        let asunto = try await asuntoDe(m)

        let vm = RevisarViewModel(repo: repo)
        await vm.cargar()
        await vm.editar(id: asunto.id,
                        concepto: "Concepto corregido",
                        importe: "1.00",
                        categoria: L.t("Suministros", "Supplies"),
                        metodo: L.t("Transferencia SPEI", "SPEI transfer"),
                        aportante: nil,
                        fecha: Date())

        let leido = try await movimientos.porId(m.id)
        let d = try XCTUnwrap(leido)
        XCTAssertEqual(d.monto, 100,
                       "el importe corregido no se guardó: sigue en \(Money.fmt(d.monto))")
        XCTAssertEqual(d.categoria, L.t("Suministros", "Supplies"), "la categoría no se guardó")
        XCTAssertEqual(d.metodo, L.t("Transferencia SPEI", "SPEI transfer"), "el método no se guardó")
        XCTAssertEqual(d.nota, "Concepto corregido", "el concepto no se guardó")
        try? await movimientos.eliminar(id: m.id)
    }

    /// **Y el importe de la hoja también se lee con el parseador bueno.** El
    /// campo de `EditarAsuntoView` es un `.decimalPad` como el del alta, así que
    /// en región española escribe coma.
    func testElImporteDeLaHojaAguantaLaComa() async throws {
        let m = try await sembrarGastoPendiente(folio: "P-9004")
        let asunto = try await asuntoDe(m)

        let vm = RevisarViewModel(repo: repo)
        await vm.cargar()
        await vm.editar(id: asunto.id, concepto: "Con coma", importe: "12,50",
                        categoria: L.t("Limpieza", "Cleaning"),
                        metodo: L.t("Efectivo", "Cash"), aportante: nil, fecha: Date())

        let leido = try await movimientos.porId(m.id)
        let d = try XCTUnwrap(leido)
        XCTAssertEqual(d.monto, 1250,
                       "«12,50» quedó como \(Money.fmt(d.monto))")
        try? await movimientos.eliminar(id: m.id)
    }
}
