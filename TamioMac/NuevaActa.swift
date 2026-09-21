import SwiftUI

/// **El alta de un acta, según `handoff7`.**
///
/// Seis secciones en el orden del handoff: MEETING, TIME, QUIÉN FIRMA,
/// ASISTENCIA, CONTENIDO y ESTADO. La forma la pone `HojaMac`.
///
/// Esta hoja ya se había escrito dos veces: la primera contra el vacío —no
/// había ninguna dibujada hasta el quinto handoff—, y la segunda se quedó corta
/// porque el quinto pedía menos campos de los que guarda la tabla `acta`. El
/// séptimo los trae todos, así que **esta versión ya no añade nada por su
/// cuenta**: lo que pide el handoff y lo que guarda la columna coinciden.
///
/// Dos cosas que el handoff resolvió y conviene no volver a discutir:
///
/// - **Los once tipos y los siete estados son los del web** (`TipoActa`,
///   `EstadoActa`). Recortarlos a cuatro y a tres, como hacía el quinto, sería
///   repetir el fallo del `estado` traducido que se arregló esa misma mañana.
/// - **El número de asistentes no se teclea**: se cuenta de las tres listas, y
///   por eso el acta y el padrón no pueden contradecirse.
///
/// Las reglas de qué se guarda salen de `NuevaActaSheet` de iOS.
struct NuevaActa: View {

    let proximoId: String
    /// Cuántas actas hay ya, para que dos borradores sin subir no lleven el
    /// mismo provisional. **No es el folio**: el bueno lo da el servidor.
    let proximoNumeroProvisional: Int
    let alGuardar: (Acta) -> Void

    // MEETING
    @State private var titulo = ""
    @State private var tipo = TipoActa.lideres
    @State private var fecha = Date()
    @State private var lugar = ""

    // TIME. **Texto y no `DatePicker`**, como el handoff: la columna es
    // `"HH:mm"` y un selector de hora obliga a formatear de ida y de vuelta
    // para un dato que se teclea en cuatro pulsaciones.
    @State private var tieneInicio = false
    @State private var horaInicio = ""
    @State private var tieneCierre = false
    @State private var horaCierre = ""

    // QUIÉN FIRMA
    @State private var preside = ""
    @State private var secretario = ""
    @State private var testigo = ""

    // ASISTENCIA
    @State private var presentes: [String] = []
    @State private var ausentes: [String] = []
    @State private var invitados: [String] = []
    @State private var quorum = false

    // CONTENIDO
    @State private var agenda = ""
    @State private var resumen = ""
    @State private var mociones: [String] = []
    @State private var acuerdos: [String] = []

    // ESTADO
    @State private var estado = EstadoActa.borrador
    @State private var confidencial = false

    @State private var intentoGuardar = false
    /// El padrón, para los tres selectores de quién firma. Se pide una vez al
    /// abrir; si está vacío, los selectores se quedan con "Elegir…" y el nombre
    /// se puede escribir igual desde el web.
    @State private var padron: [PersonaDelPadron] = []

    /// Los dos obligatorios, con las palabras del handoff: `req:'a title'` y
    /// `req:'the date of the meeting'`. La fecha siempre tiene valor, así que
    /// en la práctica solo puede faltar el título.
    private var faltan: [String] {
        titulo.trimmingCharacters(in: .whitespaces).isEmpty
            ? [L.t("un título", "a title")] : []
    }

