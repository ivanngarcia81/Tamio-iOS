import XCTest
@testable import Tamio

/// **Z6: los recurrentes del 1 de octubre, sin mover el reloj.**
///
/// El encargo decía que esto solo se puede medir adelantando la hora del
/// aparato, y que hacerlo es caro: los movimientos que se generan son reales y
/// suben al servidor. No hace falta. `MesesRecurrentes.pendientes` recibe `hoy`
/// **por parámetro** y es una función pura, así que el 1 de octubre se puede
/// simular con una cadena — y lo que de verdad importaba, según el propio
/// encargo, «no es que generen: es que no dupliquen entre el iPhone y el
/// iPad», se decide en el ID del movimiento generado, que se lee en el código.
///
/// Esta prueba no escribe nada y no necesita el aparato.
final class RecurrentesDuplicadosTests: XCTestCase {

    private func definicion(mesInicio: String,
                            ultimoMesGenerado: String?) -> MovimientoRecurrente {
        var d = MovimientoRecurrente(id: "r1", tipo: .gasto, categoria: "Servicios",
                                     monto: 20_000, metodo: "Transferencia",
                                     dia: 1, mesInicio: mesInicio)
        d.ultimoMesGenerado = ultimoMesGenerado
        d.pagadoA = "Proveedor de prueba"
        return d
    }

    // MARK: - La ventana, que es lo fácil

    /// La ventana termina en el MES PASADO: el mes en curso no se contabiliza
    /// hasta que acaba. Así que el 1 de octubre se genera septiembre, no
    /// octubre.
    func testElPrimeroDeOctubreGeneraSeptiembreYNoOctubre() {
        let (meses, marca) = MesesRecurrentes.pendientes(
            mesInicio: "2026-09", ultimoMesGenerado: nil, hoy: "2026-10")
        XCTAssertEqual(meses, ["2026-09"], "debería generar septiembre y solo septiembre")
        XCTAssertEqual(marca, "2026-09")
    }

    /// Una app cerrada varios meses se pone al día de una vez, sin colarse en
    /// el futuro.
    func testUnaAppCerradaCuatroMesesSePoneAlDiaSinPasarseDeHoy() {
        let (meses, marca) = MesesRecurrentes.pendientes(
            mesInicio: "2026-06", ultimoMesGenerado: nil, hoy: "2026-10")
        XCTAssertEqual(meses, ["2026-06", "2026-07", "2026-08", "2026-09"])
        XCTAssertEqual(marca, "2026-09")
        XCTAssertFalse(meses.contains("2026-10"), "nunca se generan meses futuros")
    }

    /// Y la segunda vez que se abre el mismo mes ya no genera nada: es la
    /// idempotencia DENTRO de un aparato, que sí está resuelta.
    func testAbrirDosVecesElMismoMesNoGeneraDosVeces() {
        let primera = MesesRecurrentes.pendientes(
            mesInicio: "2026-09", ultimoMesGenerado: nil, hoy: "2026-10")
        XCTAssertEqual(primera.meses, ["2026-09"])
        // Con la marca ya puesta —que es lo que `marcarGenerado` escribe—:
        let segunda = MesesRecurrentes.pendientes(
            mesInicio: "2026-09", ultimoMesGenerado: primera.marcaHasta, hoy: "2026-10")
        XCTAssertEqual(segunda.meses, [], "el mismo mes se generó dos veces")
    }

    // MARK: - Los DOS aparatos, que es lo que el encargo quería saber

