import SwiftUI

struct ServiciosView: View {
    @State private var vm = ServiciosViewModel()
    @State private var abierto: Servicio?
    @State private var mostrarNuevo = false
    @State private var mostrarAsignar = false
    @State private var mostrarAsistencia = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: Esp.columnaMaestra)
                        .background(.regularMaterial)
                    Divider()
                    if let s = vm.seleccion {
                        detalleServicio(s)
                    } else {
                        ContentUnavailableView(L.t("Selecciona un servicio", "Select a service"),
                                               systemImage: "book")
                    }
                }
            } else {
                listaColumna
                    .background(.regularMaterial)
                    .navigationDestination(item: $abierto) { s in
                        detalleServicio(s)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Registro de servicios", "Service log"),
                       L.t("Roster y asistencia por culto", "Roster & attendance by service"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNuevo = true } label: {
                    Label(L.t("Nuevo", "New"), systemImage: "plus")
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)
            }
        }
        .task { await vm.cargar() }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoServicioSheet(proximoId: vm.proximoId) { vm.agregarServicio($0) }
        }
        .sheet(isPresented: $mostrarAsignar) {
            if let s = vm.seleccion {
                AsignarRosterSheet(servicio: s) { personas in
                    vm.actualizarRoster(servicioId: s.id, personas: personas)
                }
            }
        }
        .sheet(isPresented: $mostrarAsistencia) {
            if let s = vm.seleccion {
                TomarAsistenciaSheet(servicio: s) { presentes, total, fecha in
                    vm.registrarAsistencia(servicioId: s.id, presentes: presentes,
                                           total: total, fecha: fecha)
                }
            }
        }
    }

    // MARK: - Lista

    @ViewBuilder
    private var listaColumna: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaColumnaCore
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var listaColumnaCore: some View {
        List {
            Section {
                ForEach(vm.lista) { s in
                    filaServicio(s)
                        .contentShape(Rectangle())
                        .onTapGesture { abrir(s) }
                }
            } header: {
                Text(L.t("Próximos", "Upcoming"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }

    private func filaServicio(_ s: Servicio) -> some View {
        let sel = s.id == vm.seleccionId
        return HStack(spacing: 12) {
            // Badge día
            VStack(spacing: 1) {
                Text(s.diaSemana)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sel ? Paleta.brand : .secondary)
                Text(s.numDia)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(sel ? Paleta.brand : .primary)
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(s.titulo).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(s.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Pill(texto: s.estadoRoster.etiqueta, color: s.estadoRoster.color)
                .fixedSize()
        }
        .padding(.vertical, 11)
        .filaDeLista(seleccionada: sel, tarjeta: sizeClass != .regular)
    }

    // MARK: - Detalle

    private func detalleServicio(_ s: Servicio) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Encabezado
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.titulo).font(.title2.weight(.semibold))
                    Text("\(s.diaSemana) \(s.numDia) de agosto · \(s.hora) · \(s.lugar)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                // Botones de acción
                HStack(spacing: 10) {
                    Button { mostrarAsistencia = true } label: {
                        Text(L.t("Tomar asistencia", "Take attendance"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Paleta.brand)
                            .padding(.horizontal, Esp.chip).padding(.vertical, 8)
                            .background(Paleta.brandFill, in: Capsule())
                    }
                    Button { mostrarAsignar = true } label: {
                        Text(L.t("Asignar", "Assign"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Esp.chip).padding(.vertical, 8)
                            .background(Paleta.brand, in: Capsule())
                    }
                    Spacer()
                }

                // Roster
                Tarjeta {
                    VStack(alignment: .leading, spacing: 0) {
                        TituloSeccion(texto: L.t("ROSTER", "ROSTER"))
                            .padding(.bottom, 12)
                        ForEach(s.roster) { item in
                            HStack(spacing: 12) {
                                Text(item.rol)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                if item.asignado {
                                    Text(item.display)
                                        .font(.subheadline.weight(.medium))
                                } else {
                                    Text(item.display)
                                        .font(.subheadline)
                                        .foregroundStyle(Paleta.enlace)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            if item.id != s.roster.last?.id { Divider() }
                        }
                    }
                }

                // Asistencia del último mes
                Tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        TituloSeccion(texto: L.t("ASISTENCIA DEL ÚLTIMO MES", "LAST MONTH ATTENDANCE"))
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(s.historial) { a in
                                VStack(spacing: 4) {
                                    VStack(spacing: 0) {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Paleta.brand)
                                            .frame(height: 48 * a.pct)
                                    }
                                    .frame(height: 48)
                                    Text(a.fecha).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }

                // Orden del culto
                Tarjeta {
                    VStack(alignment: .leading, spacing: 0) {
                        TituloSeccion(texto: L.t("ORDEN DEL CULTO", "SERVICE ORDER"))
                            .padding(.bottom, 12)
                        ForEach(s.orden) { punto in
                            HStack(alignment: .top, spacing: 14) {
                                Text(punto.hora)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Paleta.brand)
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .leading)
                                Text(punto.descripcion)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 7)
                            if punto.id != s.orden.last?.id { Divider() }
                        }
                    }
                }
            }
            .padding(Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func abrir(_ s: Servicio) {
        vm.seleccionId = s.id
        abierto = s
    }
}

// MARK: - Sheet: Nuevo servicio

private struct NuevoServicioSheet: View {
    let proximoId: String
    let onGuardar: (Servicio) -> Void
    @Environment(\.dismiss) private var dismiss

    // SERVICE INFORMATION
    @State private var tipo = L.t("Culto dominical", "Sunday service")
    @State private var fecha = Date()
    @State private var horaStr = "10:00"
    @State private var lugar = L.t("templo principal", "main sanctuary")
    @State private var lidero = ""
    @State private var predico = ""
    @State private var cancionItems: [(id: UUID, texto: String)] = []
    @State private var nuevaCancion = ""

    // ATTENDANCE
    @State private var presenciaMap: [String: Bool] = [:]
    @State private var busquedaMiembro = ""
    @State private var ninos = 0
    @State private var jovenes = 0
    @State private var adultos = 0

    // VISITORS
    @State private var visitanteItems: [(id: UUID, nombre: String)] = []
    @State private var nuevoVisitante = ""

    // PASSAGE
    @State private var tituloMensaje = ""
    @State private var textoBiblico = ""
    @State private var resumenMensaje = ""

    // BIBLE SCHOOL
    @State private var temaEscuela = ""
    @State private var maestroEscuela = ""

    // SPECIAL EVENTS
    @State private var eventosEspeciales = ""

    private static let miembrosMock = [
        "Brenda Rosado", "Dennis Castillo", "Denys Castillo",
        "Juan Martínez", "Pedro Salas", "Susana Orts",
        "Pastor Abel Ramos", "Lucía Márquez", "Jorge Hernández",
        "Carlos Rivas", "María Hernández Ríos", "Ana Lucía Torres",
    ]

    private let tipos = [
        L.t("Culto dominical",   "Sunday service"),
        L.t("Culto matutino",    "Morning service"),
        L.t("Culto vespertino",  "Evening service"),
        L.t("Reunión de oración","Prayer meeting"),
        L.t("Santa cena",        "Lord's Supper"),
        L.t("Especial",          "Special"),
    ]
    private let lugares = [
        L.t("templo principal", "main sanctuary"),
        L.t("salón anexo",      "annex hall"),
        L.t("capilla",          "chapel"),
    ]

    private var miembrosFiltrados: [String] {
        busquedaMiembro.isEmpty ? Self.miembrosMock
            : Self.miembrosMock.filter { $0.localizedCaseInsensitiveContains(busquedaMiembro) }
    }
    private var presentesCount: Int { presenciaMap.values.filter { $0 }.count }
    private var ausentesCount: Int  { presenciaMap.count - presentesCount }
    private var headcountTotal: Int { ninos + jovenes + adultos }

    var body: some View {
        NavigationStack {
            Form {
                seccionServicio
                seccionAsistencia
                seccionVisitantes
                seccionMensaje
                seccionEscuela
                seccionEventos
            }
            .navigationTitle(L.t("Nuevo servicio", "New service"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar servicio", "Save service")) {
                        onGuardar(construir())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Paleta.brand)
                }
            }
            .onAppear {
                guard presenciaMap.isEmpty else { return }
                presenciaMap = Dictionary(uniqueKeysWithValues: Self.miembrosMock.map { ($0, false) })
            }
        }
        .hojaGrande()
    }

    // MARK: - Sections

    @ViewBuilder
    private var seccionServicio: some View {
        Section(L.t("INFORMACIÓN DEL SERVICIO", "SERVICE INFORMATION")) {
            DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
            Picker(L.t("Tipo de servicio", "Service type"), selection: $tipo) {
                ForEach(tipos, id: \.self) { Text($0).tag($0) }
            }
            Picker(L.t("Lugar", "Location"), selection: $lugar) {
                ForEach(lugares, id: \.self) { Text($0).tag($0) }
            }
            HStack {
                Text(L.t("Hora", "Time"))
                Spacer()
                TextField("10:00", text: $horaStr)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 70)
            }
            TextField(L.t("Lideró el servicio · opcional", "Lead the service · optional"), text: $lidero)
                .autocorrectionDisabled()
            TextField(L.t("Predicó · opcional", "Preached · optional"), text: $predico)
                .autocorrectionDisabled()
            ForEach(cancionItems, id: \.id) { item in
                HStack(spacing: 10) {
                    Image(systemName: "music.note").font(.caption).foregroundStyle(Paleta.brand)
                    Text(item.texto)
                    Spacer()
                }
                .swipeActions { Button(role: .destructive) { cancionItems.removeAll { $0.id == item.id } }
                    label: { Label(L.t("Borrar", "Delete"), systemImage: "trash") }
                    .tint(.red) }   // el tint del TabView tapa el rojo del rol
            }
            HStack {
                TextField(L.t("Canciones y participaciones · agregar", "Add a song or participation"),
                          text: $nuevaCancion)
                    .autocorrectionDisabled()
                if !nuevaCancion.isEmpty {
                    Button(L.t("Agregar", "Add")) { cancionItems.append((UUID(), nuevaCancion)); nuevaCancion = "" }
                        .foregroundStyle(Paleta.brand).buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var seccionAsistencia: some View {
        Section {
            // Buscador + botones Mark all / Unmark all
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L.t("Buscar por nombre...", "Search member by name..."), text: $busquedaMiembro)
                    .autocorrectionDisabled()
                if !busquedaMiembro.isEmpty {
                    Button { busquedaMiembro = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button(L.t("Marcar todos", "Mark all")) {
                    for n in Self.miembrosMock { presenciaMap[n] = true }
                }
                .font(.caption.weight(.medium)).foregroundStyle(Paleta.brand).buttonStyle(.plain)
                Text("·").font(.caption).foregroundStyle(.tertiary)
                Button(L.t("Desmarcar", "Unmark all")) {
                    for n in Self.miembrosMock { presenciaMap[n] = false }
                }
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).buttonStyle(.plain)
            }
            // Contadores
            HStack(spacing: 20) {
                Label(L.t("Padrón: \(Self.miembrosMock.count)", "Roster: \(Self.miembrosMock.count)"),
                      systemImage: "person.2")
                    .font(.caption).foregroundStyle(.secondary)
                Label("\(presentesCount) \(L.t("presentes", "present"))",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(Paleta.brand)
                Label("\(ausentesCount) \(L.t("ausentes", "absent"))",
                      systemImage: "minus.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            // Lista de miembros con Toggle
            ForEach(miembrosFiltrados, id: \.self) { nombre in
                Toggle(isOn: Binding(
                    get: { presenciaMap[nombre] ?? false },
                    set: { presenciaMap[nombre] = $0 }
                )) { Text(nombre) }
                .tint(Paleta.brand)
            }
        } header: {
            Text(L.t("ASISTENCIA", "ATTENDANCE"))
        }

        Section {
            Stepper(value: $ninos, in: 0...999) {
                HStack { Text(L.t("Niños", "Children")); Spacer()
                    Text("\(ninos)").foregroundStyle(ninos > 0 ? Paleta.brand : .secondary).monospacedDigit() }
            }
            Stepper(value: $jovenes, in: 0...999) {
                HStack { Text(L.t("Jóvenes", "Youth")); Spacer()
                    Text("\(jovenes)").foregroundStyle(jovenes > 0 ? Paleta.brand : .secondary).monospacedDigit() }
            }
            Stepper(value: $adultos, in: 0...999) {
                HStack { Text(L.t("Adultos", "Adults")); Spacer()
                    Text("\(adultos)").foregroundStyle(adultos > 0 ? Paleta.brand : .secondary).monospacedDigit() }
            }
        } header: {
            HStack {
                Text(L.t("CONTEO POR GRUPO", "HEADCOUNT BY GROUP"))
                Spacer()
                if headcountTotal > 0 {
                    Text(L.t("Total: \(headcountTotal)", "Total: \(headcountTotal)"))
                        .foregroundStyle(Paleta.brand).monospacedDigit()
                }
            }
        } footer: {
            Text(L.t("Usa este conteo si el total no proviene de la lista de miembros.",
                     "Use this count if the total doesn't come from the member list above."))
        }
    }

    @ViewBuilder
    private var seccionVisitantes: some View {
        Section(L.t("VISITANTES", "VISITORS")) {
            ForEach(visitanteItems, id: \.id) { item in
                Text(item.nombre)
                    .swipeActions { Button(role: .destructive) { visitanteItems.removeAll { $0.id == item.id } }
                        label: { Label(L.t("Borrar", "Delete"), systemImage: "trash") }
                        .tint(.red) }
            }
            HStack {
                TextField(L.t("+ Agregar visitante", "+ Add visitor"), text: $nuevoVisitante)
                    .autocorrectionDisabled()
                if !nuevoVisitante.isEmpty {
                    Button(L.t("Agregar", "Add")) { visitanteItems.append((UUID(), nuevoVisitante)); nuevoVisitante = "" }
                        .foregroundStyle(Paleta.brand).buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var seccionMensaje: some View {
        Section(L.t("MENSAJE", "PASSAGE")) {
            TextField(L.t("Título del mensaje · opcional", "Message title · optional"), text: $tituloMensaje)
                .autocorrectionDisabled()
            TextField(L.t("Texto bíblico principal · p. ej. Salmos 121:1-8",
                          "Main Bible text · e.g. Psalm 121:1-8"),
                      text: $textoBiblico)
                .autocorrectionDisabled()
            TextField(L.t("Resumen breve del mensaje · opcional",
                          "Brief summary of this message · optional"),
                      text: $resumenMensaje, axis: .vertical)
                .lineLimit(2...5)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var seccionEscuela: some View {
        Section(L.t("ESCUELA BÍBLICA", "BIBLE SCHOOL")) {
            TextField(L.t("Tema enseñado · opcional", "Topic taught · optional"), text: $temaEscuela)
                .autocorrectionDisabled()
            TextField(L.t("Maestro(a) · opcional", "Class teacher · optional"), text: $maestroEscuela)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var seccionEventos: some View {
        Section(L.t("EVENTOS ESPECIALES", "SPECIAL EVENTS")) {
            TextField(
                L.t("Comuniones, bautismos, dedicaciones u otros eventos especiales...",
                    "Communions, baptisms, child dedications, or other special events..."),
                text: $eventosEspeciales, axis: .vertical)
                .lineLimit(2...5)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Build Servicio

    private func construir() -> Servicio {
        let fmtDia   = DateFormatter(); fmtDia.dateFormat = "d"; fmtDia.locale = L.locale
        let fmtSem   = DateFormatter(); fmtSem.dateFormat = "EEE"; fmtSem.locale = L.locale
        let fmtFecha = DateFormatter(); fmtFecha.dateFormat = L.t("d MMM", "MMM d"); fmtFecha.locale = L.locale

        let numDia     = fmtDia.string(from: fecha)
        let diaSem     = fmtSem.string(from: fecha).uppercased()
        let fechaCorta = fmtFecha.string(from: fecha)

        let histInicial: [AsistenciaServicio] = headcountTotal > 0
            ? [AsistenciaServicio(id: "1", fecha: fechaCorta, presentes: headcountTotal,
                                  total: max(headcountTotal, Self.miembrosMock.count))]
            : []

        return Servicio(
            id: proximoId,
            diaSemana: diaSem,
            numDia: numDia,
            titulo: tipo,
            hora: horaStr,
            lugar: lugar,
            estadoRoster: .sinAsignar,
            roster: rosterDefault(),
            historial: histInicial,
            orden: ordenDefault(),
            lideroServicio: lidero.isEmpty ? nil : lidero,
            predico: predico.isEmpty ? nil : predico,
            canciones: cancionItems.map(\.texto),
            tituloMensaje: tituloMensaje.isEmpty ? nil : tituloMensaje,
            textoBiblico: textoBiblico.isEmpty ? nil : textoBiblico,
            resumenMensaje: resumenMensaje.isEmpty ? nil : resumenMensaje,
            temaEscuelaDominica: temaEscuela.isEmpty ? nil : temaEscuela,
            maestroEscuela: maestroEscuela.isEmpty ? nil : maestroEscuela,
            eventosEspeciales: eventosEspeciales.isEmpty ? nil : eventosEspeciales,
            visitantes: visitanteItems.map(\.nombre),
            ninos: ninos,
            jovenes: jovenes,
            adultos: adultos
        )
    }

    private func rosterDefault() -> [AsignacionRoster] {
        let roles: [String]
        let dominical = L.t("Culto dominical",   "Sunday service")
        let mañana    = L.t("Culto matutino",    "Morning service")
        let tarde     = L.t("Culto vespertino",  "Evening service")
        let cena      = L.t("Santa cena",        "Lord's Supper")
        let oracion   = L.t("Reunión de oración","Prayer meeting")

        switch tipo {
        case dominical, mañana, tarde:
            roles = [L.t("Predicación","Preaching"), L.t("Alabanza","Worship"),
                     L.t("Ujieres","Ushers"), L.t("Ofrenda","Offering"), L.t("Sonido","Sound")]
        case cena:
            roles = [L.t("Predicación","Preaching"), L.t("Alabanza","Worship"),
                     L.t("Ujieres","Ushers"), L.t("Ministración cena","Supper ministers")]
        case oracion:
            roles = [L.t("Dirigente","Leader")]
        default:
            roles = [L.t("Predicación","Preaching"), L.t("Alabanza","Worship")]
        }
        return roles.enumerated().map {
            AsignacionRoster(id: $0.offset + 1, rol: $0.element, persona: nil, extras: 0)
        }
    }

    private func ordenDefault() -> [PuntoOrden] {
        [
            PuntoOrden(id: 1, hora: horaStr,
                       descripcion: L.t("Bienvenida y oración", "Welcome and prayer")),
            PuntoOrden(id: 2, hora: L.t("—", "—"),
                       descripcion: L.t("Por definir", "To be defined")),
        ]
    }
}

// MARK: - Sheet: Asignar roster

private struct AsignarRosterSheet: View {
    let servicio: Servicio
    let onGuardar: ([Int: String]) -> Void

    @State private var personas: [Int: String] = [:]
    @Environment(\.dismiss) private var dismiss

    init(servicio: Servicio, onGuardar: @escaping ([Int: String]) -> Void) {
        self.servicio = servicio
        self.onGuardar = onGuardar
        // Pre-poblar con asignaciones actuales
        var dict: [Int: String] = [:]
        for item in servicio.roster { dict[item.id] = item.persona ?? "" }
        _personas = State(initialValue: dict)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar").foregroundStyle(Paleta.brand)
                        Text("\(servicio.diaSemana) \(servicio.numDia) · \(servicio.titulo)")
                            .font(.subheadline)
                    }
                }
                Section(L.t("ROSTER", "ROSTER")) {
                    ForEach(servicio.roster) { item in
                        HStack(spacing: 12) {
                            Text(item.rol)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 100, alignment: .leading)
                            TextField(L.t("Nombre o equipo", "Name or team"),
                                      text: Binding(
                                        get: { personas[item.id] ?? "" },
                                        set: { personas[item.id] = $0 }
                                      ))
                            .font(.subheadline)
                            .autocorrectionDisabled()
                        }
                    }
                }
                Section {
                    Text(L.t("Deja el campo vacío para dejar el rol sin asignar.",
                             "Leave empty to keep the role unassigned."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L.t("Asignar roster", "Assign roster"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) {
                        onGuardar(personas)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Paleta.brand)
                }
            }
        }
    }
}

// MARK: - Sheet: Tomar asistencia

private struct TomarAsistenciaSheet: View {
    let servicio: Servicio
    let onGuardar: (Int, Int, String) -> Void

    @State private var presentes: Int
    @State private var total: Int
    @Environment(\.dismiss) private var dismiss

    private static let fmtFecha: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = L.t("d MMM", "MMM d"); f.locale = L.locale; return f
    }()

    init(servicio: Servicio, onGuardar: @escaping (Int, Int, String) -> Void) {
        self.servicio = servicio
        self.onGuardar = onGuardar
        let ultimo = servicio.historial.last
        _presentes = State(initialValue: ultimo?.presentes ?? 0)
        _total     = State(initialValue: ultimo?.total ?? max(servicio.roster.count * 10, 140))
    }

    private var pct: Double { total > 0 ? Double(presentes) / Double(total) : 0 }
    private var pctColor: Color { pct >= 0.85 ? Paleta.brand : (pct >= 0.65 ? Paleta.aviso : Paleta.negativo) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Encabezado del servicio
                    VStack(spacing: 4) {
                        Text(servicio.titulo).font(.headline)
                        Text("\(servicio.diaSemana) \(servicio.numDia) · \(servicio.hora)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Contador grande de presentes
                    VStack(spacing: 8) {
                        Text(L.t("PRESENTES", "PRESENT"))
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("\(presentes)")
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(pctColor)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.25), value: presentes)

                        // Barra de porcentaje
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 8)
                                Capsule().fill(pctColor)
                                    .frame(width: g.size.width * CGFloat(pct), height: 8)
                                    .animation(.spring(duration: 0.3), value: pct)
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, Esp.tarjeta)

                        Text("\(Int(pct * 100))% \(L.t("de", "of")) \(total) \(L.t("en roster", "in roster"))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    // Botones +/−
                    HStack(spacing: 32) {
                        botonConteo(icono: "minus", accion: { if presentes > 0 { presentes -= 1 } })
                        botonConteo(icono: "plus",  accion: { presentes += 1 })
                    }

                    Divider()

                    // Total en roster
                    Tarjeta {
                        HStack {
                            Text(L.t("Total en roster", "Total in roster"))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 12) {
                                Button { if total > 1 { total -= 1 } } label: {
                                    Image(systemName: "minus.circle").font(.title3).foregroundStyle(Paleta.brand)
                                }
                                Text("\(total)")
                                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                                    .frame(minWidth: 36)
                                Button { total += 1 } label: {
                                    Image(systemName: "plus.circle").font(.title3).foregroundStyle(Paleta.brand)
                                }
                            }
                        }
                    }

                    // Historial reciente
                    if !servicio.historial.isEmpty {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 0) {
                                TituloSeccion(texto: L.t("ÚLTIMAS ENTRADAS", "RECENT ENTRIES"))
                                    .padding(.bottom, 10)
                                ForEach(servicio.historial.suffix(4).reversed()) { a in
                                    HStack {
                                        Text(a.fecha).font(.subheadline).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(a.presentes)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Paleta.brand)
                                            .monospacedDigit()
                                        Text("/ \(a.total)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 7)
                                    if a.id != servicio.historial.first?.id { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(Esp.panel)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("Tomar asistencia", "Take attendance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Registrar", "Record")) {
                        let fecha = Self.fmtFecha.string(from: Date())
                        onGuardar(presentes, total, fecha)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Paleta.brand)
                    .disabled(presentes == 0)
                }
            }
        }
    }

    private func botonConteo(icono: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Image(systemName: icono)
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Paleta.brand, in: Circle())
                .shadow(color: Paleta.brand.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
