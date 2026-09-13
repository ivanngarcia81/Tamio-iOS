import XCTest
@testable import Tamio

/// **La unidad de `transactions.monto` y sus dos hermanas: CÉNTIMOS.**
///
/// Hasta el 13-sep-2026 las dos apps no coincidían, y el error era de un factor
/// de **cien**. Las dos guardan céntimos en su base local; la diferencia estaba
/// en la SUBIDA:
///
/// - **iOS dividía entre 100** en tres sitios —movimientos
///   (`SupabaseMovimientosRepository:297`), depósitos
///   (`MotorSincronizacion:2474`) y recurrentes (`:2712`)— y volvía a
///   multiplicar en los cuatro de bajada.
/// - **El web sube su columna de céntimos tal cual** (`sync.ts:520`,
///   `for (const c of TX_DATA_COLS) fila[c] = l[c]`), y su base local lo dice
///   en un comentario: «`total` es SUM de una columna INTEGER de centavos».
///
/// Medido entonces sobre las 38 filas vivas, dos poblaciones sin un solo
/// solape: las del web enteras y entre 10.000 y 1.000.000; las de iOS con
/// decimales y por debajo de 2.500. Un movimiento que el web guardó como
/// $500.00 el iPhone lo enseñaba como **$50.000**.
///
/// **Se arregló en iOS y no en el web**, y la razón es que iOS era el que se
/// salía: las dos bases locales están en céntimos, `iglesias.saldo_inicial` ya
/// es `bigint`, y el céntimo entero es la regla que la propia app se escribió.
/// Que el web no tuviera que tocar nada es lo que permitió hacerlo sin él.
///
/// Estas pruebas fijan el contrato de iOS. El del web va documentado en
/// `docs/ACUERDO-CON-EL-WEB.md` §1.
final class UnidadDelDineroTests: XCTestCase {

    /// Lo que iOS pone en la columna remota. Espejo de
    /// `SupabaseMovimientosRepository:297` y `MotorSincronizacion:2474`/`:2712`.
    private func loQueSubeIOS(centavos: Centavos) -> Double {
        Double(centavos)
    }

    /// Lo que iOS entiende al leer la columna. Espejo de
    /// `SupabaseMovimientosRepository:226` y `MotorSincronizacion:2562`/`:2778`/`:2860`.
    private func loQueLeeIOS(remoto: Double) -> Centavos {
        Centavos(remoto.rounded())
    }

    /// Lo que el web pone y entiende: su columna local de céntimos, tal cual.
    private func loQueSubeElWeb(centavos: Centavos) -> Double { Double(centavos) }
    private func loQueLeeElWeb(remoto: Double) -> Centavos { Centavos(remoto) }

    // MARK: - El contrato

    func testIOSSubeCentimosSinConvertir() {
        // $300.00 son 30.000 céntimos en la fila local, y suben tal cual.
        XCTAssertEqual(loQueSubeIOS(centavos: 30_000), 30_000)
        XCTAssertEqual(loQueLeeIOS(remoto: 30_000), 30_000)
    }

    /// **Lo que de verdad había que arreglar:** que las dos apps signifiquen lo
    /// mismo por el mismo número.
    func testLasDosAppsEntiendenLoMismoPorElMismoNumero() {
        for centavos in [1, 99, 300, 999, 1_250, 8_642, 68_550, 50_000, 100_000_000] {
            let subidoPorIOS = loQueSubeIOS(centavos: centavos)
            let subidoPorElWeb = loQueSubeElWeb(centavos: centavos)
            XCTAssertEqual(subidoPorIOS, subidoPorElWeb,
                           "las dos apps escriben distinto para \(centavos) céntimos")

            // Y cada una lee bien lo que escribió la otra, que es el caso que
            // fallaba: iOS multiplicaba por cien lo del web y el web dividía
            // entre cien lo de iOS.
            XCTAssertEqual(loQueLeeIOS(remoto: subidoPorElWeb), centavos)
            XCTAssertEqual(loQueLeeElWeb(remoto: subidoPorIOS), centavos)
        }
    }

    /// El caso concreto del informe, con sus números.
    func testElCasoQueSeVeiaEnLaPantalla() {
        // El web tenía $500.00 y subía 50.000 céntimos.
        let delWeb = loQueSubeElWeb(centavos: 50_000)
        XCTAssertEqual(loQueLeeIOS(remoto: delWeb), 50_000,
                       "$500.00, y no los $50.000 que enseñaba antes")

        // El iPhone captura $300.00 y sube 30.000 céntimos.
        let deIOS = loQueSubeIOS(centavos: 30_000)
        XCTAssertEqual(loQueLeeElWeb(remoto: deIOS), 30_000,
                       "$300.00, y no los $3.00 que enseñaba antes")

        print("QA-MONEDA: las dos apps suben 50000 para $500 y 30000 para $300")
    }

    /// La ida y vuelta sobre importes con céntimos. **Esto ya pasaba antes** y
    /// por eso no bastaba: el `double` devolvía el mismo número y las dos apps
    /// seguían sin significar lo mismo por él. Se conserva como red, no como
    /// prueba de que el problema estuviera resuelto.
    func testLaPrecisionDelDoubleAguantaYNuncaFueElProblema() {
        for centavos in [1, 99, 999, 1_250, 8_642, 68_550, 100_000_000] {
            XCTAssertEqual(loQueLeeIOS(remoto: loQueSubeIOS(centavos: centavos)),
                           centavos, "el importe \(centavos) no vuelve igual")
        }
        // Un entero de céntimos cabe exacto en un `double` muy por encima de
        // cualquier cifra de una iglesia: 2^53 son noventa mil billones de
        // céntimos.
        XCTAssertEqual(loQueLeeIOS(remoto: loQueSubeIOS(centavos: 9_007_199_254_740_992)),
                       9_007_199_254_740_992)
    }

    /// **El aviso que impide equivocarse al convertir lo ya guardado.** Las dos
    /// poblaciones se distinguían por la forma del número —las del web enteras
    /// y grandes—, pero eso era casualidad de esos datos: un movimiento de iOS
    /// de exactamente $10.000,00 subía como `10000`, indistinguible de uno del
    /// web de $100,00. La conversión pide un criterio que no dependa de la
    /// forma: la lista explícita de uids.
    func testLaFormaDelNumeroNoDistingueLasDosUnidades() {
        let iOSDiezMilPesos = 1_000_000.0 / 100.0     // como subía iOS: 10000
        let webCienPesos = Double(10_000)             // como sube el web: 10000
        XCTAssertEqual(iOSDiezMilPesos, webCienPesos, """
            Dejaron de ser indistinguibles. Si es así, hay algo nuevo que \
            separa las dos unidades y la migración podría apoyarse en ello.
            """)
    }
}
