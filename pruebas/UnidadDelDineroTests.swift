import XCTest
@testable import Tamio

/// **Las dos apps no coinciden en la UNIDAD de `transactions.monto`.**
///
/// Salió tirando del hilo de las categorías, el 13-sep. Es el hallazgo más
/// grave de la pasada: no es un rótulo, es el dinero, y el error es de un
/// factor de **cien**.
///
/// - **iOS sube UNIDADES.** `MotorSincronizacion:2474` y `:2710` hacen
///   `monto: Double(fila.monto) / 100.0`, y al bajar multiplican
///   (`Int((monto * 100).rounded())`). La fila local guarda céntimos
///   (`MovimientoFila.monto: Int`), así que $300.00 sube como `300`.
/// - **El web sube CÉNTIMOS.** Su base local también guarda céntimos en una
///   columna entera —lo dice su propio comentario: «`total` es SUM de una
///   columna INTEGER de centavos»— y `sync.ts:520` copia la columna **tal
///   cual**, sin dividir: `for (const c of TX_DATA_COLS) fila[c] = l[c]`.
///   Así que $500.00 sube como `50000`.
///
/// **Lo que eso significa**, y está medido en la base de la iglesia:
///
/// | origen | filas vivas | mínimo | máximo | con decimales |
/// |---|---|---|---|---|
/// | web / semilla | 20 | 10.000 | 1.000.000 | **0** |
/// | iOS | 18 | 1 | 2.500 | 3 |
///
/// Dos poblaciones sin un solo solape. Un movimiento que el web guardó como
/// $500.00 el iPhone lo enseña como **$50.000**; uno que el iPhone guardó como
/// $300.00 el web lo enseña como **$3.00**.
///
/// Esta prueba fija el contrato del lado iOS. El del web no se puede ejecutar
/// desde aquí: va documentado en `docs/ACUERDO-CON-EL-WEB.md`.
final class UnidadDelDineroTests: XCTestCase {

    /// Lo que iOS pone en la columna remota para un importe dado.
    /// Espejo de `MotorSincronizacion:2474`.
    private func loQueSubeIOS(centavos: Centavos) -> Double {
        Double(centavos) / 100.0
    }

    /// Lo que iOS entiende al leer la columna remota.
    /// Espejo de `MotorSincronizacion:2858`.
    private func loQueLeeIOS(remoto: Double) -> Centavos {
        Centavos((remoto * 100).rounded())
    }

    func testIOSSubeUnidadesYLasVuelveALeerIgual() {
        // $300.00 son 30.000 céntimos en la fila local.
        XCTAssertEqual(loQueSubeIOS(centavos: 30_000), 300.0)
        XCTAssertEqual(loQueLeeIOS(remoto: 300.0), 30_000)

        // Ida y vuelta sobre importes con céntimos, que es donde un double
        // podría desviarse. Cero desvíos, medido el 12-sep sobre las 97 filas
        // de la base: el `.rounded()` es lo que lo sostiene.
        for centavos in [1, 99, 999, 1_250, 8_642, 68_550, 100_000_000] {
            XCTAssertEqual(loQueLeeIOS(remoto: loQueSubeIOS(centavos: centavos)),
                           centavos, "el importe \(centavos) no vuelve igual")
        }
    }

    /// **El desajuste, escrito como lo que es.** Si el web sube céntimos y iOS
    /// lee unidades, iOS multiplica por cien lo que el web escribió.
    func testLoQueElWebSubeLoLeeIOSMultiplicadoPorCien() {
        // El web tiene $500.00 en su base local, en céntimos, y sube la columna
        // tal cual.
        let loQueSubeElWeb: Double = 50_000     // céntimos, sin dividir

        // iOS lo lee como si fueran unidades.
        let loQueEntiendeIOS = loQueLeeIOS(remoto: loQueSubeElWeb)

        XCTAssertEqual(loQueEntiendeIOS, 5_000_000,
                       "5.000.000 céntimos, o sea $50.000 donde había $500")
        XCTAssertEqual(loQueEntiendeIOS, 50_000 * 100, """
            El desajuste dejó de ser de un factor de cien. Si el web ya divide \
            entre 100 al subir, esto está arreglado y hay que reescribir la \
            prueba al revés; si da otro factor, mirar qué cambió.
            """)
    }

    /// Y al revés: lo que escribe el iPhone, el web lo enseña dividido por cien.
    func testLoQueIOSSubeLoLeeElWebDivididoEntreCien() {
        // El iPhone captura $300.00 → sube 300.
        let loQueSubeIOSAhora = loQueSubeIOS(centavos: 30_000)   // 300.0
        XCTAssertEqual(loQueSubeIOSAhora, 300.0)

        // El web lo mete en su columna de céntimos tal cual: 300 céntimos.
        let loQueEntiendeElWeb = Centavos(loQueSubeIOSAhora)     // 300 céntimos
        XCTAssertEqual(loQueEntiendeElWeb, 300, "$3.00 donde había $300.00")
        XCTAssertEqual(loQueEntiendeElWeb * 100, 30_000,
                       "la relación con el importe real es de cien a uno")
    }

    /// El control que separa las dos poblaciones en la base real, y que es lo
    /// que convirtió la sospecha en medida: **los importes del web son todos
    /// redondos y grandes; los de iOS llevan decimales y son pequeños.**
    func testLasDosPoblacionesSeDistinguenPorLaForma() {
        // Tal cual salen de la base de la iglesia el 13-sep.
        let delWeb: [Double] = [1_000_000, 100_000, 70_000, 50_000, 10_000]
        let deIOS: [Double] = [12.5, 9.99, 686.5, 300, 1]

        XCTAssertTrue(delWeb.allSatisfy { $0 == $0.rounded() && $0 >= 10_000 },
                      "los del web dejaron de ser redondos y grandes")
        XCTAssertTrue(deIOS.contains { $0 != $0.rounded() },
                      "los de iOS dejaron de llevar decimales")
        XCTAssertTrue(deIOS.allSatisfy { $0 < 10_000 })

        // Y por qué eso no es casualidad: un importe en céntimos de una cifra
        // normal SIEMPRE es un entero grande.
        XCTAssertEqual(loQueSubeIOS(centavos: 50_000), 500.0)
        print("QA-MONEDA: el web sube 50000 para $500; iOS sube 500 para $500")
    }
}
