import SwiftUI

/// **Las dos hojas del Registro de servicios, según `handoff7`.**
///
/// Van juntas porque son las dos caras de lo mismo: `NuevoCulto` anota que hubo
/// un culto —antes o después— y `TomarAsistencia` rellena lo que solo se sabe
/// estando allí. El handoff las separa por eso mismo, y las dos piden los tres
/// conteos: el culto los acepta al darlo de alta y la asistencia los corrige
/// después.
///
/// **El total nunca se pregunta**: es la suma de niños, jóvenes y adultos, y de
/// ahí salen todos los porcentajes de asistencia de la app. Pedirlo por
/// separado dejaría dos cifras libres de contradecirse.

// MARK: - Nuevo culto

struct NuevoCulto: View {

    let proximoId: String
    let alGuardar: (Servicio) -> Void

    @State private var fecha = Date()
    @State private var tipo = "dominical"
    @State private var dirige = ""
    @State private var predica = ""
    @State private var ninos = ""
    @State private var jovenes = ""
    @State private var adultos = ""
    @State private var tituloMensaje = ""
    @State private var textoBiblico = ""
    @State private var resumenMensaje = ""
    @State private var temaEscuela = ""
    @State private var maestroEscuela = ""
    @State private var visitantes: [String] = []
    @State private var intentoGuardar = false
    @State private var padron: [PersonaDelPadron] = []

    /// La fecha siempre trae valor, así que en la práctica nunca falta nada.
    /// Se deja declarado igual, con las palabras del handoff, porque el día que
    /// la fecha se pueda vaciar el aviso ya sabe qué decir.
    private var faltan: [String] { [] }

