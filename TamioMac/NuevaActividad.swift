import SwiftUI

/// **El alta de una actividad de la Agenda, en el Mac.**
///
/// Es la PRIMERA pantalla del Mac que escribe algo fuera de la captura rápida,
/// y por eso fija el patrón que van a seguir las otras trece que faltan en
/// Secretaría: una hoja con las casillas en dos columnas, el foco puesto donde
/// se empieza a teclear, ⌘S para guardar y Escape para salir.
///
/// **Hoja y no ventana, al revés que la captura rápida.** Aquella es ventana
/// porque se deja abierta mientras se mira la lista de atrás —se capturan
/// ochenta sobres seguidos—; una actividad se da de alta de una en una y
/// cuelga del día que está elegido en la rejilla, así que separarla de esa
/// rejilla sería perder de vista a qué día se está apuntando.
///
/// Las reglas de qué se guarda NO se inventan aquí: salen de leer
/// `NuevoEventoSheet.guardar()` de iOS, que es el único sitio donde estaban
/// escritas. Las dos que cuestan una vuelta van comentadas donde se aplican.
struct NuevaActividad: View {

    let mesActual: Date
    let diaInicial: Int
    let proximoId: String
    let alGuardar: (EventoAgenda) -> Void

    @Environment(\.dismiss) private var cerrar

    @State private var titulo = ""
    @State private var tipo: TipoEvento = .culto
    @State private var fecha: Date
    @State private var todoDia = false
    @State private var horaInicio = Date()
    @State private var horaFin = Date()
    @State private var lugar = ""
    /// Lo que lleva el selector es un id del padrón, `""` o `"__ext__"`.
    @State private var responsable = ""
    @State private var ministerio = ""
    @State private var presupuesto = ""
    @State private var notaPie = ""
    @State private var descripcion = ""
    @State private var repeticion = ""
    @State private var estadoEvento = ""
    @State private var esFechaImportante = false
    @State private var recordatorios: Set<String> = []
    @State private var intentoGuardar = false
    /// **El padrón de verdad, no una lista escrita a mano.** `padronParaSelector`
    /// es de donde lo sacan también Servicios y Cartas: tres listas distintas
    /// escritas a mano es como aparecieron tres juegos de nombres que no
    /// coincidían entre sí.
    @State private var padron: [PersonaDelPadron] = []

    @FocusState private var foco: Casilla?
    private enum Casilla { case titulo, lugar, ministerio, presupuesto, descripcion, nota }

    private static let fmtHora: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private let repeticiones = [
        L.t("No se repite", "No repeat"),
        L.t("Semanal", "Weekly"),
        L.t("Cada dos semanas", "Every two weeks"),
        L.t("Mensual", "Monthly"),
        L.t("Anual", "Yearly"),
        L.t("Personalizado", "Custom")
    ]
    private let estados = [
        L.t("Programado", "Scheduled"),
        L.t("Confirmado", "Confirmed"),
        L.t("Cancelado", "Cancelled"),
        L.t("Completado", "Completed")
    ]
    private let avisos = [
        L.t("Mismo día", "Same day"),
        L.t("Un día antes", "One day before"),
        L.t("Dos días antes", "Two days before"),
        L.t("Una semana antes", "One week before")
    ]

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

