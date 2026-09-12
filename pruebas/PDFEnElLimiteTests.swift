import XCTest
import PDFKit
@testable import Tamio

/// **Z3: los PDF en el límite.** Sin tocar desde que existen.
///
/// Los cuatro casos que el encargo pedía —mes sin movimientos, 500 filas, sin
/// logo ni firmas, y cuánto tarda— se montan con datos SINTÉTICOS y no con los
/// del aparato, por tres razones: no dependen de que el aparato tenga hoy un
/// mes vacío, no escriben nada, y 500 filas no se pueden conseguir de otra
/// forma sin sembrar movimientos reales.
///
/// **Lo que hay que entender de `PDFExport` para leer estas medidas.** No
/// recorta ni compone páginas: renderiza la vista entera como UNA imagen alta
/// y luego la corta en trozos de alto de carta
/// (`paginas = ceil((size.height - blancoDePie) / altoCarta)`, `:55`, y la
/// traslación de `:59`). De ahí salen dos consecuencias que estas pruebas
/// miden en vez de suponer:
///
/// 1. **El membrete sale UNA vez**, en la página 1. Las páginas 2 y siguientes
///    no llevan encabezado ni número.
/// 2. **El corte cae donde caiga**, por altura y no por línea, así que una fila
///    de la tabla puede partirse por la mitad entre dos páginas.
///
/// Los PDF se dejan en `Documents/` para sacarlos con
/// `devicectl device copy from` y MIRARLOS, que es lo único que dice si además
/// de caber se leen.
@MainActor
final class PDFEnElLimiteTests: XCTestCase {

    private var destino: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Fixtures

    private func iglesiaCompleta() -> ConfiguracionIglesia {
        var c = ConfiguracionIglesia()
        c.nombre = "Iglesia Nueva Vida"
        c.ciudad = "Monterrey"
        c.pastorNombre = "Samuel Ruvalcaba"
        c.tesoreroNombre = "Rafael Pérez"
        c.secretarioNombre = "Lucía Márquez"
        return c
    }

    /// El caso más común en una iglesia nueva: recién registrada, sin logo,
    /// sin firmas y sin cargos.
    private func iglesiaDesnuda() -> ConfiguracionIglesia { ConfiguracionIglesia() }

    private func estado(ingresos: Centavos, gastos: Centavos,
                        categorias: Int = 3, meses: Int = 6,
                        depositos: Int = 2) -> EstadoFinanciero {
        // **Cada paso en su propia línea con el tipo escrito.** La versión
        // compacta —la división y un `max` dentro del literal de
        // `CategoriaMonto`— hizo que el compilador se rindiera: «unable to
        // type-check this expression in reasonable time». No es un error de
        // lógica y el mensaje no señala la parte culpable.
        let divisor: Centavos = Centavos(max(categorias, 1))
        let porCategoriaIngreso: Centavos = ingresos / divisor
        let porCategoriaGasto: Centavos = gastos / divisor
        var comp: [CategoriaMonto] = []
        var gas: [CategoriaMonto] = []
        for i in 0..<categorias {
            comp.append(CategoriaMonto(nombre: "Categoría \(i + 1)",
                                       monto: porCategoriaIngreso))
            gas.append(CategoriaMonto(nombre: "Gasto \(i + 1)",
                                      monto: porCategoriaGasto))
        }
        let filas = (0..<meses).map {
            FilaMensual(clave: String(format: "2026-%02d", $0 + 1),
                        ingresos: ingresos, gastos: gastos, delta: $0 == 0 ? nil : 0.05)
        }
        let dep = (0..<depositos).map {
            DepositoBancario(id: "d\($0)", fecha: "2026-09-0\($0 + 1)",
                             periodo: "2026-09", monto: 100_00, cuenta: "Chase ··7730")
        }
        return EstadoFinanciero(
            periodo: PeriodoContable(clave: "2026-09"),
            ingresosMes: ingresos, gastosMes: gastos,
            deltaIngresos: nil, deltaGastos: nil, deltaBalance: nil,
            mesAnterior: nil, mesAnteriorNombre: nil,
            saldoAnterior: 0,
            saldoSerie: (0..<meses).map { MesAporte(mes: "M\($0)", monto: ingresos) },
            composicion: comp, gastosPorCategoria: gas,
            depositos: dep, pendientes: 0, mensual: filas)
    }