    var body: some View {
        HojaMac(titulo: L.t("Nuevo culto", "New service"),
                rotuloGuardar: L.t("Guardar", "Save"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            cuando
            quienDirigio
            asistencia
            mensaje
            escuela
            visitantesSeccion
        }
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
    }

    private var cuando: some View {
        SeccionHoja(titulo: L.t("CUÁNDO", "WHEN")) {
            FilaFecha(rotulo: L.t("Fecha", "Date"), valor: $fecha)
            // **Los diez tipos del catálogo, no los cinco del handoff.** Son
            // los que guarda la columna; recortarlos dejaría fuera cinco que el
            // web sí usa.
            FilaSelector(rotulo: L.t("Tipo de culto", "Service type"), valor: $tipo,
                         opciones: Cultos.tipos.map { ($0, Cultos.etiqueta($0)) })
        }
    }

    private var quienDirigio: some View {
        SeccionHoja(
            titulo: L.t("QUIÉN DIRIGIÓ", "WHO LED"),
            nota: L.t("Los puestos que se dejen vacíos salen como «Asignar encargado» en el roster, y el culto queda anotado con roster parcial.",
                      "Posts left empty show as “Assign person” in the roster, and the service is logged as a partial roster.")
        ) {
            FilaSelector(rotulo: L.t("Dirigió el culto · opcional", "Lead the service · optional"),
                         valor: $dirige, opciones: opcionesPadron(L.t("Nadie anotado", "Nobody logged")))
            FilaSelector(rotulo: L.t("Predicó · opcional", "Preached · optional"),
                         valor: $predica,
                         opciones: opcionesPadron(L.t("Nadie anotado", "Nobody logged"))
                            + [(L.t("Invitado", "Guest speaker"), L.t("Invitado", "Guest speaker"))])
        }
    }

    private func opcionesPadron(_ vacio: String) -> [(String, String)] {
        [("", vacio)] + padron.map { ($0.nombre, $0.nombre) }
    }

    private var asistencia: some View {
        SeccionHoja(
            titulo: L.t("ASISTENCIA", "ATTENDANCE"),
            nota: L.t("El total es la suma de los tres conteos — Tamio no lo pregunta dos veces. El porcentaje se calcula contra el padrón de esa fecha.",
                      "The total is the sum of the three counts — Tamio never asks for it twice. Attendance percentage is computed against the roster on that date.")
        ) {
            FilaNumero(rotulo: L.t("Niños", "Children"), valor: $ninos)
            FilaNumero(rotulo: L.t("Jóvenes", "Youth"), valor: $jovenes)
            FilaNumero(rotulo: L.t("Adultos", "Adults"), valor: $adultos)
        }
    }

    private var mensaje: some View {
        SeccionHoja(titulo: L.t("MENSAJE", "MESSAGE")) {
            FilaTexto(rotulo: L.t("Título del mensaje · opcional", "Message title · optional"),
                      valor: $tituloMensaje)
            FilaTexto(rotulo: L.t("Texto bíblico · opcional", "Main Bible text · optional"),
                      valor: $textoBiblico, marcador: L.t("p. ej. Salmo 121:1-8", "e.g. Psalm 121:1-8"))
            FilaArea(rotulo: L.t("Resumen del mensaje · opcional",
                                 "Short summary of the message · optional"),
                     valor: $resumenMensaje, lineas: 3...6)
        }
    }

    private var escuela: some View {
        SeccionHoja(titulo: L.t("ESCUELA DOMINICAL", "SUNDAY SCHOOL")) {
            FilaTexto(rotulo: L.t("Tema impartido · opcional", "Topic taught · optional"),
                      valor: $temaEscuela)
            FilaTexto(rotulo: L.t("Maestro de la clase · opcional", "Class teacher · optional"),
                      valor: $maestroEscuela)
        }
    }

    private var visitantesSeccion: some View {
        SeccionHoja(
            titulo: L.t("VISITANTES", "VISITORS"),
            nota: L.t("Un visitante sin ficha se guarda con el culto, no en el padrón. Darlo de alta es otro paso.",
                      "A visitor without a profile is saved with the service, not in the roster. Adding them to the registry is a separate step.")
        ) {
            FilaFichas(rotulo: L.t("Visitantes", "Visitors"), valores: $visitantes,
                       marcador: L.t("Añadir visitante", "Add visitor"))
        }
    }

    private func guardar() -> Bool {
        intentoGuardar = true
        var s = Servicio(id: proximoId)
        s.fecha = Fechas.claveDia(fecha)
        s.tipo = tipo
        s.dirige = dirige
        s.predica = predica
        s.ninos = Int(ninos) ?? 0
        s.jovenes = Int(jovenes) ?? 0
        s.adultos = Int(adultos) ?? 0
        s.tituloMensaje = tituloMensaje.trimmingCharacters(in: .whitespaces)
        s.textoBiblico = textoBiblico.trimmingCharacters(in: .whitespaces)
        s.resumenMensaje = resumenMensaje.trimmingCharacters(in: .whitespaces)
        s.temaEscuela = temaEscuela.trimmingCharacters(in: .whitespaces)
        s.maestroEscuela = maestroEscuela.trimmingCharacters(in: .whitespaces)
        s.visitantes = visitantes.map { VisitanteServicio(nombre: $0) }
        // **Los siete puestos nacen con el culto, vacíos.** Sin ellos el roster
        // no existe y la hoja de asistencia no tendría qué rellenar: son las
        // filas, no los datos.
        s.puestos = Puestos.habituales.map {
            PuestoServicio(id: UUID().uuidString, puesto: $0, nombre: "", miembroId: nil)
        }
        alGuardar(s)
        return true
    }
}

// MARK: - Tomar asistencia

/// **Tomar la lista de un culto que ya existe.**
///
/// Cambia tres cosas a la vez —los conteos, el roster y los visitantes— y por
/// eso guarda el culto entero en vez de ir campo por campo.
struct TomarAsistencia: View {

    let servicio: Servicio
    let alGuardar: (Servicio) -> Void

