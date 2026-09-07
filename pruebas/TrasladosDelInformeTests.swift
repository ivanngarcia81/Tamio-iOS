import XCTest
@testable import Tamio

/// **El folio y la iglesia de un traslado, en el informe de membresía.**
///
/// Los dos estaban en el aparato y la tabla los pintaba en blanco: el folio y
/// el destino viven en `trasladoSalida` —que el repositorio descartaba en
/// cuanto el expediente se cerraba— y la iglesia de origen, en el
/// `iglesiaAnterior` del propio miembro. Es un informe que se comparte con la
/// junta con una columna vacía de 110 puntos.
@MainActor
final class TrasladosDelInformeTests: XCTestCase {

    /// Un padrón de dos: una salida cerrada con su expediente y una entrada.
    private struct RepoFalso: MembresiaRepository {
        let miembros: [Miembro]
        func lista() async throws -> [Miembro] { miembros }
        // El informe de traslados no los usa; se contestan en cero.
        func resumen() async -> MembresiaResumen {
            MembresiaResumen(activos: 0, inactivos: 0, bajas: 0, nuevos: 0,
                             recibidos: 0, trasladados: 0, ausencias: 0, incompletos: 0)
        }
        func asistenciaResumen() async -> AsistenciaResumen {
            AsistenciaResumen(promedioPct: 0, serviciosPeriodo: 0, presentesPromedio: 0,
                              mejorServicio: "", meses: [], porTipo: [])
        }
        func guardar(_ m: Miembro) async throws {}
        func agregarPariente(miembroId: String, _ p: Pariente) async throws {}
        func quitarPariente(id: String) async throws {}
    }

    private func informe(_ miembros: [Miembro], anio: Int = 2026) async -> InformeResumen {
        let vm = InformesMembresiaViewModel(padronRepo: RepoFalso(miembros: miembros))
        await vm.cargarPadron()
        vm.añoSeleccionado = anio
        return vm.resumen
    }

    func testLaSalidaLlevaSuFolioYSuDestino() async {
        var m = Miembro(id: "1", nombre: "Rosa Elena Vega")
        m.estado = .baja("2026-03-14", "traslado")
        m.trasladoSalida = TrasladoDeSalida(folio: "TS-2026-011",
                                            iglesiaDestino: "Iglesia Getsemaní, Reynosa",
                                            estado: "completado")
        let t = await informe([m]).traslados
        XCTAssertEqual(t.count, 1)
        XCTAssertEqual(t.first?.folio, "TS-2026-011", "### el folio seguía saliendo en blanco")
        XCTAssertEqual(t.first?.iglesia, "Iglesia Getsemaní, Reynosa")
        XCTAssertEqual(t.first?.sentido, .salida)
    }

    func testLaEntradaLlevaLaIglesiaDeOrigen() async {
        var m = Miembro(id: "2", nombre: "Daniel Salas")
        m.fechaIngreso = "2026-02-01"
        m.iglesiaAnterior = "Iglesia Bautista Getsemaní, Saltillo"
        let t = await informe([m]).traslados
        XCTAssertEqual(t.first?.iglesia, "Iglesia Bautista Getsemaní, Saltillo")
        XCTAssertEqual(t.first?.sentido, .entrada)
        // Una entrada no tiene folio y no es un olvido: lo numera quien envía.
        XCTAssertEqual(t.first?.folio, "")
        XCTAssertEqual(t.first?.folioLegible, "—")
    }

    /// El expediente cerrado ya no pone a nadie "en curso", pero sus datos
    /// siguen ahí. Era el filtro que hacía el repositorio y por el que el
    /// informe se quedaba sin nada que citar.
    func testUnTrasladoCerradoNoEstaEnCursoPeroConservaSusDatos() {
        let cerrado = TrasladoDeSalida(folio: "TS-1", iglesiaDestino: "Betel", estado: "completado")
        let abierto = TrasladoDeSalida(folio: "TS-2", iglesiaDestino: "Betel", estado: "enviado")
        XCTAssertFalse(cerrado.enCurso)
        XCTAssertTrue(abierto.enCurso)

        var m = Miembro(id: "3", nombre: "Javier")
        m.trasladoSalida = cerrado
        XCTAssertNil(m.trasladoEnCurso, "### un traslado completado no puede seguir 'en curso'")
        m.trasladoSalida = abierto
        XCTAssertEqual(m.trasladoEnCurso?.folio, "TS-2")
    }
}