    var body: some View {
        HojaMac(titulo: L.t("Nueva acta", "New minutes entry"),
                rotuloGuardar: L.t("Guardar", "Save"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            reunion
            horario
            quienFirma
            asistencia
            contenido
            estadoSeccion
        }
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
    }

    // MARK: - Las secciones

    private var reunion: some View {
        SeccionHoja(titulo: L.t("REUNIÓN", "MEETING")) {
            FilaTexto(rotulo: L.t("Título", "Title"), valor: $titulo,
                      marcador: L.t("p. ej. Techo y presupuesto de misiones",
                                    "e.g. Roof repair and missions budget"))
            FilaSelector(rotulo: L.t("Tipo", "Type"), valor: $tipo,
                         opciones: TipoActa.allCases.map { ($0, $0.etiqueta) })
            FilaFecha(rotulo: L.t("Fecha", "Date"), valor: $fecha)
            FilaTexto(rotulo: L.t("Lugar", "Place"), valor: $lugar,
                      marcador: L.t("p. ej. Salón principal", "e.g. Main hall"))
        }
    }

    private var horario: some View {
        SeccionHoja(
            titulo: L.t("HORARIO", "TIME"),
            nota: L.t("Las dos horas son opcionales: un acta escrita días después rara vez las tiene, y una hora inventada es peor que ninguna.",
                      "Both times are optional: minutes written days later rarely have them, and an invented time is worse than none.")
        ) {
            FilaInterruptor(rotulo: L.t("Anotar la hora de inicio", "Log the start time"),
                            activo: $tieneInicio)
            if tieneInicio {
                FilaTexto(rotulo: L.t("Empezó a las", "Started at"),
                          valor: $horaInicio, marcador: "19:00")
            }
            FilaInterruptor(rotulo: L.t("Anotar la hora de cierre", "Log the closing time"),
                            activo: $tieneCierre)
            if tieneCierre {
                FilaTexto(rotulo: L.t("Cerró a las", "Closed at"),
                          valor: $horaCierre, marcador: "20:30")
            }
        }
    }

    private var quienFirma: some View {
        SeccionHoja(
            titulo: L.t("QUIÉN PRESIDE Y QUIÉN FIRMA", "CHAIR AND WITNESSES"),
            nota: L.t("Estos tres son los roles que firman el acta: quien preside, quien la levanta y el testigo.",
                      "These three are the roles that sign the minutes (chair, secretary, witness).")
        ) {
            FilaSelector(rotulo: L.t("Preside", "Chaired by"), valor: $preside,
                         opciones: opcionesPadron(vacio: L.t("Elegir…", "Choose…")))
            FilaSelector(rotulo: L.t("Levanta el acta", "Minuted by"), valor: $secretario,
                         opciones: opcionesPadron(vacio: L.t("Elegir…", "Choose…")))
            FilaSelector(rotulo: L.t("Testigo · opcional", "Witness · optional"),
                         valor: $testigo,
                         opciones: opcionesPadron(vacio: L.t("Nadie", "Nobody")))
        }
    }

    /// **Los nombres del padrón, y se guardan como texto.** La columna es texto
    /// libre —el web deja escribir a quien no tiene ficha—, así que el selector
    /// ayuda a no escribirlo mal pero no obliga: lo elegido se guarda tal cual.
    private func opcionesPadron(vacio: String) -> [(String, String)] {
        [("", vacio)] + padron.map { ($0.nombre, $0.nombre) }
    }

    private var asistencia: some View {
        SeccionHoja(
            titulo: L.t("ASISTENCIA", "ATTENDANCE"),
            nota: L.t("El número de asistentes no se teclea: se cuenta de estas listas, así que el acta y el padrón no pueden contradecirse.",
                      "The number of attendees is not typed: it is counted from these lists, so the minutes and the register can never disagree.")
        ) {
            FilaFichas(rotulo: L.t("Presentes", "Present"), valores: $presentes,
                       marcador: L.t("Añadir a alguien presente", "Add someone present"))
            FilaFichas(rotulo: L.t("Ausentes", "Absent"), valores: $ausentes,
                       marcador: L.t("Añadir a alguien ausente", "Add someone absent"))
            FilaFichas(rotulo: L.t("Invitados", "Guests"), valores: $invitados,
                       marcador: L.t("Añadir un invitado", "Add a guest"))
            FilaInterruptor(rotulo: L.t("Hubo quórum", "There was a quorum"), activo: $quorum)
        }
    }

    private var contenido: some View {
        SeccionHoja(titulo: L.t("CONTENIDO", "CONTENT")) {
            FilaArea(rotulo: L.t("Agenda", "Agenda"), valor: $agenda,
                     marcador: L.t("Un punto por línea", "One point per line"))
            FilaArea(rotulo: L.t("Resumen", "Summary"), valor: $resumen)
            FilaFichas(rotulo: L.t("Mociones", "Motions"), valores: $mociones,
                       marcador: L.t("Añadir una moción", "Add a motion"))
            // **Los acuerdos se numeran al guardar, por su orden**: "Acuerdo 1"
            // es el primero de esta lista, y por eso importa en qué orden se
            // escriben.
            FilaFichas(rotulo: L.t("Acuerdos", "Resolutions"), valores: $acuerdos,
                       marcador: L.t("Añadir un acuerdo", "Add a resolution"))
        }
    }

    private var estadoSeccion: some View {
        SeccionHoja(
            titulo: L.t("ESTADO", "STATUS"),
            nota: L.t("Un acta nace como borrador y solo pasa a firmada cuando los roles de arriba han firmado de verdad.",
                      "Minutes are born as a draft and only become signed once the roles above have actually signed.")
        ) {
            FilaSelector(rotulo: L.t("Estado", "Status"), valor: $estado,
                         opciones: EstadoActa.allCases.map { ($0, $0.etiqueta) })
            FilaInterruptor(rotulo: L.t("Confidencial", "Confidential"),
                            sub: L.t("Se lista, pero su contenido solo lo abren el pastor y la secretaria.",
                                     "It is listed, but its body is only opened by the pastor and the secretary."),
                            activo: $confidencial)
        }
    }

    // MARK: - Guardar

    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        alGuardar(construir())
        return true
    }

    /// **El folio es PROVISIONAL.** El bueno lo entrega el contador del
    /// servidor al subir; hasta entonces se enseña con "P-", como el de un
    /// movimiento sin subir, y por eso no se imprime. Verificado el 21-sep: se
    /// manda `P-4` y la fila vuelve como `ACTA-2026-006`.
    private func construir() -> Acta {
        var a = Acta(
            id: proximoId,
            folio: FolioCarta.provisional(seq: proximoNumeroProvisional),
            tipo: tipo,
            fecha: Fechas.claveDia(fecha),
            estado: estado,
            items: acuerdos.enumerated().map { AcuerdoActa(id: $0.offset + 1, texto: $0.element) },
            tituloPersonalizado: titulo.trimmingCharacters(in: .whitespaces),
            lugar: lugar.trimmingCharacters(in: .whitespaces),
            horaInicio: tieneInicio ? horaInicio.trimmingCharacters(in: .whitespaces) : nil,
            horaCierre: tieneCierre ? horaCierre.trimmingCharacters(in: .whitespaces) : nil,
            preside: preside,
            secretario: secretario,
            presentes: presentes,
            ausentes: ausentes,
            invitados: invitados,
            quorum: quorum,
            agenda: agenda.trimmingCharacters(in: .whitespaces),
            resumen: resumen.trimmingCharacters(in: .whitespaces),
            mociones: mociones,
            confidencial: confidencial
        )
        a.testigo = testigo
        return a
    }
}
