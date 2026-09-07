import XCTest
import GRDB
@testable import Tamio

/// **Los cinco sucesos de Tesorería.** Cada uno se prueba dos veces: que anota
/// al hacer la cosa, y que NO vuelve a anotar si la cosa se repite. Ese segundo
/// caso es el que importa: un registro que anota de más deja de servir para
/// mirar qué pasó, igual que uno que no anota.
///
/// Corre contra la base de verdad del contenedor —no una en memoria—, así que
/// lo que se prueba es el mismo código que usa la app. Sin sesión no sube nada:
/// las operaciones quedan en la cola de salida y el motor no se llama aquí.
@MainActor
final class SucesosTesoreriaTests: XCTestCase {

    private let movimientos = OfflineMovimientosRepository()
    private let depositos = OfflineDepositosRepository()

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertFalse(BaseLocal.compartida.enMemoria,
                       "La base tenía que abrir EN DISCO: en memoria no se prueba la migración")
        try BaseLocal.compartida.limpiar()
    }

    // MARK: - Ayudas

    private func apuntes() async -> [Apunte] {
        await OfflineRegistroRepository().apuntes()
    }

    private func unico(_ tipo: TipoSuceso) async throws -> Apunte {
        let hallados = await apuntes().filter { $0.tipo == tipo }
        XCTAssertEqual(hallados.count, 1, "se esperaba UN apunte de \(tipo.rawValue)")
        return try XCTUnwrap(hallados.first)
    }

    private func cuantos(_ tipo: TipoSuceso) async -> Int {
        await apuntes().filter { $0.tipo == tipo }.count
    }

    @discardableResult
    private func sembrarMovimiento(id: String = "mov-1", monto: Centavos = 125_000,
                                   folio: String = "1042",
                                   nota: String? = "Ofrenda del domingo") async throws -> Movimiento {
        let m = Movimiento(id: id, tipo: .ingreso, categoria: "Diezmo", persona: "María",
                           folio: folio, metodo: "Efectivo", monto: monto, hora: "11:20",
                           fecha: Date(), registradoPor: "Tesorero", miembro: "María",
                           categoriaCompleta: "Diezmo · Sobre", nota: nota,
                           sinDepositar: true, comprobante: nil, auditoria: [])
        try await movimientos.crear(m)
        return m
    }

    private func sembrarCorte(id: String = "corte-1",
                              titulo: String = "Domingo 6") async throws {
        try await BaseLocal.compartida.cola.write { db in
            var fila = CorteFila(id: id)
            fila.titulo = titulo
            fila.cuenta = "Principal"
            fila.fecha = "2026-09-06"
            try fila.insert(db)
        }
    }

    // MARK: - 1. movEliminado

    func testDarDeBajaUnMovimientoLoAnotaConSuConceptoImporteYFolio() async throws {
        try await sembrarMovimiento()
        try await movimientos.eliminar(id: "mov-1")

        let a = try await unico(.movEliminado)
        XCTAssertEqual(a.datos["concepto"], "Ofrenda del domingo")
        // Capturado en el teléfono y sin subir: su folio es el provisional que
        // enseña la app, no el que traiga el objeto ni el del servidor.
        XCTAssertEqual(a.datos["folio"], "P-1")
        XCTAssertEqual(a.datos["monto"], "\(Money.fmt(125_000)) \(Money.codigo)")
        XCTAssertEqual(a.area, .tesoreria)
        XCTAssertTrue(a.esAlerta, "hacer desaparecer dinero tiene que pedir que alguien mire")
        XCTAssertTrue(a.texto.contains("Ofrenda del domingo"), a.texto)
    }

    func testDarDeBajaDosVecesElMismoMovimientoAnotaUnaSola() async throws {
        try await sembrarMovimiento()
        try await movimientos.eliminar(id: "mov-1")
        try await movimientos.eliminar(id: "mov-1")
        let cuantos = await cuantos(.movEliminado)
        XCTAssertEqual(cuantos, 1, "borrar lo ya borrado no hace desaparecer el dinero dos veces")
    }

    func testDarDeBajaAlgoQueNoExisteNoAnotaNada() async throws {
        try await movimientos.eliminar(id: "no-existe")
        let cuantos = await cuantos(.movEliminado)
        XCTAssertEqual(cuantos, 0)
    }

    // MARK: - 2. corteEntregado

    func testElCorteSaleDeLaCajaLaPrimeraVezQueSeLeEchaDinero() async throws {
        try await sembrarCorte()
        try await sembrarMovimiento(id: "mov-1")
        try await sembrarMovimiento(id: "mov-2", folio: "1043")
        try await depositos.agregarAlCorte(corteId: "corte-1", movimientoIds: ["mov-1", "mov-2"])

        let a = try await unico(.corteEntregado)
        XCTAssertEqual(a.datos["corte"], "Domingo 6")
        XCTAssertEqual(a.datos["movimientos"], "2")
        XCTAssertEqual(a.area, .tesoreria)
    }

    func testEcharMasDineroAUnCorteQueYaSalioNoLoAnotaOtraVez() async throws {
        try await sembrarCorte()
        try await sembrarMovimiento(id: "mov-1")
        try await sembrarMovimiento(id: "mov-2", folio: "1043")
        try await depositos.agregarAlCorte(corteId: "corte-1", movimientoIds: ["mov-1"])
        try await depositos.agregarAlCorte(corteId: "corte-1", movimientoIds: ["mov-2"])

        let cuantos = await cuantos(.corteEntregado)
        XCTAssertEqual(cuantos, 1, "el dinero sale de la caja una vez, no una por sobre")
    }

    func testUnCorteQueSigueVacioNoAnotaNada() async throws {
        try await sembrarCorte()
        try await depositos.agregarAlCorte(corteId: "corte-1", movimientoIds: [])
        let cuantos = await cuantos(.corteEntregado)
        XCTAssertEqual(cuantos, 0)
    }

    // MARK: - 3. corteDepositado

    func testRegistrarElDepositoAnotaQueElCorteLlegoAlBanco() async throws {
        try await sembrarCorte()
        try await depositos.registrarDeposito(corteId: "corte-1", deposito())

        let a = try await unico(.corteDepositado)
        XCTAssertEqual(a.datos["corte"], "Domingo 6")
        XCTAssertEqual(a.area, .tesoreria)
    }

    func testRegistrarDosVecesElDepositoDelMismoCorteAnotaUnaSola() async throws {
        try await sembrarCorte()
        try await depositos.registrarDeposito(corteId: "corte-1", deposito(id: "dep-1"))
        try await depositos.registrarDeposito(corteId: "corte-1", deposito(id: "dep-2"))

        let cuantos = await cuantos(.corteDepositado)
        XCTAssertEqual(cuantos, 1)
    }

    private func deposito(id: String = "dep-1") -> DepositoBancario {
        DepositoBancario(id: id, fecha: "2026-09-07", periodo: "Septiembre 2026",
                         monto: 125_000, cuenta: "Principal", referencia: "REF-1")
    }

    // MARK: - 4. segundaFirma

    func testLaSegundaFirmaSeAnotaConQuienFirmoYComoLoHizo() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: "Rocío Ibarra",
                                   rol: "Asistente", modo: .conteo, conteo: 125_000)

        let a = try await unico(.segundaFirma)
        XCTAssertEqual(a.datos["corte"], "Domingo 6")
        XCTAssertEqual(a.datos["firmante"], "Rocío Ibarra")
        XCTAssertEqual(a.datos["modo"], "conteo")
        XCTAssertTrue(a.texto.contains("Rocío Ibarra"), a.texto)
        XCTAssertFalse(a.esAlerta, "una firma dada no es un problema que mirar")
    }

    func testGuardarLaMismaFirmaOtraVezNoLaAnotaDosVeces() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: "Rocío Ibarra",
                                   rol: "Asistente", modo: .conteo, conteo: 125_000)
        try await depositos.firmar(corteId: "corte-1", nombre: "Rocío Ibarra",
                                   rol: "Asistente", modo: .revision, conteo: 125_000)

        let cuantos = await cuantos(.segundaFirma)
        XCTAssertEqual(cuantos, 1)
    }

    func testFirmarDespuesDeQuitarLaFirmaVuelveAAnotar() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: "Rocío Ibarra",
                                   rol: "Asistente", modo: .conteo, conteo: 125_000)
        try await depositos.quitarFirma(corteId: "corte-1")
        try await depositos.firmar(corteId: "corte-1", nombre: "Rocío Ibarra",
                                   rol: "Asistente", modo: .conteo, conteo: 125_000)

        let cuantos = await cuantos(.segundaFirma)
        XCTAssertEqual(cuantos, 2, "firmar de nuevo tras deshacerlo es firmar otra vez")
    }

    // MARK: - 5. descuadre

    func testContarSinFirmarEsUnDescuadreYQuedaComoAlerta() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: nil, rol: nil,
                                   modo: .conteo, conteo: 118_000)

        let a = try await unico(.descuadre)
        XCTAssertEqual(a.datos["corte"], "Domingo 6")
        XCTAssertEqual(a.datos["contado"], Money.fmt(118_000))
        XCTAssertTrue(a.esAlerta, "un descuadre tiene que pedir que alguien mire")
        let firmas = await cuantos(.segundaFirma)
        XCTAssertEqual(firmas, 0, "sin nombre no hay nada firmado")
    }

    func testGuardarElMismoConteoOtraVezNoAnotaOtroDescuadre() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: nil, rol: nil,
                                   modo: .conteo, conteo: 118_000)
        try await depositos.firmar(corteId: "corte-1", nombre: nil, rol: nil,
                                   modo: .conteo, conteo: 118_000)
        let cuantos = await cuantos(.descuadre)
        XCTAssertEqual(cuantos, 1)
    }

    func testContarOtraCifraDistintaSiEsOtroDescuadre() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: nil, rol: nil,
                                   modo: .conteo, conteo: 118_000)
        try await depositos.firmar(corteId: "corte-1", nombre: nil, rol: nil,
                                   modo: .conteo, conteo: 117_500)
        let cuantos = await cuantos(.descuadre)
        XCTAssertEqual(cuantos, 2, "contó otra vez y volvió a no cuadrar: son dos hechos")
    }

    func testSinNombreYSinConteoNoAnotaNada() async throws {
        try await sembrarCorte()
        try await depositos.firmar(corteId: "corte-1", nombre: "   ", rol: nil,
                                   modo: .revision, conteo: nil)
        let apuntes = await apuntes()
        XCTAssertTrue(apuntes.isEmpty, "no pasó nada que anotar")
    }
}

