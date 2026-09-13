import XCTest
@testable import Tamio

/// **La columna `transactions.categoria` guarda tres formas distintas, y una de
/// ellas significa otra cosa en cada app.**
///
/// Salió de la prueba de modo avión del 12-sep: los dos movimientos capturados
/// guardaron `categoria = "Other"`, en inglés. Mirando el servidor, el mismo
/// concepto está repartido en hasta tres cubos.
///
/// **De dónde sale cada forma:**
///
/// - **iOS guarda la ETIQUETA TRADUCIDA.** `Catalogos.categorias(_:)` devuelve
///   `catalogo(tipo).map(\.etiqueta)` y el `Picker` guarda tal cual lo
///   seleccionado (`NuevoMovimientoView:331`, `.tag($0)`). Con la app en
///   español escribe `Diezmo`; en inglés, `Tithe`.
/// - **El web guarda la CLAVE.** `CATEGORIAS_INGRESO`/`CATEGORIAS_GASTO` de
///   `src/db.ts` son `{ id, nombre }` y lo que persiste es el `id`: `diezmo`,
///   `ofrenda`, `donacion`, `otros`…
///
/// Leer no es el problema: `Catalogos.clave(deEtiqueta:)` resuelve casi todo,
/// por etiqueta exacta o por raíz. **El problema es que dos claves del web
/// significan en el web una cosa y en iOS otra**, porque el catálogo del web
/// tiene `id` heredados que ya no se corresponden con su `nombre`:
///
///     { id: "eventos",        nombre: "Alimentos"    }
///     { id: "musicos",        nombre: "Suministros"  }
///     { id: "pastores",       nombre: "Compensación" }
///     { id: "administracion", nombre: "Varios"       }
///
/// Esta prueba no arregla nada: fija qué resuelve hoy cada clave del web, para
/// que la decisión se tome sobre la tabla y para que un cambio en el resolutor
/// no pase inadvertido.
final class CategoriasEntreLasDosAppsTests: XCTestCase {

    /// Las quince claves que el web puede escribir, tal cual salen de
    /// `src/db.ts`, con el `nombre` que el web les pone y la clave de iOS que
    /// ESE nombre designa.
    ///
    /// **Se compara clave contra clave, no etiqueta contra etiqueta.** La
    /// primera versión de esta prueba comparaba `Catalogos.etiqueta(de:)` con
    /// el `nombre` del web y falló once veces seguidas: la app del aparato está
    /// en INGLÉS, así que devolvía «Tithe» donde el web dice «Diezmo». Once
    /// fallos que no eran del producto sino de medir con una vara que depende
    /// del idioma — y con esos once habría escrito un hallazgo cuatro veces más
    /// grande que el real.
    private let clavesDelWeb: [(clave: String,
                                nombreEnElWeb: String,
                                deberiaSer: CategoriaClave?)] = [
        ("ofrenda",        "Ofrenda",       .ofrenda),
        ("diezmo",         "Diezmo",        .diezmo),
        ("donacion",       "Donación",      .donativo),
        ("otros",          "Otros",         .otro),
        ("pastores",       "Compensación",  .compensacion),
        ("musicos",        "Suministros",   .suministros),
        ("administracion", "Varios",        .varios),
        ("limpieza",       "Limpieza",      .limpieza),
        ("servicios",      "Utilidades",    .utilidades),
        ("mantenimiento",  "Mantenimiento", .mantenimiento),
        ("eventos",        "Alimentos",     .alimentos),
        ("misiones",       "Misiones",      .misiones),
        ("ayudas",         "Ayudas",        .ayudas),
        ("tecnologia",     "Tecnología",    .tecnologia),
        ("transporte",     "Transporte",    .transporte),
    ]

    /// El volcado completo, que es el documento: qué hace iOS con cada clave
    /// del web. No afirma nada, imprime.
    func testQueEntiendeIOSDeCadaClaveDelWeb() {
        print("QA-CAT: clave del web → clave que resuelve iOS · la que debería · veredicto")
        var mal: [String] = []
        for (clave, nombre, deberia) in clavesDelWeb {
            let resuelta = Catalogos.clave(deEtiqueta: clave)
            let veredicto: String
            if resuelta == nil { veredicto = "SIN RECONOCER"; mal.append(clave) }
            else if resuelta == deberia { veredicto = "ok" }
            else { veredicto = "NO COINCIDE"; mal.append(clave) }
            print("QA-CAT:  \(clave.padding(toLength: 16, withPad: " ", startingAt: 0)) → " +
                  "\((resuelta?.rawValue ?? "nil").padding(toLength: 14, withPad: " ", startingAt: 0)) · " +
                  "debería \((deberia?.rawValue ?? "nil").padding(toLength: 14, withPad: " ", startingAt: 0)) · " +
                  "\(veredicto)   (web lo llama «\(nombre)»)")
        }
        print("QA-CAT-RESUMEN: \(clavesDelWeb.count - mal.count) de \(clavesDelWeb.count) " +
              "cuadran · no cuadran: \(mal)")
    }

