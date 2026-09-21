import SwiftUI

/// **El alta de una actividad de la Agenda, según `handoff7`.**
///
/// Cuatro secciones en el orden del handoff: QUÉ ES, CUÁNDO, DÓNDE Y QUIÉN, y
/// DETALLE. La forma la pone `HojaMac`.
///
/// Fue la primera hoja que se escribió para el Mac, el 21 de septiembre, cuando
/// **no había ninguna dibujada**; de aquella versión no queda la forma, pero sí
/// las dos reglas que costaron una vuelta y siguen valiendo:
///
/// - **La fecha entera en clave local.** Guardar solo el número del día haría
///   un evento que vale para el 21 de cualquier mes de cualquier año.
/// - **`responsable` y `responsableId` son EXCLUYENTES**, como en el web: con
///   id, el texto va vacío. Guardar los dos deja dos verdades que se separan en
///   cuanto esa persona cambie de apellido.
///
/// **Dos campos del handoff no están, y es a propósito**: la repetición y el
/// presupuesto **no tienen dónde guardarse** —el JSON de `recurrencia` es del
/// web y aquí no se conocen sus claves; `presupuesto` no tiene columna—.
/// Preguntar por algo que se pierde al guardar es peor que no preguntarlo, y
/// escribir claves a ojo sería repetir el fallo del `estado` traducido. Los dos
/// están anotados en `aFila` de `AgendaRepository`.
struct NuevaActividad: View {

    let mesActual: Date
    let diaInicial: Int
    let proximoId: String
    let alGuardar: (EventoAgenda) -> Void

    // QUÉ ES
    @State private var titulo = ""
    @State private var tipo: TipoEvento = .culto
    @State private var tipoPersonalizado = ""

    // CUÁNDO
    @State private var fecha: Date
    @State private var todoDia = false
    @State private var horaInicio = ""
    @State private var horaFin = ""

    // DÓNDE Y QUIÉN
    @State private var lugar = ""
    @State private var responsableId = ""
    @State private var ministerio = ""
    @State private var invitado = ""
    @State private var contacto = ""

    // DETALLE
    @State private var descripcion = ""
    @State private var recordatorios: [String] = []
    @State private var esFechaImportante = false
    @State private var estado = "programada"

    @State private var intentoGuardar = false
    @State private var padron: [PersonaDelPadron] = []

    init(mesActual: Date, diaInicial: Int, proximoId: String,
         alGuardar: @escaping (EventoAgenda) -> Void) {
        self.mesActual = mesActual
        self.diaInicial = diaInicial
        self.proximoId = proximoId
        self.alGuardar = alGuardar
        // **Nace en el día que está elegido en la rejilla**, que es el que la
        // persona tiene delante. Abrirla en "hoy" obligaría a corregir la fecha
        // en el caso normal, que es apuntar algo en el día que se está mirando.
        var comps = Calendar.current.dateComponents([.year, .month], from: mesActual)
        comps.day = diaInicial
        _fecha = State(initialValue: Calendar.current.date(from: comps) ?? Date())
    }

    /// Con las palabras del handoff: `req:'a title'` y `req:'the date'`. La
    /// fecha siempre trae valor, así que solo puede faltar el título.
    private var faltan: [String] {
        titulo.trimmingCharacters(in: .whitespaces).isEmpty
            ? [L.t("un título", "a title")] : []
    }

