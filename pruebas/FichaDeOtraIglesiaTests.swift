import XCTest
import GRDB
@testable import Tamio

/// **La ficha de una iglesia no se guarda nunca en otra.**
///
/// El 23-sep la iglesia del revisor de Apple amaneció con el nombre, la
/// ciudad, la moneda y los cargos de la iglesia de prueba. La ficha vive en
/// memoria (`ConfiguracionIglesiaViewModel.compartido`), `cargar()` no vuelve
/// a leer, y `guardar` escribe bajo `churchIdActivo`: cerrar sesión y entrar
/// con otra cuenta sin cerrar la app subía la ficha vieja a la iglesia nueva.
@MainActor
final class FichaDeOtraIglesiaTests: XCTestCase {

    private let otra = "prueba-ficha-de-otra-iglesia"
    private var original = ""

    override func setUp() async throws {
        original = churchIdActivo
    }

    override func tearDown() async throws {
        churchIdActivo = original
        // Si la prueba fallara, que no quede nada escrito para la iglesia
        // inventada: ni la fila ni la subida pendiente.
        try await BaseLocal.compartida.cola.write { [otra] db in
            try db.execute(sql: "delete from iglesia where id = ?", arguments: [otra])
            try db.execute(sql: "delete from outbox where entidad = 'iglesia' and registroId = ?",
                           arguments: [otra])
        }
        ConfiguracionIglesiaViewModel.compartido.olvidar()
        await ConfiguracionIglesiaViewModel.compartido.cargar()
    }

    private func escritoPara(_ id: String) async throws -> Bool {
        try await BaseLocal.compartida.cola.read { db in
            let fila = try Int.fetchOne(db, sql: "select count(*) from iglesia where id = ?",
                                        arguments: [id]) ?? 0
            let cola = try Int.fetchOne(db, sql: "select count(*) from outbox where entidad = 'iglesia' and registroId = ?",
                                        arguments: [id]) ?? 0
            return fila + cola > 0
        }
    }

    func testGuardarTrasCambiarDeIglesiaNoEscribeEnLaNueva() async throws {
        let vm = ConfiguracionIglesiaViewModel.compartido
        await vm.recargar()                 // la ficha es de `original`
        churchIdActivo = otra               // entra otra cuenta sin cerrar la app
        await vm.guardarYa()                // p. ej., al salir de Ajustes
        let escrito = try await escritoPara(otra)
        XCTAssertFalse(escrito, "### la ficha de una iglesia se guardó en otra")
    }

    func testEditarTrasCambiarDeIglesiaTampocoEscribe() async throws {
        let vm = ConfiguracionIglesiaViewModel.compartido
        await vm.recargar()
        churchIdActivo = otra
        vm.config.ciudad = vm.config.ciudad + " (editada)"   // programa el guardado
        try await Task.sleep(nanoseconds: 1_300_000_000)      // más que los 800 ms
        let escrito = try await escritoPara(otra)
        XCTAssertFalse(escrito, "### una edición se guardó en la iglesia equivocada")
    }

    /// Y lo que sí tiene que seguir funcionando: en su propia iglesia, guarda.
    func testEnSuPropiaIglesiaSiGuarda() async throws {
        let vm = ConfiguracionIglesiaViewModel.compartido
        vm.olvidar()
        churchIdActivo = otra
        await vm.recargar()                 // lee la de `otra` (vacía): es suya
        await vm.guardarYa()
        let escrito = try await escritoPara(otra)
        XCTAssertTrue(escrito, "### una ficha leída de su iglesia ya no se guarda")
    }
}