    /// **Las diez que sí cuadran.** Son la mayoría, y por eso el problema se ve
    /// poco: `servicios` → Utilidades está resuelto a propósito con una raíz.
    func testLasQueCuadranEntreLasDosApps() {
        let cuadran = ["ofrenda", "diezmo", "donacion", "limpieza", "servicios",
                       "mantenimiento", "misiones", "ayudas", "tecnologia", "transporte"]
        for clave in cuadran {
            let fila = clavesDelWeb.first { $0.clave == clave }!
            XCTAssertEqual(Catalogos.clave(deEtiqueta: clave), fila.deberiaSer,
                           "«\(clave)» dejó de coincidir con lo que el web entiende")
        }
    }

    /// **`eventos` es el que está mal HOY y con dinero dentro.**
    ///
    /// El web lo usa para **Alimentos**; iOS lo resuelve como **Eventos**,
    /// porque «eventos» es la etiqueta española de su propia categoría
    /// `.eventos` y `porEtiqueta` casa exacto antes de mirar las raíces.
    ///
    /// Medido en el servidor el 12-sep: **tres gastos, $1.480**, y sus
    /// conceptos lo confirman sin lugar a duda —«Carne», «comida», «Carne»—.
    /// Están en el estado financiero bajo «Eventos».
    func testEventosSignificaAlimentosEnElWebYEventosEnIOS() throws {
        let k = try XCTUnwrap(Catalogos.clave(deEtiqueta: "eventos"))
        print("QA-CAT-EVENTOS: el web escribe «eventos» para Alimentos; " +
              "iOS lo resuelve como «\(k.rawValue)» y lo enseña como " +
              "«\(Catalogos.etiqueta(de: k))»")

        // Describe el estado de HOY a propósito: el día que se arregle fallará,
        // y ese fallo es la señal.
        XCTAssertEqual(k, .eventos, """
            «eventos» ya no se resuelve como .eventos. Si ahora da .alimentos, \
            la colisión con el web está cerrada y esta prueba hay que \
            reescribirla al revés.
            """)
        XCTAssertNotEqual(k, .alimentos)
    }

    /// Y las dos que iOS no reconoce y pinta en gris. No hay ninguna en la base
    /// de la iglesia hoy, así que son riesgo latente y no defecto activo — pero
    /// `otros` es la categoría por omisión del web, así que llegará.
    func testDosClavesDelWebNoLasReconoceIOS() {
        for clave in ["administracion", "otros"] {
            XCTAssertNil(Catalogos.clave(deEtiqueta: clave), """
                «\(clave)» ya se reconoce. Si es a propósito, bien; si salió de \
                una raíz nueva, comprobar que no arrastró otra categoría con \
                ella —el orden de `raices` importa—.
                """)
        }
        // El contraste: la etiqueta que SÍ escribe iOS para lo mismo.
        XCTAssertNotNil(Catalogos.clave(deEtiqueta: "Otro"))
        XCTAssertNotNil(Catalogos.clave(deEtiqueta: "Other"))
        print("QA-CAT-OTROS: el web escribe «otros» y iOS no lo reconoce; " +
              "iOS escribe «Otro»/«Other», que sí")
    }

    /// **La raíz del asunto, en una línea:** lo que iOS guarda depende del
    /// idioma de la app. Con el mismo catálogo y la misma selección, dos
    /// teléfonos escriben dos valores distintos para el mismo concepto.
    func testLoQueIOSGuardaDependeDelIdiomaDeLaApp() {
        let enUnIdioma = Catalogos.categorias(.ingreso)
        XCTAssertFalse(enUnIdioma.isEmpty)
        // Las etiquetas del catálogo, en los dos idiomas, resuelven a la misma
        // clave: leer está resuelto. Lo que no lo está es ESCRIBIR.
        XCTAssertEqual(Catalogos.clave(deEtiqueta: "Diezmo"),
                       Catalogos.clave(deEtiqueta: "Tithe"))
        XCTAssertEqual(Catalogos.clave(deEtiqueta: "Otro"),
                       Catalogos.clave(deEtiqueta: "Other"))
        print("QA-CAT-IDIOMA: el catálogo de ingresos de esta app dice \(enUnIdioma)")
    }
}
