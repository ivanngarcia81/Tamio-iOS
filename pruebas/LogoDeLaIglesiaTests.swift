import GRDB
import XCTest
@testable import Tamio

/// **El logo de la iglesia, de punta a punta salvo el viaje al servidor.**
///
/// Lo que se prueba aquí es lo que falla en silencio: si la migración v25
/// lanza, `BaseLocal` se cae a una base EN MEMORIA sin avisar y se pierde todo
/// lo local (§3 del traspaso). Y si la ruta no sobrevive la ida y vuelta por
/// SQLite, el logo se ve en el aparato que lo subió y en ningún otro.
final class LogoDeLaIglesiaTests: XCTestCase {

    /// La migración corrió y la base sigue siendo la de disco.
    func testLaBaseNoSeCayoAMemoria() async throws {
        XCTAssertFalse(BaseLocal.compartida.enMemoria,
                       "### la v25 lanzó: la base está en memoria y no se guarda nada")
    }

    func testLaColumnaDelLogoExiste() async throws {
        let columnas = try await BaseLocal.compartida.cola.read { db in
            try String.fetchAll(db, sql: "select name from pragma_table_info('iglesia')")
        }
        XCTAssertTrue(columnas.contains("logoPath"),
                      "### sin la columna, la ruta del logo no se guarda: \(columnas)")
    }

    /// La ruta va y vuelve por SQLite sin perderse. Es lo único que viaja: los
    /// bytes viven en Application Support.
    func testLaRutaSobreviveElGuardado() async throws {
        var c = ConfiguracionIglesia()
        c.nombre = "Iglesia de prueba"
        c.logoPath = "iglesia-x/logo/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png"
        let vuelta = IglesiaFila(id: "iglesia-x", c).configuracion
        XCTAssertEqual(vuelta.logoPath, c.logoPath)
        XCTAssertEqual(vuelta.nombre, c.nombre,
                       "### el orden del init por miembros se desalineó al meter logoPath")
    }

    // MARK: - Preparar la imagen

    private func imagen(_ ancho: Int, _ alto: Int) -> UIImage {
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: ancho, height: alto),
                                       format: formato).image { ctx in
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: ancho, height: alto))
        }
    }

    /// Una foto del carrete son varios MB y 4000 px de lado. Sin encoger, cada
    /// bajada de la iglesia se traería eso para pintarlo a 52 puntos.
    @MainActor
    func testUnaFotoGrandeSeEncoge() {
        let salida = LogoIglesia.preparada(imagen(4032, 3024))
        XCTAssertEqual(max(salida.size.width, salida.size.height), 1024)
        // La proporción se conserva: un logo apaisado no puede salir cuadrado.
        XCTAssertEqual(salida.size.height, 768, accuracy: 1)
    }

    /// Un logo ya pequeño se deja como está: reescalarlo solo lo emborrona.
    @MainActor
    func testUnLogoPequenoNoSeToca() {
        let entrada = imagen(300, 120)
        let salida = LogoIglesia.preparada(entrada)
        XCTAssertEqual(salida.size, entrada.size)
    }

    /// PNG y no JPEG: un logo recortado trae fondo transparente, y en JPEG la
    /// transparencia se rellena de blanco — un rectángulo encima del membrete.
    @MainActor
    func testConservaLaTransparencia() throws {
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        formato.opaque = false
        let conAlfa = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 2000),
                                              format: formato).image { _ in }
        let datos = try XCTUnwrap(LogoIglesia.preparada(conAlfa).pngData())
        let vuelta = try XCTUnwrap(UIImage(data: datos)?.cgImage)
        XCTAssertNotEqual(vuelta.alphaInfo, .none,
                          "### se perdió el canal alfa al preparar el logo")
    }
}

/// **La v25 sobre una base que ya existía**, que es el caso que la prueba de
/// arriba NO cubre: allí la base nace de cero con todas las migraciones puestas
/// y cualquier `alter table` roto pasaría desapercibido.
///
/// Es la receta del §3 del traspaso —sembrar con el código anterior, migrar,
/// comprobar que la fila sigue— hecha sin desinstalar nada: el migrador se
/// detiene en la v24, se siembra, y luego se le deja terminar.
final class MigracionV25Tests: XCTestCase {

    func testLaIglesiaSembradaEnLaV24SobreviveALaV25() throws {
        let cola = try DatabaseQueue()
        let migrador = BaseLocal.migrador

        try migrador.migrate(cola, upTo: "v24_folioProvisional")
        try cola.write { db in
            try db.execute(sql: "insert into iglesia (id, nombre) values (?, ?)",
                           arguments: ["iglesia-x", "Iglesia Nueva Vida"])
        }

        // Si esto lanza, en la app de verdad no hay error: hay una base en
        // memoria y los datos de la iglesia desaparecidos.
        try migrador.migrate(cola)

        let (nombre, logo) = try cola.read { db -> (String?, String?) in
            (try String.fetchOne(db, sql: "select nombre from iglesia where id = 'iglesia-x'"),
             try String.fetchOne(db, sql: "select logoPath from iglesia where id = 'iglesia-x'"))
        }
        XCTAssertEqual(nombre, "Iglesia Nueva Vida", "### la migración se llevó la iglesia por delante")
        XCTAssertEqual(logo, "", "### la columna nueva no trajo su valor por omisión")
    }
}