    var body: some View {
        HojaMac(titulo: L.t("Nueva actividad", "New event"),
                rotuloGuardar: L.t("Guardar", "Save"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            queEs
            cuando
            dondeYQuien
            detalle
        }
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
    }

    // MARK: - Las secciones

    private var queEs: some View {
        SeccionHoja(titulo: L.t("ACTIVIDAD", "EVENT")) {
            FilaTexto(rotulo: L.t("Título", "Title"), valor: $titulo)
            FilaSelector(rotulo: L.t("Tipo", "Type"), valor: $tipo,
                         opciones: TipoEvento.allCases.map { ($0, $0.titulo) })
            // **Solo cuenta con el tipo "Otra".** La columna `tipo` del web
            // guarda "otra" y el nombre propio va aparte; escrito con otro tipo
            // elegido, no se leería en ninguna parte.
            if tipo == .otro {
                FilaTexto(rotulo: L.t("Tipo propio", "Custom type"),
                          valor: $tipoPersonalizado,
                          marcador: L.t("Solo cuando el tipo es «Otra»",
                                        "Only when the type is Other"))
            }
        }
    }

    private var cuando: some View {
        SeccionHoja(titulo: L.t("CUÁNDO", "WHEN")) {
            FilaFecha(rotulo: L.t("Fecha", "Date"), valor: $fecha)
            FilaInterruptor(rotulo: L.t("Todo el día", "All day"), activo: $todoDia)
            if !todoDia {
                FilaTexto(rotulo: L.t("Empieza", "Starts"), valor: $horaInicio,
                          marcador: "19:00")
                FilaTexto(rotulo: L.t("Termina", "Ends"), valor: $horaFin,
                          marcador: "21:00")
            }
        }
    }

    private var dondeYQuien: some View {
        SeccionHoja(titulo: L.t("DÓNDE Y QUIÉN", "WHERE AND WHO")) {
            FilaTexto(rotulo: L.t("Lugar", "Place"), valor: $lugar)
            FilaSelector(rotulo: L.t("A cargo", "In charge"), valor: $responsableId,
                         opciones: [("", L.t("Nadie todavía", "Nobody yet"))]
                            + padron.map { ($0.id, $0.nombre) })
            FilaSelector(rotulo: L.t("Ministerio", "Ministry"), valor: $ministerio,
                         opciones: [("", L.t("Ninguno", "None"))]
                            + Padron.ministerios.map { ($0, Padron.etiqueta($0)) })
            FilaTexto(rotulo: L.t("Invitado", "Guest"), valor: $invitado,
                      marcador: L.t("Un orador o una iglesia que visita",
                                    "A speaker or a visiting church"))
            FilaTexto(rotulo: L.t("Contacto", "Contact"), valor: $contacto,
                      marcador: L.t("Teléfono o correo del invitado",
                                    "Phone or email of the guest"))
        }
    }

    private var detalle: some View {
        SeccionHoja(
            titulo: L.t("DETALLE", "DETAIL"),
            nota: L.t("Una fecha importante sale en el calendario y en los recordatorios de todos los que tienen acceso a Secretaría.",
                      "An important date shows on the calendar and in the reminders of everyone with access to Secretary.")
        ) {
            FilaArea(rotulo: L.t("Descripción", "Description"), valor: $descripcion)
            FilaFichas(rotulo: L.t("Recordatorios", "Reminders"), valores: $recordatorios,
                       marcador: L.t("Añadir un recordatorio", "Add a reminder"))
            FilaInterruptor(rotulo: L.t("Fecha importante", "Important date"),
                            activo: $esFechaImportante)
            // Las claves son las del web, no los rótulos: es la lección del
            // `estado` traducido de esta misma mañana.
            FilaSelector(rotulo: L.t("Estado", "Status"), valor: $estado,
                         opciones: [
                            ("borrador",   L.t("Borrador", "Draft")),
                            ("programada", L.t("Programada", "Scheduled")),
                            ("confirmada", L.t("Confirmada", "Confirmed")),
                            ("completada", L.t("Completada", "Done")),
                            ("cancelada",  L.t("Cancelada", "Cancelled"))
                         ])
        }
    }

    // MARK: - Guardar

    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        alGuardar(construir())
        return true
    }

    private func construir() -> EventoAgenda {
        let elegido = padron.first { $0.id == responsableId }
        var e = EventoAgenda(
            id: proximoId,
            // **La fecha entera en clave local**, no el número del día.
            fecha: Fechas.claveDia(fecha),
            hora: todoDia ? nil : horaInicio.trimmingCharacters(in: .whitespaces),
            titulo: titulo.trimmingCharacters(in: .whitespaces),
            descripcion: descripcion.trimmingCharacters(in: .whitespaces),
            tipo: tipo,
            completado: estado == "completada" || estado == "cancelada",
            todoDia: todoDia,
            horaFin: todoDia ? nil : horaFin.trimmingCharacters(in: .whitespaces),
            lugar: lugar.trimmingCharacters(in: .whitespaces),
            // Excluyentes: con id, el texto va vacío.
            responsable: elegido == nil ? "" : elegido!.nombre,
            responsableId: elegido?.id,
            ministerio: ministerio,
            estadoEvento: estado,
            esFechaImportante: esFechaImportante,
            recordatorios: recordatorios
        )
        e.tipoPersonalizado = tipo == .otro
            ? tipoPersonalizado.trimmingCharacters(in: .whitespaces) : ""
        e.invitado = invitado.trimmingCharacters(in: .whitespaces)
        e.contacto = contacto.trimmingCharacters(in: .whitespaces)
        return e
    }
}
