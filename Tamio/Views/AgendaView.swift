import SwiftUI

struct AgendaView: View {
    @State private var vm = AgendaViewModel()
    @State private var mostrarNuevo = false
    @State private var diaAbierto = false

    private let diasSemana = ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"]

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    calendarioColumna
                        .frame(minWidth: 300, maxWidth: 420)
                        .background(.regularMaterial)
                    Divider()
                    detalleDiaColumna
                }
            } else {
                calendarioColumna
                    .background(.regularMaterial)
                    .navigationDestination(isPresented: $diaAbierto) {
                        detalleDiaColumna
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(
            L.t("Agenda", "Calendar"),
            L.t("\(vm.etiquetaMes) · \(vm.pendientesMes) pendientes",
                "\(vm.etiquetaMes) · \(vm.pendientesMes) pending")
        )
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNuevo = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text(L.t("Nuevo", "New"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                    .background(Paleta.brand, in: Capsule())
                }
            }
        }
        .task { await vm.cargar() }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoEventoSheet(
                mesActual: vm.mesActual,
                diaInicial: vm.diaSeleccionado,
                proximoId: vm.proximoId
            ) { ev in
                vm.añadir(ev)
            }
        }
    }

    // MARK: - Columna calendario (izquierda)

    @ViewBuilder
    private var calendarioColumna: some View {
        VStack(spacing: 0) {
            Picker(L.t("Vista", "View"), selection: $vm.vistaActual) {
                Text(L.t("Mes", "Month")).tag(0)
                Text(L.t("Semana", "Week")).tag(1)
                Text(L.t("Lista", "List")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)

            navMes
            Divider()

            switch vm.vistaActual {
            case 1:  vistaSemana
            case 2:  vistaLista
            default: vistaMes
            }
        }
    }

    // MARK: - Barra de navegación de mes

    private var navMes: some View {
        HStack(spacing: 0) {
            Button { vm.irAlMesAnterior() } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text(vm.etiquetaMes)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button { vm.irAHoy() } label: {
                Text(L.t("Hoy", "Today"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Paleta.brand)
            }

            Button { vm.irAlMesSiguiente() } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Esp.hueco).padding(.bottom, 4)
    }

    // MARK: - Vista Mes

    private var vistaMes: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(diasSemana, id: \.self) { d in
                        Text(d)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Esp.hueco).padding(.vertical, 4)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                    spacing: 0
                ) {
                    ForEach(vm.celdasDelMes) { celda in
                        if let dia = celda.dia {
                            celdaDia(dia)
                        } else {
                            Color.clear.frame(height: 54)
                        }
                    }
                }
                .padding(.horizontal, Esp.hueco)
            }
        }
    }

    private func celdaDia(_ dia: Int) -> some View {
        let sel = dia == vm.diaSeleccionado
        let hoy = vm.diaHoy == dia
        let evs = vm.eventos(dia: dia)

        return Button { vm.diaSeleccionado = dia; diaAbierto = true } label: {
            VStack(spacing: 3) {
                ZStack {
                    if sel {
                        Circle().fill(Paleta.brand).frame(width: 28, height: 28)
                    } else if hoy {
                        Circle().stroke(Paleta.brand, lineWidth: 1.5).frame(width: 28, height: 28)
                    }
                    Text("\(dia)")
                        .font(.subheadline.weight(sel || hoy ? .semibold : .regular))
                        .foregroundStyle(sel ? .white : (hoy ? Paleta.brand : .primary))
                }
                HStack(spacing: 3) {
                    ForEach(evs.prefix(3)) { ev in
                        Circle().fill(ev.tipo.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 8)
            }
            .frame(height: 54).frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vista Semana

    @ViewBuilder
    private var vistaSemana: some View {
        let weekdayOfSel = (vm.primerDiaOffset + vm.diaSeleccionado - 1) % 7
        let primerDiaSemana = vm.diaSeleccionado - weekdayOfSel

        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let d = primerDiaSemana + i
                        if d >= 1, d <= vm.diasEnMes {
                            celdaSemana(d, weekdayIndex: i)
                        } else {
                            celdaSemanaVacia(weekdayIndex: i)
                        }
                    }
                }
                .padding(.vertical, 8)

                Divider()

                let evs = vm.eventosDia
                if evs.isEmpty {
                    ContentUnavailableView(L.t("Sin eventos", "No events"),
                                           systemImage: "calendar.badge.checkmark")
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 6) {
                        ForEach(evs) { ev in tarjetaEventoCompacta(ev) }
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
                }
            }
        }
    }

    private func celdaSemana(_ dia: Int, weekdayIndex: Int) -> some View {
        let sel = dia == vm.diaSeleccionado
        let hoy = vm.diaHoy == dia
        let evs = vm.eventos(dia: dia)

        return Button { vm.diaSeleccionado = dia; diaAbierto = true } label: {
            VStack(spacing: 5) {
                Text(diasSemana[weekdayIndex])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ZStack {
                    if sel {
                        Circle().fill(Paleta.brand).frame(width: 30, height: 30)
                    } else if hoy {
                        Circle().stroke(Paleta.brand, lineWidth: 1.5).frame(width: 30, height: 30)
                    }
                    Text("\(dia)")
                        .font(.subheadline.weight(sel || hoy ? .semibold : .regular))
                        .foregroundStyle(sel ? .white : (hoy ? Paleta.brand : .primary))
                }

                HStack(spacing: 2) {
                    ForEach(evs.prefix(2)) { ev in
                        Circle().fill(ev.tipo.color).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func celdaSemanaVacia(weekdayIndex: Int) -> some View {
        VStack(spacing: 5) {
            Text(diasSemana[weekdayIndex])
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
            Color.clear.frame(width: 30, height: 30)
            Color.clear.frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Vista Lista

    private var vistaLista: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(vm.eventosOrdenados, id: \.dia) { grupo in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(grupo.lista.enumerated()), id: \.element.id) { i, ev in
                                Button { vm.diaSeleccionado = grupo.dia; diaAbierto = true } label: {
                                    eventoFilaLista(ev)
                                }
                                .buttonStyle(.plain)
                                if i < grupo.lista.count - 1 { Divider().padding(.leading, 12) }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.75))
                        .padding(.horizontal, Esp.pantalla).padding(.bottom, 8)
                    } header: {
                        Text(etiquetaDiaLista(grupo.dia))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Esp.pantalla).padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGroupedBackground).opacity(0.95))
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func eventoFilaLista(_ ev: EventoAgenda) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ev.completado ? Color(.tertiaryLabel) : ev.tipo.color)
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(ev.titulo)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ev.completado ? .secondary : .primary)
                    .strikethrough(ev.completado)
                    .lineLimit(1)
                if let hora = ev.hora {
                    Text(hora).font(.caption2).foregroundStyle(ev.tipo.color)
                }
            }
            Spacer()
            if ev.completado {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Paleta.brand)
            }
        }
        .padding(.horizontal, Esp.fila).padding(.vertical, 10)
    }

    // MARK: - Columna detalle del día (derecha)

    private var detalleDiaColumna: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let evs = vm.eventosDia
                let pendientes = evs.filter { !$0.completado }.count
                let completos  = evs.filter { $0.completado }.count

                VStack(alignment: .leading, spacing: 4) {
                    Text(tituloDia)
                        .font(.title3.weight(.semibold))
                    Text(subtituloDia(pendientes: pendientes, completos: completos))
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                if evs.isEmpty {
                    ContentUnavailableView(L.t("Sin eventos", "No events"),
                                           systemImage: "calendar.badge.checkmark")
                } else {
                    ForEach(evs) { ev in tarjetaEvento(ev) }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Tarjetas de evento

    private func tarjetaEvento(_ ev: EventoAgenda) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ev.completado ? Color(.tertiaryLabel) : ev.tipo.color)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(ev.titulo)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ev.completado ? .secondary : .primary)
                        .strikethrough(ev.completado)
                        .lineLimit(1)
                    Spacer()
                    if ev.completado {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Paleta.brand)
                    }
                }
                if let hora = ev.hora {
                    Text(hora)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ev.tipo.color)
                }
                if !ev.descripcion.isEmpty {
                    Text(ev.descripcion)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.75)
        )
    }

    private func tarjetaEventoCompacta(_ ev: EventoAgenda) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ev.completado ? Color(.tertiaryLabel) : ev.tipo.color)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(ev.titulo)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ev.completado ? .secondary : .primary)
                    .strikethrough(ev.completado)
                    .lineLimit(1)
                if let hora = ev.hora {
                    Text(hora).font(.caption2).foregroundStyle(ev.tipo.color)
                }
            }

            Spacer()

            if ev.completado {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Paleta.brand)
            }
        }
        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Helpers

    private var tituloDia: String {
        let offset = (vm.primerDiaOffset + vm.diaSeleccionado - 1) % 7
        let nombres = [
            L.t("Domingo", "Sunday"), L.t("Lunes", "Monday"), L.t("Martes", "Tuesday"),
            L.t("Miércoles", "Wednesday"), L.t("Jueves", "Thursday"),
            L.t("Viernes", "Friday"), L.t("Sábado", "Saturday"),
        ]
        return "\(nombres[offset]) \(vm.diaSeleccionado)"
    }

    private func subtituloDia(pendientes: Int, completos: Int) -> String {
        guard pendientes + completos > 0 else {
            return L.t("Sin compromisos", "No commitments")
        }
        var partes: [String] = []
        if pendientes > 0 { partes.append("\(pendientes) \(L.t("pendientes", "pending"))") }
        if completos  > 0 { partes.append("\(completos) \(L.t("completos", "completed"))") }
        return partes.joined(separator: " · ")
    }

    private func etiquetaDiaLista(_ dia: Int) -> String {
        let offset = (vm.primerDiaOffset + dia - 1) % 7
        let abrevs = ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"]
        return "\(abrevs[offset])  \(dia)"
    }
}