    private func aportante(conAportes n: Int) -> (Aportante, [Aporte]) {
        // Mismo cuidado que en `estado(_:)`: cada pieza a una variable con su
        // tipo. El literal con el subíndice del array, la aritmética de la
        // fecha y la del importe todo junto vuelve a agotar al compilador.
        let conceptos = ["Diezmo", "Ofrenda", "Misiones", "Construcción"]
        let inicio: TimeInterval = 1_767_225_600
        let unDia: TimeInterval = 86_400
        var aportes: [Aporte] = []
        aportes.reserveCapacity(n)
        for i in 0..<n {
            let concepto: String = conceptos[i % conceptos.count]
            let cuando = Date(timeIntervalSince1970: inicio + Double(i) * unDia)
            let importe: Centavos = 1_000 + Centavos(i % 50) * 137
            aportes.append(Aporte(id: "a\(i)", concepto: concepto,
                                  fecha: cuando, monto: importe))
        }
        let a = Aportante(
            id: "ap1", nombre: "Ana Lucía Torres Menchaca", estado: .activo,
            rol: "diezmo", miembroDesde: "2019", telefono: "81 1234 5678",
            correo: "ana@ejemplo.com", nacimiento: "1985-04-12",
            direccion: "Av. Constitución 1234, Monterrey", estadoCivil: "Casada",
            idFiscal: "TOMA850412ABC", congregaDesde: "2016",
            frecuencia: .semanal, aportes: aportes, familia: [])
        return (a, aportes)
    }

    // MARK: - Medir

    private struct Medida {
        let paginas: Int
        let bytes: Int
        let ms: Int
        /// El texto de cada página, para saber DÓNDE sale el membrete.
        let textoPorPagina: [String]
    }

    private func medir(_ nombre: String, _ render: () -> URL?) throws -> Medida {
        let t0 = Date()
        let url = render()
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        let u = try XCTUnwrap(url, "PDFExport devolvió nil para \(nombre)")
        let datos = try Data(contentsOf: u)
        try? datos.write(to: destino.appendingPathComponent("qa-limite-\(nombre).pdf"))
        let doc = try XCTUnwrap(PDFDocument(url: u), "PDFKit no pudo abrir \(nombre)")
        let textos = (0..<doc.pageCount).map { doc.page(at: $0)?.string ?? "" }
        print("QA-LIMITE:\(nombre):paginas=\(doc.pageCount):bytes=\(datos.count):ms=\(ms)")
        return Medida(paginas: doc.pageCount, bytes: datos.count, ms: ms,
                      textoPorPagina: textos)
    }

    // MARK: - 1 · Un mes sin un solo movimiento

