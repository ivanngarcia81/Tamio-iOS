import XCTest
@testable import Tamio

/// **Decir qué columna es cuál.**
///
/// Los dos importadores exigían los nombres de columna exactos, así que solo
/// tragaban archivos salidos de la propia exportación de Tamio. Esto es el
/// reflejo del `csvImport.ts` del web: se sugiere, el usuario corrige, y el
/// documento se reescribe con las claves de la app.
final class MapeoDeColumnasTests: XCTestCase {

    private func doc(_ encabezados: [String], _ filas: [[String]]) -> CSVLector.Documento {
        CSVLector.Documento(encabezados: encabezados, filas: filas)
    }

    private let campos = ImportadorAportantes.campos

    /// **Lo que no puede empeorar:** un archivo exportado por Tamio se
    /// reconocía entero antes y tiene que seguir reconociéndose solo.
    func testUnArchivoDeTamioSeMapeaSolo() {
        let d = doc(["nombre", "correo", "telefono"], [["Ana", "a@b.c", "555"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        XCTAssertEqual(mapeo["nombre"], "nombre")
        XCTAssertEqual(mapeo["correo"], "correo")
        XCTAssertTrue(CSVLector.faltantes(mapeo, campos: campos).isEmpty,
                      "### un archivo propio pediría mapeo a mano")
    }

    /// Y el caso que motivó todo esto: un Excel cualquiera.
    func testUnExcelConOtrosNombresTambienSeReconoce() {
        let d = doc(["Full Name", "E-mail", "Phone"], [["Ana", "a@b.c", "555"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        XCTAssertEqual(mapeo["nombre"], "Full Name")
        XCTAssertEqual(mapeo["correo"], "E-mail")
        XCTAssertEqual(mapeo["telefono"], "Phone")
    }

    /// **El normalizador, directo.** Se rompió con "E-mail": la primera
    /// versión solo cambiaba espacios, y un encabezado de Excel trae guiones,
    /// puntos y paréntesis.
    func testElNormalizadorTrataTodoSeparadorIgual() {
        for entrada in ["E-mail", "e mail", " E.Mail ", "E_MAIL", "e/mail"] {
            XCTAssertEqual(CSVLector.normalizar(entrada), "e_mail",
                           "### \(entrada) no se normalizó igual")
        }
        XCTAssertEqual(CSVLector.normalizar(" TELÉFONO "), "telefono")
        XCTAssertEqual(CSVLector.normalizar("Full Name"), "full_name")
    }

    /// **Los encabezados en español llevan artículos.** "Fecha de ingreso" no
    /// casaba con el alias `fecha_ingreso`, y se vio en la foto de la pantalla,
    /// no en el código.
    func testLosEncabezadosConArticuloTambienCasan() {
        let d = doc(["Full Name", "Fecha de ingreso", "Fecha de nacimiento"], [["Ana", "2019-03-04", "1980-01-01"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        XCTAssertEqual(mapeo["miembro_desde"], "Fecha de ingreso",
                       "### 'Fecha de ingreso' no se reconoció")
        XCTAssertEqual(mapeo["nacimiento"], "Fecha de nacimiento")
    }

    /// Acentos, mayúsculas y espacios no deben decidir nada.
    func testAcentosYMayusculasNoImportan() {
        let d = doc([" TELÉFONO ", "Dirección"], [["555", "Calle 1"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        XCTAssertEqual(mapeo["telefono"], " TELÉFONO ")
        XCTAssertEqual(mapeo["direccion"], "Dirección")
    }

    /// Una columna del archivo no puede alimentar dos campos a la vez.
    func testUnaColumnaNoSeAsignaDosVeces() {
        // "id" es alias de `aportante_id` y también la clave de `id`.
        let d = doc(["id"], [["x"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: ImportadorAportes.campos)
        let usadas = mapeo.values.filter { $0 == "id" }
        XCTAssertEqual(usadas.count, 1, "### la misma columna alimentando dos campos")
    }

    /// El documento resultante habla en las claves de la app, y lo que no se
    /// mapeó queda vacío —que es lo que cada importador sabe rellenar.
    func testAplicarReescribeConLasClavesDeLaApp() {
        let d = doc(["Full Name", "Phone"], [["Ana", "555"], ["Luis", "666"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        let m = CSVLector.aplicar(mapeo, a: d, campos: campos)

        XCTAssertEqual(m.encabezados, campos.map(\.clave))
        XCTAssertEqual(m.valor(m.filas[0], "nombre"), "Ana")
        XCTAssertEqual(m.valor(m.filas[1], "telefono"), "666")
        XCTAssertEqual(m.valor(m.filas[0], "correo"), "",
                       "### una columna que no venía debería quedar vacía")
    }

    /// Y lo que apaga el botón de continuar.
    func testLosObligatoriosSinColumnaSeDelatan() {
        let d = doc(["Phone"], [["555"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        XCTAssertEqual(CSVLector.faltantes(mapeo, campos: campos).map(\.clave), ["nombre"])
    }

    /// En aportes, quién aporta NO es obligatorio: un diezmo de alguien sin
    /// ficha se registra igual. Solo fecha e importe.
    func testEnAportesSoloFechaEImporteSonObligatorios() {
        let d = doc(["Date", "Amount"], [["2026-01-04", "700"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: ImportadorAportes.campos)
        XCTAssertTrue(CSVLector.faltantes(mapeo, campos: ImportadorAportes.campos).isEmpty)
        XCTAssertEqual(mapeo["fecha"], "Date")
        XCTAssertEqual(mapeo["monto"], "Amount")
    }

    /// Una fila más corta que el encabezado no puede reventar el mapeo: los
    /// CSV de verdad vienen así cuando la última columna va vacía.
    func testUnaFilaCortaNoRevienta() {
        let d = doc(["nombre", "correo"], [["Ana"]])
        let mapeo = CSVLector.mapeoSugerido(d, campos: campos)
        let m = CSVLector.aplicar(mapeo, a: d, campos: campos)
        XCTAssertEqual(m.valor(m.filas[0], "nombre"), "Ana")
        XCTAssertEqual(m.valor(m.filas[0], "correo"), "")
    }
}