    /// Lo único obligatorio, igual que en iOS: sin título la actividad no se
    /// puede reconocer en la rejilla, que es donde va a vivir.
    private var puedeGuardar: Bool {
        !titulo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("Nueva actividad", "New activity"))
                .font(.system(size: 15, weight: .semibold))

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 11) {
                GridRow {
                    campo(L.t("Título", "Title")) {
                        TextField("", text: $titulo,
                                  prompt: Text(L.t("Qué es", "What it is")))
                            .textFieldStyle(.roundedBorder)
                            .focused($foco, equals: .titulo)
                    }
                    .gridCellColumns(2)
                }
                GridRow {
                    campo(L.t("Tipo", "Type")) {
                        Picker("", selection: $tipo) {
                            ForEach(TipoEvento.allCases, id: \.self) { t in
                                Text(t.titulo).tag(t)
                            }
                        }
                        .labelsHidden()
                    }
                    campo(L.t("Fecha", "Date")) {
                        DatePicker("", selection: $fecha, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                GridRow {
                    Toggle(L.t("Todo el día", "All day"), isOn: $todoDia)
                        .gridCellColumns(2)
                }
                if !todoDia {
                    GridRow {
                        campo(L.t("Empieza", "Starts")) {
                            DatePicker("", selection: $horaInicio,
                                       displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        campo(L.t("Termina", "Ends")) {
                            DatePicker("", selection: $horaFin,
                                       displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                GridRow {
                    campo(L.t("Lugar", "Place")) {
                        TextField("", text: $lugar,
                                  prompt: Text(L.t("Opcional", "Optional")))
                            .textFieldStyle(.roundedBorder)
                            .focused($foco, equals: .lugar)
                    }
                    campo(L.t("Responsable", "In charge")) {
                        Picker("", selection: $responsable) {
                            Text(L.t("Sin asignar", "Unassigned")).tag("")
                            ForEach(padron) { p in Text(p.nombre).tag(p.id) }
                            Divider()
                            Text(L.t("Otra persona", "Other person")).tag("__ext__")
                        }
                        .labelsHidden()
                    }
                }
                GridRow {
                    campo(L.t("Ministerio", "Ministry")) {
                        TextField("", text: $ministerio,
                                  prompt: Text(L.t("Opcional", "Optional")))
                            .textFieldStyle(.roundedBorder)
                            .focused($foco, equals: .ministerio)
                    }
                    campo(L.t("Presupuesto", "Budget")) {
                        TextField("", text: $presupuesto,
                                  prompt: Text(L.t("Opcional", "Optional")))
                            .textFieldStyle(.roundedBorder)
                            .focused($foco, equals: .presupuesto)
                    }
                }
                GridRow {
                    campo(L.t("Estado", "Status")) {
                        Picker("", selection: $estadoEvento) {
                            ForEach(estados, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    campo(L.t("Repetición", "Repeat")) {
                        Picker("", selection: $repeticion) {
                            ForEach(repeticiones, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
                GridRow {
                    campo(L.t("Avisar", "Remind")) {
                        // Casillas y no un selector: los avisos se acumulan
                        // —"una semana antes" Y "el mismo día"— y un `Picker`
                        // sabría elegir uno solo.
                        HStack(spacing: 14) {
                            ForEach(avisos, id: \.self) { a in
                                Toggle(a, isOn: Binding(
                                    get: { recordatorios.contains(a) },
                                    set: { encendido in
                                        if encendido { recordatorios.insert(a) }
                                        else { recordatorios.remove(a) }
                                    }))
                                    .toggleStyle(.checkbox)
                            }
                        }
                    }
                    .gridCellColumns(2)
                }
                GridRow {
                    Toggle(L.t("Fecha importante", "Key date"), isOn: $esFechaImportante)
                        .gridCellColumns(2)
                }
                GridRow {
                    campo(L.t("Descripción", "Description")) {
                        TextField("", text: $descripcion,
                                  prompt: Text(L.t("Opcional", "Optional")),
                                  axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .focused($foco, equals: .descripcion)
                    }
                    .gridCellColumns(2)
                }
                GridRow {
                    campo(L.t("Nota al pie", "Footnote")) {
                        TextField("", text: $notaPie,
                                  prompt: Text(L.t("Opcional", "Optional")))
                            .textFieldStyle(.roundedBorder)
                            .focused($foco, equals: .nota)
                    }
                    .gridCellColumns(2)
                }
            }

            if intentoGuardar && !puedeGuardar {
                Label(L.t("Falta el título de la actividad.",
                          "The activity title is missing."),
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Paleta.negativo)
            }

            HStack(spacing: 9) {
                // El mismo aviso honesto que la captura rápida: el tabulador
                // recorre las casillas de texto, no los selectores.
                Text(L.t("El tabulador recorre las casillas de texto.",
                         "Tab moves through the text fields."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                Button(L.t("Guardar", "Save")) { guardar() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.brand)
            }
        }
        .padding(18)
        .frame(width: 640)
        .task {
            estadoEvento = estados[0]
            repeticion = repeticiones[0]
            if padron.isEmpty { padron = await padronParaSelector() }
            foco = .titulo
        }
    }

    private func campo<C: View>(_ rotulo: String,
                                @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).font(.system(size: 11.5)).foregroundStyle(.secondary)
            contenido()
        }
    }

    private func guardar() {
        intentoGuardar = true
        guard puedeGuardar else {
            foco = .titulo
            return
        }
        // **Sin hora cuando es de todo el día**, y las dos a la vez: dejar solo
        // la de fin sería una actividad que termina antes de empezar.
        let inicio: String? = todoDia ? nil : Self.fmtHora.string(from: horaInicio)
        let fin: String? = todoDia ? nil : Self.fmtHora.string(from: horaFin)

        // **Los dos campos del responsable son EXCLUYENTES**, igual que en el
        // web: quien está en el padrón viaja como id y deja el nombre vacío
        // —así, quien se case y cambie de apellido no deja actividades
        // hablando de quien ya no se llama así—; quien no está, como texto.
        let delPadron = padron.first { $0.id == responsable }
        let externo = responsable == "__ext__"

        let ev = EventoAgenda(
            id: proximoId,
            // **La fecha ENTERA en clave local**, no el día del mes: un evento
            // guardado con el número suelto valdría para el 21 de cualquier mes
            // de cualquier año. `Fechas.claveDia` es la misma que usa iOS.
            fecha: Fechas.claveDia(fecha),
            hora: inicio,
            titulo: titulo.trimmingCharacters(in: .whitespaces),
            descripcion: descripcion.trimmingCharacters(in: .whitespaces),
            tipo: tipo,
            completado: false,
            todoDia: todoDia,
            horaFin: fin,
            lugar: lugar.trimmingCharacters(in: .whitespaces),
            responsable: externo ? L.t("Otra persona", "Other person")
                                 : (delPadron?.nombre ?? ""),
            responsableId: delPadron?.id,
            ministerio: ministerio.trimmingCharacters(in: .whitespaces),
            presupuesto: presupuesto.trimmingCharacters(in: .whitespaces),
            notaPie: notaPie.trimmingCharacters(in: .whitespaces),
            repeticion: repeticion,
            estadoEvento: estadoEvento,
            esFechaImportante: esFechaImportante,
            recordatorios: Array(recordatorios)
        )
        alGuardar(ev)
        cerrar()
    }
}
