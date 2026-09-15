import XCTest
@testable import Tamio

/// **La otra mitad del hallazgo nº 1: el día de calendario que retrocede.**
///
/// `FechaSoloFechaTests` ya fija el CONTRATO —`diaDeCalendario` y `claveDia`
/// son inversos—. Lo que faltaba no era el contrato: era que los sitios que
/// leen un día de calendario pasaran por él. Estaba escrito desde el 10-sep y
/// **solo lo usaba `Miembro.swift:475`**.
///
/// **El inventario del informe mezclaba tres cosas**, y por eso esta prueba no
/// persigue los trece sitios que listaba. La firma del defecto es UNA: parsear
/// en UTC y volver a EMITIR en local. Quien parsea en UTC y formatea fijando
/// UTC —`Secretaria.fechaLegible` (:200), `Secretaria.cuerpo` (:212),
/// `Secretaria.dia` (:896) y `AgendaRepository` (:106), que además ya se
/// corrige a mano— es correcto a propósito y cambiarlo lo rompería.
///
/// **Aviso de instrumento, y es el que da valor a este archivo.** La primera
/// versión de estas pruebas llamaba a `Fechas.diaDeCalendario` directamente
/// para comprobar los arreglos. Pasaba en verde… **y también pasaba con los
/// arreglos revertidos**, porque medía la función que ya era correcta y no los
/// sitios que la ignoraban. Se comprobó revirtiendo: 5 de 5 en verde sin el
/// arreglo. Una prueba de un arreglo tiene que llamar al OBJETO del arreglo.
///
/// **Qué queda sin prueba de sitio, y por qué.** De los tres arreglos, solo el
/// importador es alcanzable desde aquí:
///
/// - `MembresiaView:1010-1021, 1261` es el `init` de una vista SwiftUI y sus
///   valores iniciales de `@State` no se leen desde fuera. Lo cubre la vuelta
///   completa a mano en la ficha (abrir, guardar, reabrir ×3).
/// - `ServiciosRepository:385` vive dentro de `resumen(desde:hasta:)`, que es
///   `async` y baja los cultos de la base. Se comprueba mirando la gráfica de
///   asistencia con datos sembrados.
///
/// Fuera de todo esto queda `MotorSincronizacion:2843`, la fecha del
/// movimiento: esa no la arregla el iOS solo, porque las 38 filas torcidas las
/// escribió la app web y la convención se acuerda en
/// `docs/ACUERDO-CON-EL-WEB.md`.
final class DiaDeCalendarioEnSusSitiosTests: XCTestCase {

    /// El control positivo. Sin él una prueba verde no dice nada: en UTC este
    /// fallo NO se reproduce y todo lo de abajo pasaría solo.
    func testControlLaZonaDelAparatoNoEsUTC() throws {
        let offset = TimeZone.current.secondsFromGMT()
        NSLog("[QA-DIACAL] zona %@ offset %d", TimeZone.current.identifier, offset)
        try XCTSkipIf(offset == 0, "el aparato está en UTC: aquí no se reproduce")
        XCTAssertLessThan(offset, 0, "la iglesia está al oeste de Greenwich")
    }

    // MARK: - El importador de aportes · el sitio de verdad

    private func aportante(_ aportes: [Aporte]) -> Aportante {
        Aportante(id: "a1", nombre: "María", estado: .activo, rol: "diezmo",
                  miembroDesde: "2018", telefono: "", correo: "", nacimiento: "",
                  direccion: "", estadoCivil: "", idFiscal: "", congregaDesde: "2016",
                  frecuencia: .mensual, aportes: aportes, familia: [])
    }

    private func documento(fecha: String) -> CSVLector.Documento {
        CSVLector.Documento(encabezados: ["fecha", "monto", "aportante_nombre", "concepto"],
                            filas: [[fecha, "100.00", "María", "Diezmo"]])
    }

    /// **`ImportadorAportes:117` · la previa enseñaba el día anterior.**
    ///
    /// La fila analizada lleva `fecha: Fechas.corta(fecha)`, y `corta` formatea
    /// en la zona del aparato. Con el parseo viejo —medianoche UTC— un aporte
    /// del 27 se le enseñaba al usuario como 26 justo en la pantalla que sirve
    /// para decidir si el archivo está bien antes de importarlo.
    func testLaPreviaDelImportadorNoRetrocedeUnDia() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se reproduce")

        let a = try ImportadorAportes.analizar(documento(fecha: "2026-07-27"),
                                               existentes: [aportante([])])
        let fila = try XCTUnwrap(a.filas.first)
        NSLog("[QA-DIACAL] previa → %@", fila.fecha)

        XCTAssertTrue(fila.fecha.contains("27"),
                      "### la previa enseña «\(fila.fecha)» para un aporte del 27")
    }

    /// **Y lo caro: la huella de duplicados se calculaba sobre otro día.**
    ///
    /// `huella` usa `CSV.fecha`, que tampoco fija zona. Así que el mismo aporte
    /// ya guardado y el que viene del archivo caían en huellas distintas, el
    /// duplicado entraba como nuevo y el importe se contaba dos veces. Es
    /// dinero de la congregación, y acaba en una constancia que se firma.
    func testUnAporteYaRegistradoSeDetectaComoDuplicado() throws {
        try XCTSkipIf(TimeZone.current.secondsFromGMT() == 0, "en UTC no se reproduce")

        // El aporte ya guardado nace por el camino BUENO, que es como lo
        // escribe hoy la app: un día de calendario.
        let yaGuardado = Aporte(id: "ap1", concepto: "Diezmo",
                                fecha: try XCTUnwrap(Fechas.diaDeCalendario("2026-07-27")),
                                monto: 100_00)
        let a = try ImportadorAportes.analizar(documento(fecha: "2026-07-27"),
                                               existentes: [aportante([yaGuardado])])
        let fila = try XCTUnwrap(a.filas.first)

        NSLog("[QA-DIACAL] duplicados %d · nuevos %d", a.duplicados, a.nuevos)
        guard case .duplicado = fila.destino else {
            return XCTFail("### el mismo aporte entra como nuevo: el importe se cuenta dos veces")
        }
        XCTAssertEqual(a.nuevos, 0)
    }

    // MARK: - La raya que no hay que cruzar al arreglar esto

    /// `diaDeCalendario` solo se desvía para la forma canónica `yyyy-MM-dd`;
    /// cualquier cosa con hora es un INSTANTE y sigue por el camino de siempre.
    /// Si alguien "simplifica" mandándolo todo por aquí, los movimientos —que
    /// sí llevan hora— empezarían a mentir en la otra dirección, que es
    /// exactamente el error que cometió la v1 del encargo.
    func testUnaFechaConHoraSigueSiendoUnInstante() throws {
        let conHora = "2026-07-12 02:28"
        let porDia = try XCTUnwrap(Fechas.diaDeCalendario(conHora))
        let porInstante = try XCTUnwrap(Fechas.desdeTexto(conHora))
        XCTAssertEqual(porDia, porInstante,
                       "### diaDeCalendario se está comiendo la hora de un instante")

        // Y la hora sigue llegando entera, que es la mitad que se arregló el
        // 14-sep: si esto se cae, volvió el `.withFullDate` a casar primero.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: porInstante).minute, 28,
                       "### la hora se perdió otra vez al leer la forma del web")
    }
}
