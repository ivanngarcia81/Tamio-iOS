import SwiftUI

struct ServiciosView: View {
    @State private var vm = ServiciosViewModel()
    @State private var abierto: Servicio?
    /// **Una sola hoja y no cuatro apiladas.** Varios `.sheet` sobre la misma
    /// vista no conviven: se abre la que SwiftUI decida, y la que se añadió
    /// aquí no llegaba a presentarse. Es el patrón que Ingresos ya usa.
    @State private var hoja: HojaServicio?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private enum HojaServicio: Identifiable {
        case nuevo
        case asignar
        case contar
        /// El culto cuya lista se toma. **Puente hasta que Servicios lea la
        /// v16**: hoy esta pantalla corre sobre servicios de maqueta, que no
        /// tienen fila en `servicio`, así que se coge el culto real más
        /// reciente. Cuando Servicios se siente sobre la tabla, el culto será
        /// el de la fila y esto se cae solo.
        case lista(CultoConLista)

        var id: String {
            switch self {
            case .nuevo:   return "nuevo"
            case .asignar: return "asignar"
            case .contar:  return "contar"
            case .lista(let c): return "lista-\(c.id)"
            }
        }
    }

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
                Button { hoja = .nuevo } label: {
                    Label(L.t("Nuevo", "New"), systemImage: "plus")
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)
            }
        }
        .task { await vm.cargar() }
        .sheet(item: $hoja) { cual in
            switch cual {
            case .nuevo:
                NuevoServicioSheet(proximoId: vm.proximoId) { vm.agregarServicio($0) }
            case .asignar:
                if let s = vm.seleccion {
                    AsignarRosterSheet(servicio: s) { personas in
                        vm.actualizarRoster(servicioId: s.id, personas: personas)
                    }
                }
            case .contar:
                if let s = vm.seleccion {
                    TomarAsistenciaSheet(servicio: s) { presentes, total, fecha in
                        vm.registrarAsistencia(servicioId: s.id, presentes: presentes,
                                               total: total, fecha: fecha)
                    }
                }
            case .lista(let culto):
                if let s = vm.seleccion {
                    ListaAsistenciaSheet(culto: culto) { presentes, total, fecha in
                        vm.registrarAsistencia(servicioId: s.id, presentes: presentes,
                                               total: total, fecha: fecha)
                    }
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
                    // La fecha completa, no "23 de agosto" con el mes escrito
                    // a mano: el culto puede ser de cualquier mes.
                    Text(s.fechaLegible)
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                // Botones de acción
                HStack(spacing: 10) {
                    // Pintados a mano: el primario iba con `Paleta.brand` de
                    // fondo y el texto en blanco, los mismos ~2.4:1 en oscuro
                    // que se quitaron del resto de la app. Ahora son botones de
                    // verdad, con el estilo que ya llevan los demás: glass con
                    // el verde de marca el que actúa, glass en gris el otro.
                    // **Dos cosas distintas.** "Tomar lista" abre el padrón
                    // agrupado en familias y guarda una fila por persona, que
                    // es de donde salen la racha y las ausencias. "Contar" es
                    // el conteo de cabezas de siempre, para el culto donde no
                    // se pasa lista.
                    Button { if let c = vm.cultoDeLaSeleccion { hoja = .lista(c) } } label: {
                        Text(L.t("Tomar lista", "Take attendance"))
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.glass).tint(Color.secondary)
                    .disabled(vm.cultoDeLaSeleccion == nil)
                    Button { hoja = .contar } label: {
                        Text(L.t("Contar", "Count"))
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.glass).tint(Color.secondary)
                    Button { hoja = .asignar } label: {
                        Text(L.t("Asignar", "Assign"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.glass).tint(Paleta.brand)
                    Spacer()
                }

                // Roster
                Tarjeta {
                    VStack(alignment: .leading, spacing: 0) {
                        TituloSeccion(texto: L.t("ROSTER", "ROSTER"))
                            .padding(.bottom, 12)
                        ForEach(s.puestos) { item in
                            HStack(spacing: 12) {
                                Text(item.etiqueta)
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
                            if item.id != s.puestos.last?.id { Divider() }
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
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(punto.titulo).font(.subheadline)
                                    // Quién lo hace, si está puesto: el
                                    // servidor lo guarda y no se enseñaba.
                                    if !punto.encargado.isEmpty {
                                        Text(punto.encargado)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
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
    /// La CLAVE del tipo de culto, no su etiqueta: es lo que se guarda y lo
    /// que decide qué puestos lleva. Con la etiqueta traducida, en inglés no
    /// acertaba ninguna rama.
    @State private var tipoClave = "dominical"
    @State private var fecha = Date()
    @State private var horaStr = "10:00"
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
        .hojaFormulario()
    }

    // MARK: - Sections

    @ViewBuilder
    private var seccionServicio: some View {
        Section(L.t("INFORMACIÓN DEL SERVICIO", "SERVICE INFORMATION")) {
            DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
            Picker(L.t("Tipo de servicio", "Service type"), selection: $tipoClave) {
                ForEach(Cultos.tipos, id: \.self) { Text(Cultos.etiqueta($0)).tag($0) }
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
        var srv = Servicio(id: proximoId)
        srv.fecha = Fechas.claveDia(fecha)
        srv.tipo = tipoClave
        srv.dirige = lidero
        srv.predica = predico
        srv.participaciones = cancionItems.map(\.texto)
        srv.tituloMensaje = tituloMensaje
        srv.textoBiblico = textoBiblico
        srv.resumenMensaje = resumenMensaje
        srv.temaEscuela = temaEscuela
        srv.maestroEscuela = maestroEscuela
        srv.eventos = eventosEspeciales
        srv.visitantes = visitanteItems.map { VisitanteServicio(nombre: $0.nombre) }
        srv.ninos = ninos
        srv.jovenes = jovenes
        srv.adultos = adultos
        srv.puestos = puestosDefault()
        srv.orden = ordenDefault()
        if headcountTotal > 0 {
            srv.historial = [AsistenciaServicio(id: srv.id, fecha: Fechas.diaLegible(srv.fecha),
                                                presentes: headcountTotal, total: headcountTotal)]
        }
        return srv
    }

    /// Los puestos que suele llevar cada tipo de culto. **Claves, no
    /// etiquetas**: antes se comparaba `tipo` contra el nombre traducido del
    /// culto, así que en inglés no acertaba ninguna rama y todos los cultos
    /// salían con el roster de "por defecto".
    private func puestosDefault() -> [PuestoServicio] {
        let claves: [String]
        switch tipoClave {
        case "dominical", "evangelistico", "especial":
            claves = ["predicacion", "alabanza", "ujieres", "ofrenda", "sonido"]
        case "oracion":
            claves = ["oracion"]
        case "estudio":
            claves = ["predicacion"]
        default:
            claves = ["predicacion", "alabanza"]
        }
        return claves.map { PuestoServicio(id: UUID().uuidString, puesto: $0, nombre: "", miembroId: nil) }
    }

    private func ordenDefault() -> [PuntoOrden] {
        [PuntoOrden(id: UUID().uuidString, posicion: 0, hora: horaStr,
                    titulo: L.t("Bienvenida y oración", "Welcome and prayer"), encargado: "")]
    }
}

// MARK: - Sheet: Asignar roster

private struct AsignarRosterSheet: View {
    let servicio: Servicio
    let onGuardar: ([String: String]) -> Void

    @State private var personas: [String: String] = [:]
    @Environment(\.dismiss) private var dismiss

    init(servicio: Servicio, onGuardar: @escaping ([String: String]) -> Void) {
        self.servicio = servicio
        self.onGuardar = onGuardar
        _personas = State(initialValue: Dictionary(
            servicio.puestos.map { ($0.id, $0.nombre) }, uniquingKeysWith: { a, _ in a }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar").foregroundStyle(Paleta.brand)
                        Text("\(servicio.fechaLegible) · \(servicio.titulo)")
                            .font(.subheadline)
                    }
                }
                Section(L.t("ROSTER", "ROSTER")) {
                    ForEach(servicio.puestos) { item in
                        HStack(spacing: 12) {
                            Text(item.etiqueta)
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
                    .buttonStyle(.glassProminent)
                    .tint(Paleta.brand)
                }
            }
        }
        .hojaFormulario()
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
        _total     = State(initialValue: ultimo?.total ?? 140)
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
                        Text(servicio.fechaLegible)
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
        .hojaFormulario()
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

// MARK: - Sheet: Tomar lista

/// **La lista del culto, con las familias plegadas.**
///
/// Una fila por familia —"Hernández Ríos · 3"— con su casilla: la familia
/// llega junta y se marca de un toque. Desplegando, cada uno con la suya, para
/// el domingo en que el mayor se quedó en casa. Quien no tiene parentescos
/// sale como familia de uno y se ve igual que los demás: la lista no tiene que
/// distinguir dos casos.
///
/// Lo que se guarda es una fila por PERSONA, aunque se marque por familia. La
/// racha, la última visita y el aviso de ausencias son de cada uno.
struct ListaAsistenciaSheet: View {
    @State private var vm: ListaAsistenciaViewModel
    let onGuardado: (Int, Int, String) -> Void

    @Environment(\.dismiss) private var dismiss

    init(culto: CultoConLista, onGuardado: @escaping (Int, Int, String) -> Void) {
        _vm = State(initialValue: ListaAsistenciaViewModel(culto: culto))
        self.onGuardado = onGuardado
    }

    private var pctColor: Color {
        vm.pct >= 0.85 ? Paleta.brand : (vm.pct >= 0.65 ? Paleta.aviso : Paleta.negativo)
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.cargando {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.familias.isEmpty {
                    ContentUnavailableView(L.t("El padrón está vacío", "The roster is empty"),
                                           systemImage: "person.2.slash",
                                           description: Text(L.t("Da de alta a alguien en Membresía para poder tomar lista.",
                                                                 "Add someone in Membership to take attendance.")))
                } else {
                    lista
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { contador }
            .navigationTitle(Cultos.etiqueta(vm.culto.tipo))
            .navigationSubtitle(Fechas.diaLegible(vm.culto.fecha))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.busqueda,
                        prompt: Text(L.t("Buscar por nombre", "Search by name")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) {
                        let (p, t) = (vm.presentes, vm.total)
                        Task { await vm.guardar() }
                        onGuardado(p, t, Fechas.diaLegible(vm.culto.fecha))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                    .tint(Paleta.brand)
                }
            }
            .task { await vm.cargar() }
        }
    }

    /// Cuántos van, sin tener que contar filas. Va en una capa con material y
    /// la lista corre por debajo, como en el resto de la app.
    private var contador: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(vm.presentes)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(pctColor)
                    .contentTransition(.numericText())
                Text(L.t("de \(vm.total) en el padrón", "of \(vm.total) on the roster"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(vm.pct * 100))%")
                    .font(.title3.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(pctColor)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill)).frame(height: 6)
                    Capsule().fill(pctColor)
                        .frame(width: g.size.width * CGFloat(vm.pct), height: 6)
                }
            }
            .frame(height: 6)
            .animation(.spring(duration: 0.3), value: vm.pct)
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
        .background(.regularMaterial)
    }

    private var lista: some View {
        List {
            ForEach(vm.familiasVisibles) { f in
                Section {
                    filaFamilia(f)
                    // Una familia de uno no despliega nada: su fila ES la
                    // persona, y su casilla la marca.
                    if vm.desplegadas.contains(f.id) {
                        ForEach(f.integrantes) { m in filaPersona(m) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    @ViewBuilder
    private func filaFamilia(_ f: Familia) -> some View {
        let marcados = vm.presentesDe(f)
        let todos = marcados == f.integrantes.count
        HStack(spacing: 12) {
            Button { withAnimation(.snappy(duration: 0.2)) { vm.alternarFamilia(f) } } label: {
                Image(systemName: todos ? "checkmark.circle.fill"
                                        : (marcados > 0 ? "circle.badge.minus" : "circle"))
                    .font(.title2)
                    .foregroundStyle(todos ? Paleta.brand : (marcados > 0 ? Paleta.aviso : .secondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(f.titulo)

            VStack(alignment: .leading, spacing: 2) {
                Text(f.titulo).font(.subheadline.weight(.medium)).lineLimit(1)
                if !f.esIndividual {
                    Text(marcados == 0
                         ? L.t("Nadie marcado", "None marked")
                         : L.t("\(marcados) de \(f.integrantes.count)", "\(marcados) of \(f.integrantes.count)"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 6)

            if !f.esIndividual {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        if vm.desplegadas.contains(f.id) { vm.desplegadas.remove(f.id) }
                        else { vm.desplegadas.insert(f.id) }
                    }
                } label: {
                    Image(systemName: vm.desplegadas.contains(f.id) ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t("Ver a cada uno", "Show each person"))
            }
        }
        .padding(.vertical, 8)
        .filaDeLista(seleccionada: false, tarjeta: true)
    }

    private func filaPersona(_ m: Miembro) -> some View {
        let presente = vm.estaPresente(m.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button { withAnimation(.snappy(duration: 0.2)) { vm.alternar(m.id) } } label: {
                    Image(systemName: presente ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(presente ? Paleta.brand : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(m.nombre)
                Text(m.nombre).font(.subheadline).lineLimit(1)
                Spacer(minLength: 6)
            }
            // La razón solo tiene sentido para quien no vino, y por eso no se
            // dibuja para quien sí.
            if !presente {
                HStack(spacing: 8) {
                    Menu {
                        Button { vm.ponerRazon(m.id, "") } label: {
                            Text(L.t("Sin razón", "No reason"))
                        }
                        Divider()
                        ForEach(AsistenciaFila.razones, id: \.self) { r in
                            Button { vm.ponerRazon(m.id, r) } label: {
                                Text(AsistenciaFila.etiquetaRazon(r))
                            }
                        }
                    } label: {
                        let r = vm.marcas[m.id]?.razon ?? ""
                        HStack(spacing: 4) {
                            Text(r.isEmpty ? L.t("¿Por qué faltó?", "Why absent?")
                                           : AsistenciaFila.etiquetaRazon(r))
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .tint((vm.marcas[m.id]?.razon.isEmpty ?? true) ? nil : Paleta.brand)

                    Button { vm.alternarSeguimiento(m.id) } label: {
                        Label(L.t("Seguimiento", "Follow-up"), systemImage: "flag")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .tint(vm.marcas[m.id]?.seguimiento == true ? Paleta.aviso : nil)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 34)
            }
        }
        .padding(.vertical, 6)
        .filaDeLista(seleccionada: false, tarjeta: true)
    }
}