    /// **Dos aparatos que abren la app el mismo día generan el mismo mes, y el
    /// movimiento que crean NO tiene id determinista.**
    ///
    /// `MaterializadorRecurrentes.alDia` no consulta si ya existe un
    /// movimiento de esa definición para ese mes: solo mira
    /// `def.ultimoMesGenerado`. Y el movimiento nace con `id: ""`
    /// (`RecurrentesRepository:249`), que
    /// `OfflineMovimientosRepository.crear` rellena con
    /// `UUID().uuidString` (`:48`).
    ///
    /// Así que si el iPhone y el iPad abren la app antes de que la marca del
    /// primero haya sincronizado, los dos generan la renta de septiembre con
    /// **uids distintos**, `transactions` acepta las dos —su única restricción
    /// es la clave primaria sobre `uid`, comprobado en el servidor: no hay
    /// nada único sobre recurrente+mes— y la renta queda **dos veces en los
    /// libros**, con dos folios consumidos que no se recuperan.
    ///
    /// Lo único que lo evita hoy es que la marca llegue antes, y eso es una
    /// carrera, no una garantía.
    func testDosAparatosGeneranElMismoMesConIdsDistintos() throws {
        let enElIPhone = definicion(mesInicio: "2026-09", ultimoMesGenerado: nil)
        let enElIPad = definicion(mesInicio: "2026-09", ultimoMesGenerado: nil)

        let a = MesesRecurrentes.pendientes(mesInicio: enElIPhone.mesInicio,
                                            ultimoMesGenerado: enElIPhone.ultimoMesGenerado,
                                            hoy: "2026-10")
        let b = MesesRecurrentes.pendientes(mesInicio: enElIPad.mesInicio,
                                            ultimoMesGenerado: enElIPad.ultimoMesGenerado,
                                            hoy: "2026-10")
        XCTAssertEqual(a.meses, b.meses)
        XCTAssertEqual(a.meses, ["2026-09"])

        let fecha = try XCTUnwrap(MesesRecurrentes.fecha(en: "2026-09", dia: 1))
        let m1 = MaterializadorRecurrentes.movimiento(de: enElIPhone, en: fecha)
        let m2 = MaterializadorRecurrentes.movimiento(de: enElIPad, en: fecha)

        print("QA-RECURRENTE: mes=\(a.meses) · id1=«\(m1.id)» id2=«\(m2.id)» · " +
              "recurrenteId=\(m1.recurrenteId ?? "nil") · monto=\(m1.monto)")

        // Los dos movimientos son EL MISMO apunte: misma definición, mismo mes,
        // mismo importe, misma fecha.
        XCTAssertEqual(m1.recurrenteId, m2.recurrenteId)
        XCTAssertEqual(m1.monto, m2.monto)
        XCTAssertEqual(m1.fecha, m2.fecha)

        // **Y aquí está el agujero: el id viene vacío, así que lo pone un UUID
        // nuevo en cada aparato y el `upsert onConflict: "uid"` no los puede
        // reconocer como el mismo.** Esta afirmación describe el estado de HOY
        // a propósito: el día que el id se derive de `recurrenteId + mes`, esta
        // prueba fallará y eso será la señal de que el agujero se cerró.
        XCTAssertEqual(m1.id, "", """
            El movimiento generado ya trae id. Si ahora es determinista \
            —derivado de recurrenteId + mes—, el duplicado entre aparatos está \
            resuelto y esta prueba hay que reescribirla al revés.
            """)
        XCTAssertEqual(m2.id, "")
    }

    /// El interruptor sobre un movimiento recién capturado: ese mes ya está
    /// cubierto y no se vuelve a generar, pero sí se da por hecho. Es el caso
    /// que el web resuelve con `skipMes`.
    func testElMesQueSeSaltaNoSeGeneraPeroSiSeMarca() {
        let (meses, marca) = MesesRecurrentes.pendientes(
            mesInicio: "2026-09", ultimoMesGenerado: nil,
            hoy: "2026-09", saltar: "2026-09")
        XCTAssertEqual(meses, [], "el mes ya capturado no se vuelve a generar")
        XCTAssertEqual(marca, "2026-09", """
            El mes saltado no quedó marcado, así que el mes que viene se \
            volvería a mirar y la renta saldría dos veces.
            """)
    }

    /// El día se ajusta a la longitud del mes y se construye en UTC al
    /// mediodía, para que ninguna conversión de huso lo mueva de mes. Es la
    /// misma familia que el hallazgo nº 1 de esta pasada.
    func testElDiaTreintaYUnoEnFebreroYElMediodiaUTC() throws {
        let feb = try XCTUnwrap(MesesRecurrentes.fecha(en: "2026-02", dia: 31))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        XCTAssertEqual(f.string(from: feb), "2026-02-28 12:00")

        let abr = try XCTUnwrap(MesesRecurrentes.fecha(en: "2026-04", dia: 31))
        XCTAssertEqual(f.string(from: abr), "2026-04-30 12:00")

        // Y el mediodía es lo que lo salva al oeste de Greenwich: en local
        // sigue siendo el mismo DÍA.
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(local.string(from: feb), "2026-02-28",
                       "la fecha del recurrente se movió de día en la zona del aparato")
    }
}
