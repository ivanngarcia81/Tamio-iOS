import XCTest
@testable import Tamio

/// **El año de un aporte, que decide lo que dice una constancia firmada.**
///
/// La fecha llega como texto ("2026-01-01") y se parsea a medianoche UTC. Leída
/// con el calendario del aparato, en cualquier zona al oeste de Greenwich cae
/// en el año anterior — y su importe con ella.
final class AnioDeUnAporteTests: XCTestCase {

    /// **Al oeste de Greenwich, que es donde está la iglesia.** El fallo solo
    /// se ve con desfase negativo: en UTC o al este, medianoche UTC sigue
    /// cayendo en el mismo día y la prueba pasaría sin probar nada. Se salta
    /// en vez de fallar, como `IPadMembresiaTests` con el idioma.
    override func setUpWithError() throws {
        try super.setUpWithError()
        let desfase = TimeZone.current.secondsFromGMT()
        try XCTSkipUnless(desfase < 0,
                          "zona \(TimeZone.current.identifier): al este de Greenwich esto no prueba nada")
    }

    private func aportante(_ fechas: [String]) -> Aportante {
        Aportante(id: "a1", nombre: "María", estado: .activo, rol: "diezmo",
                  miembroDesde: "2018", telefono: "", correo: "", nacimiento: "",
                  direccion: "", estadoCivil: "", idFiscal: "", congregaDesde: "2016",
                  frecuencia: .mensual,
                  aportes: fechas.enumerated().map { i, f in
                      Aporte(id: "ap\(i)", concepto: "Diezmo",
                             fecha: Fechas.desdeTexto(f) ?? Date(), monto: 100_00)
                  },
                  familia: [])
    }

    func testElAporteDelPrimeroDeEneroCuentaEnSuAnio() {
        let a = aportante(["2026-01-01"])
        XCTAssertEqual(a.aportes(anio: 2026).count, 1,
                       "el 1 de enero se iba al año anterior, y su importe con él")
        XCTAssertEqual(a.total(anio: 2026), 100_00)
        XCTAssertEqual(a.total(anio: 2025), 0)
    }

    func testElAporteDelUltimoDeDiciembreNoSeAdelanta() {
        let a = aportante(["2025-12-31"])
        XCTAssertEqual(a.total(anio: 2025), 100_00)
        XCTAssertEqual(a.total(anio: 2026), 0)
    }

    func testLosAniosOfrecidosSonLosDeVerdad() {
        let a = aportante(["2026-01-01", "2025-12-31"])
        XCTAssertEqual(a.aniosConAportes.prefix(2).sorted(by: >), [2026, 2025],
                       "un año que no existe en la lista es una constancia en blanco")
    }

    func testUnAporteConHoraSeLeeIgual() {
        // Los que bajan de Supabase traen hora: "2026-01-01T00:00:00Z".
        let a = aportante(["2026-01-01T00:00:00Z"])
        XCTAssertEqual(a.total(anio: 2026), 100_00)
    }

    func testElAnioDelPdfEmpiezaElUnoDeEneroEnUTC() {
        let rango = PeriodoReporte.anio.intervalo(desde: Date(), hasta: Date())
        let primeroDeEnero = Fechas.desdeTexto("\(Fechas.anio(de: Date()))-01-01")!
        XCTAssertTrue(rango.contains(primeroDeEnero),
                      "el periodo Año dejaba fuera el aporte del día 1")
    }
}
