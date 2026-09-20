import XCTest
@testable import Tamio

/// **Cartas no puede abrirse sin una sola plantilla.**
///
/// Desde que la lista salió de la tabla `plantilla` en vez del `enum`
/// (`515a6c6`), una base sin plantillas dejaba el carrusel en blanco y el
/// resumen en "0 templates · 0 issued in September". Eso se lee como "la
/// iglesia borró sus plantillas en el web", y lo que había pasado era que no
/// habían llegado a bajar: la vuelta de sincronización se cayó en un paso
/// anterior y se llevó por delante todos los de abajo.
///
/// El respaldo estaba PROMETIDO en el comentario de `repositorioPlantillas()`
/// desde aquel mismo día y no estaba escrito: la función solo miraba si había
/// sesión. Estas dos pruebas son para que no vuelva a quedarse en el
/// comentario.
final class PlantillaDeRespaldoTests: XCTestCase {

    /// Una base vacía que NUNCA llegó a bajarlas: sin cursor de `plantilla`.
    private struct BaseVaciaSinBajar: PlantillasRepository {
        func catalogo() async -> CatalogoPlantillas { CatalogoPlantillas() }
        func yaSeIntentoBajarlas() async -> Bool { false }
    }

    /// Una base vacía que SÍ las bajó y no había ninguna. Es el caso real del
    /// teléfono de Iván: sesión de "Revisión App Store", cuya iglesia de demo
    /// no siembra plantillas.
    private struct BaseVaciaYaBajada: PlantillasRepository {
        func catalogo() async -> CatalogoPlantillas { CatalogoPlantillas() }
        func yaSeIntentoBajarlas() async -> Bool { true }
    }

    /// Una base con las de la iglesia, con su texto redactado en el web.
    private struct BaseConLasDeLaIglesia: PlantillasRepository {
        func yaSeIntentoBajarlas() async -> Bool { true }
        func catalogo() async -> CatalogoPlantillas {
            CatalogoPlantillas(lista: [
                Plantilla(id: "a", nombre: "Carta de traslado", tipo: .traslado,
                          asunto: "Traslado", cuerpoHtml: "<p>Hola</p>"),
            ])
        }
    }

    func testSinNingunaEnLaBaseSeEnsenanLosTiposGenericos() async {
        let c = await PlantillasConRespaldo(base: BaseVaciaSinBajar()).catalogo()
        XCTAssertFalse(c.lista.isEmpty, "el carrusel de Cartas se abre vacío")
        XCTAssertEqual(c.lista.count, TipoPlantilla.allCases.count)
        XCTAssertTrue(c.deRespaldo,
                      "la pantalla las enseñaría como si fueran las de la iglesia")
    }

    /// **Los dos vacíos no se avisan igual.** "No han bajado todavía" manda a
    /// mirar la red; "esta iglesia no tiene" manda a mirar la cuenta. Dar el
    /// primero cuando el caso es el segundo manda a buscar donde no está, y
    /// eso pasó: el iPhone estaba con la sesión de "Revisión App Store".
    func testSinCursorDiceQueNoHanBajado() async {
        let c = await PlantillasConRespaldo(base: BaseVaciaSinBajar()).catalogo()
        XCTAssertEqual(c.motivo, .noHanBajado)
    }

    func testConCursorYCeroFilasDiceQueLaIglesiaNoTiene() async {
        let c = await PlantillasConRespaldo(base: BaseVaciaYaBajada()).catalogo()
        XCTAssertEqual(c.motivo, .laIglesiaNoTiene)
    }

    /// **Y no se cuelan cuando sí hay.** Un respaldo que pisara las de la
    /// iglesia sería peor que no tenerlo: las suyas traen el texto redactado
    /// y estas traen solo el nombre del tipo.
    func testConLasDeLaIglesiaElRespaldoNoAparece() async {
        let c = await PlantillasConRespaldo(base: BaseConLasDeLaIglesia()).catalogo()
        XCTAssertEqual(c.lista.count, 1)
        XCTAssertEqual(c.lista.first?.nombre, "Carta de traslado")
        XCTAssertFalse(c.deRespaldo)
        XCTAssertNil(c.motivo)
    }

    /// El respaldo no trae texto: por eso la pantalla tiene que avisar y no
    /// limitarse a enseñarlas. Si algún día lo trajera, el aviso sobra y esta
    /// prueba es la que lo recuerda.
    func testElRespaldoNoTraeTextoQueRedactar() async {
        let c = await PlantillasConRespaldo(base: BaseVaciaSinBajar()).catalogo()
        XCTAssertTrue(c.lista.allSatisfy { $0.asunto.isEmpty && $0.cuerpoHtml.isEmpty })
    }
}
