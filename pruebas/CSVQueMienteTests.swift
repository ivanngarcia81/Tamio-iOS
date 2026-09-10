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
    /// al pegar dos hojas— dejaba al usuario eligiendo entre dos opciones con el
    /// mismo nombre, y `aplicar` resolvía por `firstIndex(of:)`: elija la que
    /// elija, se llevaba la PRIMERA. Ahora la segunda se llama "monto (2)", así
    /// que se puede pedir, y el `Picker` del mapeo deja de tener dos ids
    /// iguales.
    func testSeLlegaALaSegundaColumnaDuplicada() throws {
        let doc = try CSVLector.leer(escribir("nombre,monto,monto\nAna,100,999\n"))
        XCTAssertEqual(doc.encabezados, ["nombre", "monto", "monto (2)"])
        let campos = [CSVLector.Campo("nombre", "Nombre", obligatorio: true),
                      CSVLector.Campo("monto", "Monto", obligatorio: true)]
        // El usuario elige a mano la SEGUNDA columna (la de 999).
        let salida = CSVLector.aplicar(["nombre": "nombre", "monto": "monto (2)"],
                                       a: doc, campos: campos)
        XCTAssertEqual(salida.valor(salida.filas[0], "monto"), "999")
        // Y la primera sigue siendo alcanzable.
        let primera = CSVLector.aplicar(["nombre": "nombre", "monto": "monto"],
                                        a: doc, campos: campos)
        XCTAssertEqual(primera.valor(primera.filas[0], "monto"), "100")
    }

    /// Y la sugerencia automática sigue cogiendo la primera, que es lo sensato
    /// cuando nadie ha dicho nada.
    func testLaSugerenciaCogeLaPrimeraDeLasDuplicadas() throws {
        let doc = try CSVLector.leer(escribir("nombre,monto,monto\nAna,100,999\n"))
        let campos = [CSVLector.Campo("monto", "Monto", obligatorio: true)]
        XCTAssertEqual(CSVLector.mapeoSugerido(doc, campos: campos)["monto"], "monto")
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

    /// **Un importe con letras DENTRO se rechaza.** `desdeTexto` borraba todo
    /// lo que no fuera dígito o separador viniera de donde viniera, así que
    /// "1e9" se leía $19.00 y "12 pesos 34" se leía $1,234.00, sin avisar. En un
    /// importador que ya rechaza lo que no entiende —y lo enseña en la previa—
    /// eso es peor que rechazarlo: entra una cifra plausible y falsa.
    func testUnImporteConLetrasDentroSeRechaza() {
        for basura in ["1e9", "12 pesos 34", "1.2.3.4x", "N/D", "—", "pendiente"] {
            XCTAssertNil(Money.desdeTexto(basura),
                         "«\(basura)» se leyó como \(Money.desdeTexto(basura) ?? -1) centavos")
        }
    }

    /// **Y el símbolo o el código de moneda, que van en los extremos, siguen
    /// pasando.** Es la lenience que había que conservar al apretar la regla.
    func testElSimboloYElCodigoDeMonedaSiguenPasando() {
        XCTAssertEqual(Money.desdeTexto("$1,960.00"), 196_000)
        XCTAssertEqual(Money.desdeTexto("1.960,00 MXN"), 196_000)
        XCTAssertEqual(Money.desdeTexto("USD 1960"), 196_000)
        XCTAssertEqual(Money.desdeTexto("€ 1 960,00"), 196_000)
        XCTAssertEqual(Money.desdeTexto("  1960,00  "), 196_000)
        XCTAssertEqual(Money.desdeTexto("-50"), -5_000)
        XCTAssertEqual(Money.desdeTexto("MXN -50"), -5_000)
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

    /// El separador se decide con la PRIMERA línea, y **sin mirar dentro de las
    /// comillas**: con `"nombre, apellido";monto` ganaba la coma y el archivo
    /// entero se quedaba en una sola columna. El archivo era correcto y la app
    /// decía que le faltaban las columnas obligatorias.
    func testSeparadorConComaEnElEncabezado() throws {
        let doc = try CSVLector.leer(escribir("\"nombre, apellido\";monto\nAna;100\n"))
        XCTAssertEqual(doc.encabezados, ["nombre, apellido", "monto"])
        XCTAssertEqual(doc.valor(doc.filas[0], "nombre, apellido"), "Ana")
    }

    /// El control del de arriba: un archivo de comas de verdad se sigue
    /// detectando como tal aunque un campo entrecomillado lleve un punto y coma.
    func testSeparadorDeComasConPuntoYComaEntreComillas() throws {
        let doc = try CSVLector.leer(escribir("\"apellido; nombre\",monto\nAna,100\n"))
        XCTAssertEqual(doc.encabezados, ["apellido; nombre", "monto"])
    }
}
