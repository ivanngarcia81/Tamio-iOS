import XCTest
@testable import Tamio

/// **Lo que se guarda en `categoria` es la CLAVE, no la etiqueta traducida.**
///
/// Hasta el 13-sep-2026 el `Picker` guardaba lo que se leía en pantalla
/// (`NuevoMovimientoView`, `.tag($0)` sobre `Catalogos.categorias`), así que lo
/// escrito dependía del idioma que tuviera la app: el mismo diezmo acababa en
/// `diezmo`, `Diezmo` y `Tithe`, y el reparto por categoría del estado
/// financiero —que se imprime y se firma— lo enseñaba partido en tres.
///
/// Se pone en la misma pauta que los catálogos del padrón —ministerios,
/// cargos, estado civil—, que ya guardan claves y traducen al pintar porque así
/// las escribió el web. Las categorías eran la excepción.
///
/// **Lo que esto NO arregla**, y necesita al otro repo: que los vocabularios de
/// las dos apps no coincidan donde significan lo mismo —iOS dice `donativo` y
/// el web `donacion`; iOS `otro` y el web `otros`— y que el web use `eventos`
/// para *Alimentos*. Va en `docs/ACUERDO-CON-EL-WEB.md` §2.
final class CategoriaSeGuardaPorClaveTests: XCTestCase {

    // MARK: - Lo que ofrece el Picker

    /// Las opciones del selector son claves, no etiquetas.
    func testElSelectorOfreceClaves() {
        let ingresos = Catalogos.clavesDeCategoria(.ingreso)
        XCTAssertTrue(ingresos.contains("diezmo"), "faltó la clave del diezmo: \(ingresos)")
        XCTAssertFalse(ingresos.contains("Diezmo"), "el selector sigue ofreciendo la etiqueta")
        XCTAssertFalse(ingresos.contains("Tithe"), "el selector sigue ofreciendo la etiqueta")

        let gastos = Catalogos.clavesDeCategoria(.gasto)
        XCTAssertTrue(gastos.contains("suministros"))
        XCTAssertFalse(gastos.contains("Supplies"))
    }

    /// **Y lo que se ofrece no depende del idioma.** Es la mitad del problema:
    /// con etiquetas, el mismo catálogo daba dos listas distintas.
    func testLoQueSeOfreceNoCambiaConElIdioma() {
        // Las claves son literales del enum, así que no pasan por `L.t`.
        let claves = Set(Catalogos.clavesDeCategoria(.ingreso))
        let etiquetas = Set(Catalogos.categorias(.ingreso))
        XCTAssertNotEqual(claves, etiquetas, """
            Las claves y las etiquetas coinciden, así que esta prueba no \
            distingue nada: mirar si el catálogo cambió de forma.
            """)
        // Todas las claves resuelven a sí mismas.
        for c in claves {
            XCTAssertEqual(Catalogos.clave(deEtiqueta: c)?.rawValue, c,
                           "la clave «\(c)» no se resuelve a sí misma")
        }
    }

    // MARK: - Lo heredado

    /// Una etiqueta guardada por la app vieja se normaliza a su clave, venga
    /// del idioma que venga. Es lo que convierte el `Tithe` de ayer en el
    /// `diezmo` de hoy sin migración.
    func testLoHeredadoSeNormalizaASuClave() {
        for viejo in ["Diezmo", "Tithe", "diezmo"] {
            XCTAssertEqual(Catalogos.categoriaGuardable(viejo), "diezmo",
                           "«\(viejo)» no se normalizó")
        }
        for viejo in ["Otro", "Other"] {
            XCTAssertEqual(Catalogos.categoriaGuardable(viejo), "otro")
        }
        for viejo in ["Supplies", "Suministros"] {
            XCTAssertEqual(Catalogos.categoriaGuardable(viejo), "suministros")
        }
    }

    /// **Una categoría de la iglesia se queda como su dueño la escribió.** No
    /// tiene clave, y inventarle una sería perder su nombre.
    func testUnaCategoriaDeLaIglesiaSeQuedaComoEsta() {
        let propia = "Café de bienvenida"
        XCTAssertEqual(Catalogos.categoriaGuardable(propia), propia)
        XCTAssertEqual(Catalogos.etiquetaDeCategoria(propia), propia)
        XCTAssertNil(Catalogos.clave(deEtiqueta: propia))
    }

    // MARK: - Lo que se pinta

    /// La clave guardada se lee como la etiqueta del idioma de ahora.
    func testLaClaveSePintaComoEtiqueta() {
        let pintada = Catalogos.etiquetaDeCategoria("diezmo")
        XCTAssertNotEqual(pintada, "diezmo", "se está enseñando la clave en crudo")
        XCTAssertEqual(Catalogos.clave(deEtiqueta: pintada), .diezmo,
                       "la etiqueta pintada ya no resuelve a su clave")
    }

    /// Ida y vuelta sobre TODAS las claves: guardar → pintar → volver a la
    /// misma clave. Sin esto, una sola clave mal resuelta parte un cubo del
    /// reporte sin que nadie lo note.
    func testTodasLasClavesVanYVuelven() {
        for clave in CategoriaClave.allCases {
            let guardada = clave.rawValue
            let pintada = Catalogos.etiquetaDeCategoria(guardada)
            XCTAssertEqual(Catalogos.clave(deEtiqueta: pintada), clave,
                           "«\(guardada)» se pinta «\(pintada)» y ya no vuelve")
            XCTAssertEqual(Catalogos.categoriaGuardable(pintada), guardada,
                           "«\(pintada)» no vuelve a guardarse como «\(guardada)»")
        }
    }

    /// **`ayudaSocial` es la que lo destapó.** Las claves se resolvían por
    /// casualidad —casi todas se escriben igual que su etiqueta española— y
    /// esta, en camello, no: normalizada es `ayudasocial` y su etiqueta es
    /// `ayuda social`, con espacio. Ninguna raíz la alcanzaba. Ahora las claves
    /// están puestas a mano en la tabla y la casualidad es contrato.
    func testLaClaveEnCamelloTambienResuelve() {
        XCTAssertEqual(Catalogos.clave(deEtiqueta: "ayudaSocial"), .ayudaSocial)
        XCTAssertEqual(Catalogos.categoriaGuardable("ayudaSocial"), "ayudaSocial")
        XCTAssertEqual(Catalogos.clave(deEtiqueta: "Ayuda social"), .ayudaSocial)
    }

    /// Y el orden de las raíces sigue mandando donde importa: «Ayuda social» no
    /// puede resolverse como «Ayudas».
    func testAyudaSocialNoSeConfundeConAyudas() {
        XCTAssertEqual(Catalogos.clave(deEtiqueta: "Ayuda social"), .ayudaSocial)
        XCTAssertEqual(Catalogos.clave(deEtiqueta: "Ayudas"), .ayudas)
    }
}