    /// Lo primero que ve una iglesia que acaba de instalar la app y pide el
    /// reporte antes de registrar nada.
    func testElReporteDeUnMesSinMovimientos() throws {
        let m = try medir("reporte-mes-vacio") {
            PDFExport.render(
                ReporteHojaPDF(e: self.estado(ingresos: 0, gastos: 0,
                                              categorias: 0, meses: 0, depositos: 0),
                               iglesia: self.iglesiaCompleta()),
                nombre: "limite-mes-vacio")
        }
        XCTAssertGreaterThan(m.bytes, 1_000, "el PDF salió vacío de verdad")

        // **Medido: sale en DOS páginas, no en una.** `PDFExport` corta una
        // imagen alta por altura de carta, así que la pregunta no es cuántas
        // páginas hay sino si la segunda LLEVA ALGO: una hoja en blanco dentro
        // de un documento que se entrega es un descuido que se ve.
        for (i, t) in m.textoPorPagina.enumerated() {
            let limpio = t.trimmingCharacters(in: .whitespacesAndNewlines)
            print("QA-LIMITE-VACIO: página \(i + 1) · \(limpio.count) caracteres · " +
                  "«\(limpio.replacingOccurrences(of: "\n", with: " ").prefix(120))»")
        }
        let sobrantes = m.textoPorPagina.enumerated()
            .filter { $0.offset > 0 &&
                      $0.element.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 }
            .map { $0.offset + 1 }
        XCTAssertTrue(sobrantes.isEmpty, """
            El reporte de un mes SIN movimientos ocupa \(m.paginas) páginas y \
            las páginas \(sobrantes) están prácticamente en blanco. Es un \
            documento que se entrega e imprime: una hoja vacía al final se ve. \
            `PDFExport` pagina por ALTURA (`:55`), así que unos pocos puntos de \
            más en la vista cuestan una hoja entera.
            """)

        // **Que no prometa lo que no hay.** Mismo criterio que el rastro de
        // auditoría y que «Compactar base de datos»: un mes sin movimientos es
        // un mes sin movimientos, no un documento roto ni una plantilla a
        // medio rellenar.
        let t = m.textoPorPagina.joined()
        XCTAssertFalse(t.contains("{{"), """
            El reporte de un mes vacío imprime un hueco de plantilla sin \
            rellenar. Es el caso de la carta que imprimía \
            `{{miembro_nombre}}`, otra vez.
            """)
        XCTAssertTrue(t.contains("Iglesia Nueva Vida") || t.contains("Monterrey"),
                      "el membrete no salió: el documento no dice de quién es")
    }

    // MARK: - 2 · Quinientas filas

    /// El encargo pedía «500 movimientos: cuánto tarda, si parte la tabla, si el
    /// membrete se repite». Quien lista de verdad una fila por apunte es el
    /// reporte de aportes de una persona, no el estado financiero —ese lista
    /// CATEGORÍAS—, así que es ahí donde se mide.
    func testQuinientasFilasEnUnReporteDeAportes() throws {
        let (a, aportes) = aportante(conAportes: 500)
        let m = try medir("aportes-500") {
            PDFExport.render(
                ReporteAportesHojaPDF(aportante: a, aportes: aportes,
                                      periodoLegible: "2026",
                                      iglesia: self.iglesiaCompleta()),
                nombre: "limite-aportes-500")
        }

        XCTAssertGreaterThan(m.paginas, 1, """
            500 aportes caben en UNA página: o la tabla no los está listando \
            —y entonces el documento miente por omisión— o algo los recortó.
            """)
        // Cuánto tarda, con el número delante y sin umbral inventado: lo que
        // importa es que quede escrito para comparar la próxima vez.
        print("QA-LIMITE-TIEMPO: 500 aportes en \(m.ms) ms, \(m.paginas) páginas")

        // **El membrete NO se repite, y eso es lo que hay que decidir.**
        // `PDFExport` corta una imagen alta, así que la cabecera existe una vez.
        let nombre = "Iglesia Nueva Vida"
        let conMembrete = m.textoPorPagina.enumerated()
            .filter { $0.element.contains(nombre) }.map(\.offset)
        print("QA-LIMITE-MEMBRETE: páginas con membrete \(conMembrete) de \(m.paginas)")
        XCTAssertEqual(conMembrete, [0], """
            El membrete aparece en \(conMembrete.count) páginas de \(m.paginas). \
            Se esperaba solo en la primera, porque `PDFExport` corta una imagen \
            alta en vez de componer páginas. Si ahora se repite, `PDFExport` \
            cambió y esta prueba está describiendo otra cosa.
            """)

        // Y ninguna página en blanco: el corte por altura las puede dejar.
        let vacias = m.textoPorPagina.enumerated()
            .filter { $0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.offset)
        XCTAssertTrue(vacias.isEmpty, "páginas sin nada de texto: \(vacias)")
    }

