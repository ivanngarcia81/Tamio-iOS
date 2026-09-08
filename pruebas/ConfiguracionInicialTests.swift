import XCTest
@testable import Tamio

/// **Cuándo se pide la configuración inicial de la iglesia.**
///
/// La condición peligrosa no es la del nombre: es la de la sincronización. Sin
/// ella, el primer arranque de un aparato ve la base local en blanco y le pide
/// al segundo miembro de una iglesia con tres años de datos que la configure
/// otra vez — pisándole el nombre al guardar.
final class ConfiguracionInicialTests: XCTestCase {

    private let yaBajo = Date()

    func testIglesiaReciennCreadaYaBajada() {
        XCTAssertTrue(ConfiguracionInicialView.haceFalta(nombre: "", ultimaSincronizacion: yaBajo))
    }

    func testIglesiaConNombreNoSePregunta() {
        XCTAssertFalse(ConfiguracionInicialView.haceFalta(nombre: "Iglesia Nueva Vida",
                                                          ultimaSincronizacion: yaBajo))
    }

    /// El caso que este repo ya se comió una vez con Inicio en ceros: la
    /// pantalla dibujada antes de que termine la bajada.
    func testSinHaberBajadoNuncaNoSePregunta() {
        XCTAssertFalse(ConfiguracionInicialView.haceFalta(nombre: "", ultimaSincronizacion: nil),
                       "### le pediría configurar la iglesia a alguien que aún no ha bajado nada")
    }

    /// Y tampoco se pregunta si el servidor sí trajo el nombre pero la bajada
    /// no ha terminado: las dos condiciones, no una.
    func testNiConNombreNiBajada() {
        XCTAssertFalse(ConfiguracionInicialView.haceFalta(nombre: "Iglesia Nueva Vida",
                                                          ultimaSincronizacion: nil))
    }

    /// Un nombre de espacios en blanco es un nombre vacío. Pasó con los cargos:
    /// lo que parece puesto y no lo está es lo que se cuela.
    func testUnNombreDeEspaciosEsVacio() {
        XCTAssertTrue(ConfiguracionInicialView.haceFalta(nombre: "   \n ", ultimaSincronizacion: yaBajo))
    }
}
