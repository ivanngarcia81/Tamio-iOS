import XCTest
import GRDB
@testable import Tamio

/// **Inicio es una consulta, y esto comprueba que consulta.** Era la última
/// pantalla de Tesorería que enseñaba cifras inventadas con la sesión de la
/// iglesia de verdad abierta; lo que se prueba aquí es que cada número de la
/// primera pantalla sale de los mismos movimientos que enseña Ingresos.
///
/// Corre contra la base del contenedor, sin sesión: nada sube.
@MainActor
final class InicioCalculadoTests: XCTestCase {

    private let movimientos = OfflineMovimientosRepository()
    private let repo = DashboardCalculado()

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertFalse(BaseLocal.compartida.enMemoria)
        try BaseLocal.compartida.limpiar()
    }

    // MARK: - Ayudas

    @discardableResult
    private func sembrar(id: String, tipo: TipoMovimiento = .ingreso,
                         monto: Centavos = 100_00, metodo: String = "Efectivo",
                         categoria: String = "Diezmo",
                         estado: EstadoRevision = .aprobado,
                         hace dias: Int = 0) async throws -> Movimiento {
        let fecha = Calendar.current.date(byAdding: .day, value: -dias, to: Date()) ?? Date()
        var m = Movimiento(id: id, tipo: tipo, categoria: categoria, persona: "María",
                           folio: "", metodo: metodo, monto: monto, hora: "11:20",
                           fecha: fecha, registradoPor: "Tesorero", miembro: "María",
                           categoriaCompleta: categoria, nota: "Sobre",
                           sinDepositar: true, comprobante: nil, auditoria: [])
        m.estadoRevision = estado
        try await movimientos.crear(m)
        return m
    }

    private func inicio() async throws -> DashboardData {
        try await repo.cargar(periodo: .mes)
    }

    // MARK: - Las cifras

    func testLosIngresosYGastosDelMesSalenDeLosMovimientos() async throws {
        try await sembrar(id: "i1", monto: 1_200_00)
        try await sembrar(id: "i2", monto: 800_00)
        try await sembrar(id: "g1", tipo: .gasto, monto: 500_00, categoria: "Servicios")

        let d = try await inicio()
        XCTAssertEqual(d.ingresos, 2_000_00)
        XCTAssertEqual(d.gastos, 500_00)
        XCTAssertEqual(d.balance, 1_500_00)
        XCTAssertEqual(d.registrosIngreso, 2)
        XCTAssertEqual(d.registrosGasto, 1)
        XCTAssertEqual(d.diezmos, 2)
    }

    func testLoQueEsperaVistoBuenoNoCuentaEnLasCifrasDelMes() async throws {
        try await sembrar(id: "i1", monto: 1_000_00)
        try await sembrar(id: "i2", monto: 9_999_00, estado: .pendiente)

        let d = try await inicio()
        XCTAssertEqual(d.ingresos, 1_000_00,
                       "un movimiento que espera visto bueno todavía no es un hecho contable")
        // Pero SÍ existe: el hub cuenta cuántos movimientos hay, no cuántos
        // cuentan en el mes.
        XCTAssertEqual(d.movimientosTotal, 2)
        // El KPI de Inicio, el badge del tab y la propia bandeja responden a
        // la misma pregunta, así que se comprueba contra ella y no contra un
        // número escrito aquí: la bandeja tiene más reglas que "espera visto
        // bueno" —sin comprobante, aportante sin vincular— y su cuenta es la
        // buena.
        let bandeja = await RevisarCalculado().asuntos().filter { !$0.archivado }.count
        XCTAssertEqual(d.pendientes, bandeja)
        XCTAssertGreaterThan(d.pendientes, 0, "algo que espera visto bueno tiene que reclamarse")
    }

    func testElSaldoEnCajaEsElEfectivoQueNingunCorteDepositadoReclama() async throws {
        try await sembrar(id: "i1", monto: 1_200_00, metodo: "Efectivo")
        try await sembrar(id: "i2", monto: 3_000_00, metodo: "Transferencia")
        try await sembrar(id: "g1", tipo: .gasto, monto: 500_00, metodo: "Efectivo")

        let d = try await inicio()
        XCTAssertEqual(d.saldoCaja, 1_200_00,
                       "solo el efectivo RECIBIDO y sin depositar; una transferencia nunca pasó por la caja")
        XCTAssertEqual(d.sinDepositarCount, 2, "los dos ingresos siguen sin depositar")
    }

    func testDepositarUnCorteSacaSuDineroDeLaCaja() async throws {
        try await sembrar(id: "i1", monto: 1_200_00)
        let depositos = OfflineDepositosRepository()
        try await BaseLocal.compartida.cola.write { db in
            var c = CorteFila(id: "corte-1")
            c.titulo = "Domingo"
            try c.insert(db)
        }
        try await depositos.agregarAlCorte(corteId: "corte-1", movimientoIds: ["i1"])
        let enCorte = try await inicio().saldoCaja
        XCTAssertEqual(enCorte, 1_200_00,
                       "meterlo en un corte NO lo saca de la caja: sigue sin ir al banco")

        try await depositos.registrarDeposito(
            corteId: "corte-1",
            DepositoBancario(id: "dep-1", fecha: "2026-09-07", periodo: "Septiembre 2026",
                             monto: 1_200_00, cuenta: "Principal"))
        let d = try await inicio()
        XCTAssertEqual(d.saldoCaja, 0, "en el banco ya no es efectivo en caja")
        XCTAssertEqual(d.sinDepositarCount, 0)
    }

    func testLaIglesiaEsLaDeAjustes() async throws {
        let cfg = ConfiguracionIglesiaViewModel.compartido
        cfg.config.nombre = "Iglesia de prueba"
        cfg.config.ciudad = "Saltillo"
        let d = try await inicio()
        XCTAssertEqual(d.church.nombre, "Iglesia de prueba",
                       "iba escrita a mano: decía Getsemaní con la cuenta de otra iglesia")
        XCTAssertEqual(d.church.ciudad, "Saltillo")
    }

    // MARK: - La gráfica y la lista

    func testLaGraficaEnseñaSeisMesesAunqueEstenVacios() async throws {
        try await sembrar(id: "i1", monto: 1_000_00)
        let tramos = try await inicio().tramos
        XCTAssertEqual(tramos.count, 6, "una iglesia que empieza tiene que ver la barra creciendo")
        XCTAssertEqual(tramos.last?.ingresos, 1_000_00, "el último tramo es el mes en curso")
        XCTAssertEqual(tramos.first?.ingresos, 0)
        XCTAssertEqual(Set(tramos.map(\.clave)).count, 6, "seis meses distintos, no seis veces el mismo")
    }

    func testLoRecienteSonLosCuatroUltimosDelMasNuevoAlMasViejo() async throws {
        for i in 0..<6 {
            try await sembrar(id: "i\(i)", monto: Centavos((i + 1) * 100_00), hace: i)
        }
        let recientes = try await inicio().recientes
        XCTAssertEqual(recientes.count, 4)
        XCTAssertEqual(recientes.map(\.id), ["i0", "i1", "i2", "i3"])
    }

    func testLoRecienteNoSeFiltraPorPeriodo() async throws {
        // Capturado hace 40 días: fuera del mes en curso. "Lo último que pasó"
        // no es un resumen del mes, y en día 1 estaría siempre vacío.
        try await sembrar(id: "viejo", monto: 700_00, hace: 40)
        let d = try await inicio()
        XCTAssertEqual(d.ingresos, 0, "no cuenta en el mes")
        XCTAssertEqual(d.recientes.map(\.id), ["viejo"], "pero sí es lo último que pasó")
    }

    func testSinMovimientosNoInventaNada() async throws {
        let d = try await inicio()
        XCTAssertEqual(d.ingresos, 0)
        XCTAssertEqual(d.gastos, 0)
        XCTAssertEqual(d.saldoCaja, 0)
        XCTAssertEqual(d.movimientosTotal, 0)
        XCTAssertNil(d.deltaIngresos, "sin mes anterior no hay variación, no es un +100%")
        XCTAssertTrue(d.ingresosPorCategoria.isEmpty)
        XCTAssertTrue(d.recientes.isEmpty)
    }
}

/// **El selector de aportante lee el padrón del teléfono, no la red.** Iba
/// contra Supabase cada vez que se abría la hoja de captura, así que sin señal
/// el menú salía vacío y el diezmo se quedaba sin persona — en una app que
/// existe para capturar el sobre en el templo, con señal o sin ella.
@MainActor
final class CatalogoAportantesTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        try BaseLocal.compartida.limpiar()
    }

    func testElSelectorOfreceElPadronYDejaFueraLasBajas() async throws {
        let repo = OfflineMembresiaRepository()
        try await repo.guardar(Miembro(id: "m1", nombre: "María Hernández"))
        try await repo.guardar(Miembro(id: "m2", nombre: "Ana Torres"))
        var baja = Miembro(id: "m3", nombre: "Pedro Salas")
        baja.estado = .baja("2026-09-01", "traslado")
        try await repo.guardar(baja)

        let catalogo = try await OfflineAportantesCatalogo().activos()
        XCTAssertEqual(catalogo.map(\.nombre), ["Ana Torres", "María Hernández"],
                       "en orden alfabético y sin la baja")
        XCTAssertEqual(catalogo.first?.id, "m2", "el id es el del padrón: es lo que vincula el aporte")
    }
}
