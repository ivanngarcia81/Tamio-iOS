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

    /// **Dos aparatos que abren la app el mismo día generan el mismo mes, y
    /// ahora el movimiento que crean tiene el MISMO id.**
    ///
    /// Hasta el 13-sep nacía con `id: ""` y `OfflineMovimientosRepository.crear`
    /// le ponía un `UUID()` nuevo (`:48`), así que si el iPhone y el iPad
    /// abrían la app antes de que `ultimoMesGenerado` sincronizara, los dos
    /// generaban la renta del mismo mes con uids distintos y `transactions`
    /// aceptaba las dos —su única restricción es la clave primaria sobre `uid`;
    /// no hay nada único sobre recurrente + mes—. La renta quedaba dos veces en
    /// los libros.
    ///
    /// Con el id derivado de `recurrenteId + mes`, el `upsert onConflict:
    /// "uid"` que ya usa todo el motor las reconoce como el mismo apunte.
    ///
    /// **Lo que el id derivado NO devuelve: el folio.** Cada aparato pide el
    /// suyo al generar, así que dos aparatos gastan dos números aunque la fila
    /// acabe siendo una. Los folios consumidos no se recuperan, y eso no tiene
    /// arreglo desde aquí: el folio se reserva antes de saber que la fila ya
    /// existía.
    func testDosAparatosGeneranElMismoMesConElMismoId() throws {
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

        let mes = try XCTUnwrap(a.meses.first)
        let fecha = try XCTUnwrap(MesesRecurrentes.fecha(en: mes, dia: 1))
        let m1 = MaterializadorRecurrentes.movimiento(de: enElIPhone, en: fecha, mes: mes)
        let m2 = MaterializadorRecurrentes.movimiento(de: enElIPad, en: fecha, mes: mes)

        print("QA-RECURRENTE: mes=\(mes) · id1=«\(m1.id)» id2=«\(m2.id)»")

        // Son el mismo apunte: misma definición, mismo mes, mismo importe.
        XCTAssertEqual(m1.recurrenteId, m2.recurrenteId)
        XCTAssertEqual(m1.monto, m2.monto)
        XCTAssertEqual(m1.fecha, m2.fecha)

        // Y ahora, el mismo id.
        XCTAssertFalse(m1.id.isEmpty, "el id volvió a nacer vacío: lo pondría un UUID")
        XCTAssertEqual(m1.id, m2.id, """
            Los dos aparatos generan ids distintos para la misma renta, así que \
            `transactions` va a quedarse con las dos filas.
            """)
    }

    /// El id dice de dónde salió la fila, que es medio arreglo por sí solo:
    /// quien mire la base ve que es de una serie y de qué mes.
    func testElIdDerivadoLlevaLaDefinicionYElMes() {
        let id = MaterializadorRecurrentes.idDelGenerado(recurrenteId: "r1", mes: "2026-09")
        XCTAssertEqual(id, "rec-r1-2026-09")
    }

    /// Meses distintos de la misma serie son apuntes distintos, y series
    /// distintas del mismo mes también. Sin esto, el arreglo del duplicado
    /// crearía uno peor: dos rentas machacándose entre sí.
    func testMesesYSeriesDistintasNoColisionan() {
        let sep = MaterializadorRecurrentes.idDelGenerado(recurrenteId: "r1", mes: "2026-09")
        let oct = MaterializadorRecurrentes.idDelGenerado(recurrenteId: "r1", mes: "2026-10")
        let otra = MaterializadorRecurrentes.idDelGenerado(recurrenteId: "r2", mes: "2026-09")
        XCTAssertNotEqual(sep, oct, "dos meses de la misma serie comparten id")
        XCTAssertNotEqual(sep, otra, "dos series del mismo mes comparten id")
        XCTAssertEqual(Set([sep, oct, otra]).count, 3)
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