    /// El reporte anual con los doce meses y muchas categorías, que es el otro
    /// documento que puede crecer.
    func testElReporteAnualConDoceMesesYVeinteCategorias() throws {
        let cats = (0..<20).map { CategoriaMonto(nombre: "Categoría \($0 + 1)", monto: 5_000) }
        let meses = (1...12).map {
            FilaMensual(clave: String(format: "2026-%02d", $0),
                        ingresos: 120_000, gastos: 80_000, delta: $0 == 1 ? nil : 0.03)
        }
        let m = try medir("anual-12x20") {
            PDFExport.render(
                ReporteAnualHojaPDF(a: ReporteAnual(anio: "2026", meses: meses,
                                                    ingresosPorCategoria: cats,
                                                    gastosPorCategoria: cats,
                                                    depositosTotal: 900_000,
                                                    pendientes: 0),
                                    iglesia: self.iglesiaCompleta()),
                nombre: "limite-anual")
        }
        XCTAssertGreaterThan(m.bytes, 1_000)
        XCTAssertFalse(m.textoPorPagina.joined().contains("{{"))
        print("QA-LIMITE-ANUAL: \(m.paginas) páginas, \(m.ms) ms")
    }

    // MARK: - 3 · Sin logo y sin firmas

    /// **El caso más común en una iglesia nueva**, y el que más fácil imprime
    /// un hueco: no hay logo, no hay firmas y no hay cargos configurados.
    func testSinLogoNiFirmasNoQuedanHuecos() throws {
        let desnuda = iglesiaDesnuda()

        // El membrete de una iglesia sin configurar tiene que ser VACÍO, no un
        // nombre inventado — está escrito así a propósito en
        // `ConfiguracionIglesia:161`: «un documento sin membrete es un
        // descuido, pero uno con el nombre de otra iglesia es un error».
        XCTAssertEqual(desnuda.membrete, "")

        let m = try medir("reporte-desnudo") {
            PDFExport.render(ReporteHojaPDF(e: self.estado(ingresos: 50_000, gastos: 20_000),
                                            iglesia: desnuda),
                             nombre: "limite-desnudo")
        }
        let t = m.textoPorPagina.joined()
        XCTAssertGreaterThan(m.bytes, 1_000, "no se generó nada")
        XCTAssertFalse(t.contains("{{"), "hueco de plantilla sin rellenar")
        // Ni el nombre de otra iglesia ni un ejemplo colado del código.
        for colado in ["Iglesia Nueva Vida", "Mi Iglesia", "ejemplo", "Ejemplo"] {
            XCTAssertFalse(t.contains(colado), """
                El reporte de una iglesia SIN configurar imprime «\(colado)», \
                que no es suyo. Es el caso de los diecisiete ejemplos que \
                asomaban con la app en inglés, en un documento que se entrega.
                """)
        }
        print("QA-LIMITE-DESNUDO: \(m.paginas) páginas, \(m.bytes) bytes")
    }

    /// Y la constancia sin configurar, que es el documento fiscal.
    func testLaConstanciaSinConfigurarNoInventaNada() throws {
        let (a, aportes) = aportante(conAportes: 24)
        let m = try medir("constancia-desnuda") {
            PDFExport.render(
                ConstanciaHojaPDF(aportante: a, aportes: aportes, anio: 2026,
                                  iglesia: self.iglesiaDesnuda()),
                nombre: "limite-constancia-desnuda")
        }
        let t = m.textoPorPagina.joined()
        XCTAssertGreaterThan(m.bytes, 1_000)
        XCTAssertFalse(t.contains("{{"), "hueco de plantilla en la constancia")
        XCTAssertTrue(t.contains("Ana Lucía Torres Menchaca"),
                      "la constancia no lleva el nombre de quien aportó")
        print("QA-LIMITE-CONSTANCIA: \(m.paginas) páginas, \(m.bytes) bytes")
    }
}