// MARK: - Sheet: Nueva actividad

private struct NuevoEventoSheet: View {
    let mesActual: Date
    let diaInicial: Int
    let proximoId: String
    let onGuardar: (EventoAgenda) -> Void

    @State private var titulo = ""
    @State private var tipo: TipoEvento = .culto
    @State private var fechaEvento: Date
    @State private var todoDia = false
    @State private var horaInicio = Date()
    @State private var horaFin = Date()
    @State private var lugar = ""
    @State private var descripcion = ""
    @State private var responsable = ""
    @State private var ministerio = ""
    @State private var presupuesto = ""
    @State private var notaPie = ""
    @State private var repeticion: String
    @State private var estadoEvento: String
    @State private var esFechaImportante = false
    @State private var recordatorios: Set<String> = []

    @Environment(\.dismiss) private var dismiss

    private static let fmtHora: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let miembrosMock = [
        "Brenda Castillo", "Dennis Castillo", "Denys Castillo",
        "Juan Martínez", "Pedro García", "Susana Ortiz",
        "María López", "José Hernández"
    ]

    private let opcionesRepeticion: [String]
    private let estadosEvento: [String]
    private let opcionesRecordatorio: [String]

    init(mesActual: Date, diaInicial: Int, proximoId: String, onGuardar: @escaping (EventoAgenda) -> Void) {
        self.mesActual = mesActual
        self.diaInicial = diaInicial
        self.proximoId = proximoId
        self.onGuardar = onGuardar

        var comps = Calendar.current.dateComponents([.year, .month], from: mesActual)
        comps.day = diaInicial
        _fechaEvento = State(initialValue: Calendar.current.date(from: comps) ?? Date())

        let reps = [
            L.t("No se repite", "No repeat"),
            L.t("Semanal", "Weekly"),
            L.t("Cada dos semanas", "Every two weeks"),
            L.t("Mensual", "Monthly"),
            L.t("Anual", "Yearly"),
            L.t("Personalizado", "Custom")
        ]
        opcionesRepeticion = reps
        _repeticion = State(initialValue: reps[0])

        let estados = [
            L.t("Programado", "Scheduled"),
            L.t("Confirmado", "Confirmed"),
            L.t("Cancelado", "Cancelled"),
            L.t("Completado", "Completed")
        ]
        estadosEvento = estados
        _estadoEvento = State(initialValue: estados[0])

        opcionesRecordatorio = [
            L.t("Mismo día", "Same day"),
            L.t("Un día antes", "One day before"),
            L.t("Dos días antes", "Two days before"),
            L.t("Una semana antes", "One week before")
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("EVENTO", "EVENT")) {
                    TextField(L.t("Título", "Title"), text: $titulo)
                    Picker(L.t("Tipo", "Type"), selection: $tipo) {
                        ForEach(TipoEvento.allCases, id: \.self) { t in
                            Text(t.titulo).tag(t)
                        }
                    }
                }

                Section(L.t("FECHA Y HORA", "DATE & TIME")) {
                    DatePicker(L.t("Fecha", "Date"), selection: $fechaEvento,
                               displayedComponents: .date)
                        .tint(Paleta.brand)
                    Toggle(L.t("Todo el día", "All-day activity"), isOn: $todoDia)
                        .tint(Paleta.brand)
                    if !todoDia {
                        DatePicker(L.t("Hora inicio", "Start time"), selection: $horaInicio,
                                   displayedComponents: .hourAndMinute)
                            .tint(Paleta.brand)
                        DatePicker(L.t("Hora fin", "End time"), selection: $horaFin,
                                   displayedComponents: .hourAndMinute)
                            .tint(Paleta.brand)
                    }
                    TextField(L.t("Lugar (opcional)", "Location (optional)"), text: $lugar)
                }

                Section(L.t("DESCRIPCIÓN", "DESCRIPTION")) {
                    TextField(L.t("Descripción o notas (opcional)", "Description / notes (optional)"),
                              text: $descripcion, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section(L.t("RESPONSABILIDAD", "RESPONSIBILITY")) {
                    Picker(L.t("Responsable", "Person in charge"), selection: $responsable) {
                        Text(L.t("— Sin asignar —", "— Unassigned —")).tag("")
                        ForEach(Self.miembrosMock, id: \.self) { m in Text(m).tag(m) }
                        Text(L.t("— Otra persona (externa) —", "— Other person (external) —")).tag("__ext__")
                    }
                    TextField(L.t("Ministerio / departamento (opcional)", "Ministry / department (optional)"),
                              text: $ministerio)
                    TextField(L.t("Presupuesto o ponente (opcional)", "Budget or speaker (optional)"),
                              text: $presupuesto)
                    TextField(L.t("Nota al pie (opcional)", "Footnote (optional)"),
                              text: $notaPie)
                }

                Section {
                    Picker(L.t("Repetición", "Repeats"), selection: $repeticion) {
                        ForEach(opcionesRepeticion, id: \.self) { Text($0).tag($0) }
                    }
                    Picker(L.t("Estado", "Status"), selection: $estadoEvento) {
                        ForEach(estadosEvento, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle(L.t("Marcar como fecha importante", "Mark as important date"),
                           isOn: $esFechaImportante).tint(Paleta.brand)
                } header: {
                    Text(L.t("ADICIONAL", "ADDITIONAL"))
                }

                Section(L.t("RECORDATORIOS", "REMINDERS")) {
                    FlowLayout(spacing: 8) {
                        ForEach(opcionesRecordatorio, id: \.self) { op in
                            let sel = recordatorios.contains(op)
                            Button {
                                if sel { recordatorios.remove(op) } else { recordatorios.insert(op) }
                            } label: {
                                Text(op)
                                    .font(.subheadline)
                                    .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                                    .background(sel ? Paleta.brand : Color(.tertiarySystemFill),
                                                in: Capsule())
                                    .foregroundStyle(sel ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(L.t("Nueva actividad", "New activity"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar actividad", "Save activity")) { guardar() }
                        .fontWeight(.semibold)
                        .foregroundStyle(titulo.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? .secondary : Paleta.brand)
                        .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .hojaGrande()
    }

    private func guardar() {
        let dia = Calendar.current.component(.day, from: fechaEvento)
        let horaStr: String? = todoDia ? nil : Self.fmtHora.string(from: horaInicio)
        let horaFinStr: String? = todoDia ? nil : Self.fmtHora.string(from: horaFin)
        let resp = responsable == "__ext__" ? L.t("Otra persona", "Other person") : responsable

        let ev = EventoAgenda(
            id: proximoId,
            dia: dia,
            hora: horaStr,
            titulo: titulo.trimmingCharacters(in: .whitespaces),
            descripcion: descripcion.trimmingCharacters(in: .whitespaces),
            tipo: tipo,
            completado: false,
            todoDia: todoDia,
            horaFin: horaFinStr,
            lugar: lugar.trimmingCharacters(in: .whitespaces),
            responsable: resp,
            ministerio: ministerio.trimmingCharacters(in: .whitespaces),
            presupuesto: presupuesto.trimmingCharacters(in: .whitespaces),
            notaPie: notaPie.trimmingCharacters(in: .whitespaces),
            repeticion: repeticion,
            estadoEvento: estadoEvento,
            esFechaImportante: esFechaImportante,
            recordatorios: Array(recordatorios)
        )
        onGuardar(ev)
        dismiss()
    }
}