/// **Las claves de `datos` son las del web.** Un apunte escrito en el teléfono
/// lo lee la app web y al revés: si las claves no coinciden, la frase sale con
/// guiones donde iban el nombre o el importe. Esto se rompió de verdad —iOS
/// escribía `nombre` donde el web lee `destinatario`— y por eso se prueba.
final class ClavesDelRegistroTests: XCTestCase {

    func testUnApunteDelWebSeLeeEnteroAunqueTraigaNumeros() {
        // Tal cual lo escribe `registrar()` en `src/db.ts`: `movimientos` es un
        // número, no una cadena.
        let json = #"{"corte":"Domingo 6","movimientos":3}"#
        let datos = OfflineRegistroRepository.datos(json)
        XCTAssertEqual(datos["corte"], "Domingo 6")
        XCTAssertEqual(datos["movimientos"], "3",
                       "un solo valor numérico dejaba TODO el apunte en blanco")
    }

    func testLasFrasesDelWebSeLeenConSusClaves() {
        func texto(_ tipo: TipoSuceso, _ datos: [String: String]) -> String {
            Apunte(id: "a", tipo: tipo, datos: datos, autor: "Tamio", creadoEn: Date()).texto
        }
        XCTAssertTrue(texto(.segundaFirma,
                            ["corte": "Domingo 6", "firmante": "Rocío", "modo": "conteo"])
            .contains("Rocío"))
        XCTAssertTrue(texto(.cartaEmitida,
                            ["folio": "C-1", "destinatario": "María"]).contains("María"))
        XCTAssertTrue(texto(.movEliminado,
                            ["concepto": "Ofrenda", "monto": "$100.00", "folio": "1042"])
            .contains("Ofrenda"))
    }

    func testLosApuntesViejosDeIOSSiguenLegibles() {
        // Los que ya están en la base de la iglesia, escritos con las claves de
        // antes. Si dejaran de leerse, el registro perdería su historia.
        func texto(_ tipo: TipoSuceso, _ datos: [String: String]) -> String {
            Apunte(id: "a", tipo: tipo, datos: datos, autor: "Tamio", creadoEn: Date()).texto
        }
        XCTAssertTrue(texto(.cartaEmitida, ["folio": "C-1", "nombre": "María"])
            .contains("María"))
        XCTAssertTrue(texto(.segundaFirma, ["corte": "Domingo 6", "quien": "Rocío"])
            .contains("Rocío"))
        XCTAssertFalse(texto(.actaCerrada, ["folio": "A-3"]).contains("—"),
                       "un acta sin título no puede leerse «Se cerró el acta «—»»")
    }
}