    @State private var ninos: String
    @State private var jovenes: String
    @State private var adultos: String
    /// Por clave de puesto, que es como el handoff nombra las siete filas.
    @State private var roster: [String: String]
    @State private var visitantes: [String]
    @State private var padron: [PersonaDelPadron] = []

    init(servicio: Servicio, alGuardar: @escaping (Servicio) -> Void) {
        self.servicio = servicio
        self.alGuardar = alGuardar
        _ninos = State(initialValue: servicio.ninos == 0 ? "" : String(servicio.ninos))
        _jovenes = State(initialValue: servicio.jovenes == 0 ? "" : String(servicio.jovenes))
        _adultos = State(initialValue: servicio.adultos == 0 ? "" : String(servicio.adultos))
        var r: [String: String] = [:]
        for p in servicio.puestos { r[p.puesto] = p.nombre }
        _roster = State(initialValue: r)
        _visitantes = State(initialValue: servicio.visitantes.map(\.nombre))
    }

    var body: some View {
        HojaMac(titulo: L.t("Tomar asistencia · \(servicio.titulo) · \(Fechas.diaLegible(servicio.fecha))",
                            "Take attendance · \(servicio.titulo) · \(Fechas.diaLegible(servicio.fecha))"),
                rotuloGuardar: L.t("Guardar el conteo", "Save the count"),
                faltan: [],
                intentoGuardar: false,
                alGuardar: guardar) {
            conteo
            rosterSeccion
            visitantesSeccion
        }
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
    }

    private var conteo: some View {
        SeccionHoja(
            titulo: L.t("CONTEO POR GRUPO", "COUNT BY GROUP"),
            nota: L.t("El total es la suma de los tres, y de él salen todas las cifras de asistencia de la app: el culto, los informes y el porcentaje de cada miembro.",
                      "The total is the sum of the three counts, and it feeds every attendance figure in the app: the service, the reports and each member’s percentage.")
        ) {
            FilaNumero(rotulo: L.t("Niños", "Children"), valor: $ninos)
            FilaNumero(rotulo: L.t("Jóvenes", "Youth"), valor: $jovenes)
            FilaNumero(rotulo: L.t("Adultos", "Adults"), valor: $adultos)
        }
    }

    private var rosterSeccion: some View {
        SeccionHoja(
            titulo: L.t("ROSTER", "ROSTER"),
            nota: L.t("Un puesto que se quede en «Asignar encargado» deja el culto anotado con roster parcial.",
                      "A post left as “Assign person” keeps the service logged as a partial roster.")
        ) {
            ForEach(Puestos.habituales, id: \.self) { clave in
                FilaSelector(rotulo: Puestos.etiqueta(clave),
                             valor: Binding(
                                get: { roster[clave] ?? "" },
                                set: { roster[clave] = $0 }),
                             opciones: [("", L.t("Asignar encargado", "Assign person"))]
                                + padron.map { ($0.nombre, $0.nombre) })
            }
        }
    }

    private var visitantesSeccion: some View {
        SeccionHoja(
            titulo: L.t("VISITANTES", "VISITORS"),
            nota: L.t("Un visitante se guarda con el culto, no en el padrón. Darlo de alta como miembro es otro paso.",
                      "A visitor is saved with the service, not in the registry. Adding them as a member is a separate step.")
        ) {
            FilaFichas(rotulo: L.t("Visitantes anotados en este culto",
                                   "Visitors logged in this service"),
                       valores: $visitantes,
                       marcador: L.t("Añadir visitante", "Add visitor"))
        }
    }

    private func guardar() -> Bool {
        var s = servicio
        s.ninos = Int(ninos) ?? 0
        s.jovenes = Int(jovenes) ?? 0
        s.adultos = Int(adultos) ?? 0
        s.puestos = s.puestos.map { p in
            var x = p
            x.nombre = (roster[p.puesto] ?? "").trimmingCharacters(in: .whitespaces)
            return x
        }
        s.visitantes = visitantes.map { VisitanteServicio(nombre: $0) }
        alGuardar(s)
        return true
    }
}
