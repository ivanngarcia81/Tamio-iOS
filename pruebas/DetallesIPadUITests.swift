import XCTest

/// **Los detalles que la pasada de pantallas no abrió**: la carta, el culto y
/// el día de la agenda. En iPad son la columna derecha, así que se recorren
/// desplazando ESA columna —un `swipeUp` en el centro cae en la lista.
final class DetallesIPad: HojasIPad {

    /// Desplaza la columna de detalle y fotografía.
    func bajar(_ nombre: String, _ veces: Int = 2) {
        for i in 1...veces {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.8))
               .press(forDuration: 0.1,
                      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.25)))
            sleep(1)
            revisar("\(nombre)-\(i)")
        }
    }

    func testDetalleDeCarta() {
        seccion("Letters")
        sleep(3)
        revisar("D-01-carta-plantilla")
        bajar("D-02-carta-plantilla")
        // Una carta ya emitida: la sección "Issued this month" de la columna.
        if tocaTexto("Transfer letter") || tocaTexto("Membership certificate") {
            revisar("D-03-carta-emitida")
            bajar("D-04-carta-emitida", 1)
        } else {
            print("### COLUMNA: " + app.staticTexts.allElementsBoundByIndex.prefix(30)
                  .filter { $0.frame.minX < 600 && !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        }
    }

    func testDetalleDeCulto() {
        seccion("Service log")
        revisar("D-05-culto")
        bajar("D-06-culto", 3)
        // El segundo culto de la lista, que es de otro tipo.
        if tocaTexto("Prayer meeting") { revisar("D-07-culto-oracion") }
    }

    func testDetalleDeDia() {
        seccion("Calendar")
        revisar("D-08-agenda-mes")
        // Un día con actividades: los puntos de color están en la rejilla.
        for dia in ["21", "23", "26"] {
            if tocaTexto(dia) {
                revisar("D-09-dia-\(dia)")
                break
            }
        }
        bajar("D-10-dia", 1)
        // Y la vista de semana y de lista, con su detalle.
        if toca("Week") { revisar("D-11-semana") }
        if toca("List") { revisar("D-12-lista") }
    }
}
