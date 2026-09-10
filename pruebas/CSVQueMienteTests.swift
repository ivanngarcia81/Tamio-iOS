import XCTest
@testable import Tamio

/// **CSV retorcidos.** El importador de aportes es la puerta por la que entra
/// dinero en bloque: un archivo que se lee mal mete cifras falsas en el libro
/// sin que nadie las teclee.
final class CSVQueMiente: XCTestCase {

    func escribir(_ texto: String, _ nombre: String = "prueba.csv", bom: Bool = false) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        var datos = Data()
        if bom { datos.append(contentsOf: [0xEF, 0xBB, 0xBF]) }
        datos.append(texto.data(using: .utf8)!)
        try? datos.write(to: url)
        return url
    }

    /// El BOM de Excel no debe estropear el nombre de la primera columna.
    func testBOM() throws {
        let doc = try CSVLector.leer(escribir("nombre,monto\nAna,100\n", bom: true))
        XCTAssertEqual(doc.encabezados, ["nombre", "monto"])
    }

    /// Filas vacías en medio, no solo al final.
    func testFilasVacias() throws {
        let doc = try CSVLector.leer(escribir("nombre,monto\nAna,100\n\n\nLuis,200\n\n"))
        XCTAssertEqual(doc.filas.count, 2)
    }

    /// Comas dentro de un nombre entrecomillado.
    func testComaDentroDelNombre() throws {
        let doc = try CSVLector.leer(escribir("nombre,monto\n\"Márquez Peña, Lucía\",100\n"))
        XCTAssertEqual(doc.valor(doc.filas[0], "nombre"), "Márquez Peña, Lucía")
    }

    /// **Columnas duplicadas.** Un Excel con dos columnas llamadas igual —pasa
    /// al pegar dos hojas— deja al usuario eligiendo entre dos opciones que se
    /// llaman igual, y `aplicar` resuelve siempre por `firstIndex(of:)`: elija
    /// la que elija, se lleva la PRIMERA. Si la buena era la segunda, el
    /// importe que entra es otro y nada lo dice.
    func testColumnasDuplicadas() throws {
        let doc = try CSVLector.leer(escribir("nombre,monto,monto\nAna,100,999\n"))
        XCTAssertEqual(doc.encabezados, ["nombre", "monto", "monto"])
        let campos = [CSVLector.Campo("nombre", "Nombre", obligatorio: true),
                      CSVLector.Campo("monto", "Monto", obligatorio: true)]
        // El usuario elige a mano la SEGUNDA columna "monto" (la de 999).
        let mapeo = ["nombre": "nombre", "monto": "monto"]
        let salida = CSVLector.aplicar(mapeo, a: doc, campos: campos)
        XCTAssertEqual(salida.valor(salida.filas[0], "monto"), "999",
                       "No hay forma de elegir la segunda columna con el mismo nombre")
    }

    /// El mismo archivo con los encabezados en el otro idioma.
    func testEncabezadosEnIngles() throws {
        let doc = try CSVLector.leer(escribir("name,amount,date\nAna,100,2026-09-01\n"))
        let campos = [CSVLector.Campo("aportante_nombre", "Nombre", obligatorio: true,
                                      alias: ["nombre", "name", "giver"]),
                      CSVLector.Campo("monto", "Monto", obligatorio: true,
                                      alias: ["amount", "importe"]),
                      CSVLector.Campo("fecha", "Fecha", obligatorio: true,
                                      alias: ["date"])]
        let mapeo = CSVLector.mapeoSugerido(doc, campos: campos)
        XCTAssertEqual(CSVLector.faltantes(mapeo, campos: campos).count, 0,
                       "no reconoció los encabezados en inglés: \(mapeo)")
    }

    /// Los dos formatos de importe, que es lo que `Money.desdeTexto` promete.
    func testLosDosFormatosDeImporte() {
        XCTAssertEqual(Money.desdeTexto("1,960.00"), 196_000)
        XCTAssertEqual(Money.desdeTexto("1.960,00"), 196_000)
        XCTAssertEqual(Money.desdeTexto("1960"), 196_000)
    }

    /// **Un importe con letras dentro NO debería colarse.** `desdeTexto` borra
    /// todo lo que no sea dígito, punto, coma o menos: "1e9" se lee $19.00 y
    /// "12 pesos 34" se lee $1,234.00, sin avisar. En un importador que ya
    /// rechaza lo que no entiende, esto es peor que rechazarlo: entra una cifra
    /// plausible y falsa.
    func testUnImporteConLetrasSeDeberiaRechazar() {
        XCTAssertNil(Money.desdeTexto("1e9"), "se leyó como \(Money.desdeTexto("1e9") ?? -1) centavos")
        XCTAssertNil(Money.desdeTexto("12 pesos 34"),
                     "se leyó como \(Money.desdeTexto("12 pesos 34") ?? -1) centavos")
    }

    /// Un archivo grande no debe tardar una eternidad ni perder filas.
    func testCincoMilFilas() throws {
        var texto = "nombre,monto,fecha\n"
        for i in 1...5000 { texto += "Persona \(i),\(i).50,2026-09-01\n" }
        let url = escribir(texto, "grande.csv")
        let t0 = Date()
        let doc = try CSVLector.leer(url)
        let tardo = Date().timeIntervalSince(t0)
        print("CINCO-MIL: \(doc.filas.count) filas en \(String(format: "%.2f", tardo)) s")
        XCTAssertEqual(doc.filas.count, 5000)
        XCTAssertLessThan(tardo, 5.0, "tardó \(tardo) s en leer 5.000 filas")
    }

    /// El separador se decide con la PRIMERA línea. Un archivo cuyo encabezado
    /// lleva una coma dentro de comillas y usa punto y coma se troceará mal.
    func testSeparadorConComaEnElEncabezado() throws {
        let doc = try CSVLector.leer(escribir("\"nombre, apellido\";monto\nAna;100\n"))
        XCTAssertEqual(doc.encabezados.count, 2,
                       "el separador se detectó mal: \(doc.encabezados)")
    }
}
