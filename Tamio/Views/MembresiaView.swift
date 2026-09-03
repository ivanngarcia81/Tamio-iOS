import SwiftUI

struct MembresiaView: View {
    @State private var vm = MembresiaViewModel()
    @State private var abierto: Miembro?
    @State private var subtab = 0        // 0 Miembros · 1 Asistencia · 2 Seguimiento
    @State private var mostrarNuevo = false
    @State private var miembroAEditar: Miembro?
    @State private var miembroParaSeguimiento: Miembro?
    @State private var mostrarFiltros = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 640 {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: 340)
                        .background(.regularMaterial)
                    Divider()
                    panelDerecho
                }
            } else {
                listaColumna
                    .background(.regularMaterial)
                    .navigationDestination(item: $abierto) { m in
                        MiembroDetalle(miembro: m, resumen: vm.resumen,
                                       onEditar: { miembroAEditar = m },
                                       onSeguimiento: { miembroParaSeguimiento = m })
                            .background(Color(.systemGroupedBackground))
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Membresía", "Membership"),
                       L.t("Padrón, altas, bajas y traslados", "Roster, additions, removals & transfers"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNuevo = true } label: {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text(L.t("Nuevo", "New")) }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
        }
        .task { await vm.cargar() }
        .onChange(of: subtab) { _, nuevo in
            vm.sincronizarSeleccion(enSeguimiento: nuevo == 2)
        }
        .sheet(isPresented: $mostrarFiltros) { filtrosSheet }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoMiembroSheet(proximoId: vm.proximoId) { nuevo in
                vm.agregarMiembro(nuevo)
            }
        }
        .sheet(item: $miembroAEditar) { m in
            NuevoMiembroSheet(proximoId: m.id, miembroExistente: m) { editado in
                vm.editarMiembro(editado)
            }
        }
        .sheet(item: $miembroParaSeguimiento) { m in
            SeguimientoSheet(miembro: m) { nota in
                vm.agregarSeguimiento(miembroId: m.id, nota: nota)
            }
        }
    }

    // MARK: - Panel derecho según pestaña

    @ViewBuilder
    private var panelDerecho: some View {
        switch subtab {
        case 1:
            if let a = vm.asistencia {
                PanelAsistencia(asistencia: a, masConstantes: vm.masConstantes, ausentes: vm.itemsAusentes)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
        default:
            let listActiva = subtab == 2 ? vm.itemsSeguimiento : vm.itemsFiltrados
            if let m = listActiva.first(where: { $0.id == vm.seleccionId }) ?? listActiva.first {
                MiembroDetalle(miembro: m, resumen: vm.resumen,
                               onEditar: { miembroAEditar = m },
                               onSeguimiento: { miembroParaSeguimiento = m })
            } else {
                ContentUnavailableView(L.t("Selecciona un miembro", "Select a member"),
                                       systemImage: "person.crop.circle")
                    .background(Color(.systemGroupedBackground))
            }
        }
    }

    // MARK: - Columna izquierda

    private var listaColumna: some View {
        VStack(spacing: 0) {
            // Picker + buscador + chips
            VStack(spacing: 10) {
                Picker(L.t("Vista", "View"), selection: $subtab) {
                    Text(L.t("Miembros", "Members")).tag(0)
                    Text(L.t("Asistencia", "Attendance")).tag(1)
                    Text(L.t("Seguimiento", "Follow-up")).tag(2)
                }
                .pickerStyle(.segmented)

                if subtab != 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(L.t("Buscar por nombre o correo", "Search by name or email"),
                                  text: $vm.busqueda).textFieldStyle(.plain)
                        if !vm.busqueda.isEmpty {
                            Button { vm.busqueda = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))

                    HStack(spacing: 8) {
                        Menu {
                            Button { vm.filtroAño = nil } label: {
                                if vm.filtroAño == nil { Label(L.t("Todos los años", "All years"), systemImage: "checkmark") }
                                else { Text(L.t("Todos los años", "All years")) }
                            }
                            Divider()
                            ForEach(vm.añosDisponibles, id: \.self) { año in
                                Button { vm.filtroAño = año } label: {
                                    if vm.filtroAño == año { Label(String(año), systemImage: "checkmark") }
                                    else { Text(String(año)) }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(vm.filtroAño.map { L.t("Año \(String($0))", "Year \(String($0))") } ?? L.t("Todos los años", "All years"))
                                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(vm.filtroAño != nil ? Paleta.brand : .primary)
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(Capsule().fill(vm.filtroAño != nil ? Paleta.brandFill : Color(.secondarySystemFill)))
                            .overlay(Capsule().stroke(vm.filtroAño != nil ? Paleta.brandStroke : Color.clear, lineWidth: 1))
                        }

                        Spacer()

                        Button { mostrarFiltros = true } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "line.3.horizontal.decrease")
                                Text(L.t("Más filtros", "More filters"))
                                if filtrosActivos > 0 {
                                    Text("\(filtrosActivos)")
                                        .font(.caption2.weight(.bold)).foregroundStyle(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Paleta.brand, in: Circle())
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(filtrosActivos > 0 ? Paleta.brand : .primary)
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(Capsule().fill(filtrosActivos > 0 ? Paleta.brandFill : Color(.secondarySystemFill)))
                            .overlay(Capsule().stroke(filtrosActivos > 0 ? Paleta.brandStroke : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            Divider()

            listaActiva

            Divider()
            HStack {
                let total = subtab == 2 ? vm.itemsSeguimiento.count : vm.itemsFiltrados.count
                let roster = vm.items.count
                let hayFiltros = subtab != 2 && (vm.filtroAño != nil || filtrosActivos > 0 || !vm.busqueda.isEmpty)
                let totalStr = subtab == 2
                    ? L.t("\(total) de \(roster) miembros", "\(total) of \(roster) members")
                    : hayFiltros
                        ? L.t("\(total) de \(roster) en el padrón", "\(total) of \(roster) on the roster")
                        : L.t("\(roster) miembros en el padrón", "\(roster) members on the roster")
                Text(totalStr)
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .colchonInferior()
    }

    @ViewBuilder
    private var listaActiva: some View {
        if subtab == 2 && vm.itemsSeguimiento.isEmpty {
            ContentUnavailableView(L.t("Sin alertas", "No alerts"),
                                   systemImage: "checkmark.circle",
                                   description: Text(L.t("Todos los miembros están al corriente.", "All members are up to date.")))
        } else if sizeClass == .regular {
            listaActivaCuerpo.listStyle(.plain)
        } else {
            listaActivaCuerpo.listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var listaActivaCuerpo: some View {
        let rowBG: Color = sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)
        List {
            if subtab == 2 {
                ForEach(vm.itemsSeguimiento) { m in
                    filaSeguimiento(m)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(rowBG)
                        .contentShape(Rectangle())
                        .onTapGesture { abrir(m) }
                }
            } else {
                ForEach(vm.itemsFiltrados) { m in
                    filaMiembro(m)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(rowBG)
                        .contentShape(Rectangle())
                        .onTapGesture { abrir(m) }
                }
            }
        }
    }

    // MARK: - Filas de lista

    private func filaMiembro(_ m: Miembro) -> some View {
        let esSel = m.id == vm.seleccionId
        return HStack(spacing: 12) {
            Text(m.iniciales)
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(m.estado.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(m.nombre).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(m.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                if m.estado != .baja {
                    Text("\(m.asistenciaPct)%")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(colorPct(m.asistenciaPct))
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.secondary)
                }
                Pill(texto: m.estado.etiqueta, color: m.estado.color)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(esSel ? Paleta.brandFill : Color.clear)
        .overlay(alignment: .leading) {
            if esSel { Rectangle().fill(Paleta.brand).frame(width: 3) }
        }
    }

    private func filaSeguimiento(_ m: Miembro) -> some View {
        let esSel = m.id == vm.seleccionId
        return HStack(spacing: 12) {
            Text(m.iniciales)
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(m.estado.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(m.nombre).font(.subheadline.weight(.medium)).lineLimit(1)
                if let razon = m.seguimientoRazon {
                    Text(razon).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(m.asistenciaPct)%")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(colorPct(m.asistenciaPct))
                Pill(texto: m.estado.etiqueta, color: m.estado.color)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(esSel ? Paleta.brandFill : Color.clear)
        .overlay(alignment: .leading) {
            if esSel { Rectangle().fill(Paleta.brand).frame(width: 3) }
        }
    }

    // MARK: - Helpers

    private var filtrosActivos: Int {
        (vm.filtroEstado != nil ? 1 : 0) + (vm.filtroMinisterio != nil ? 1 : 0)
    }

    private var filtrosSheet: some View {
        NavigationStack {
            List {
                Section(L.t("ESTADO", "STATUS")) {
                    filaFiltro(L.t("Todos", "All"), activo: vm.filtroEstado == nil) {
                        vm.filtroEstado = nil
                    }
                    ForEach([EstadoMiembro.activo, .nuevo, .recibido, .traslado, .baja], id: \.self) { e in
                        filaFiltro(e.etiqueta, activo: vm.filtroEstado == e) { vm.filtroEstado = e }
                    }
                }
                if !vm.ministeriosDisponibles.isEmpty {
                    Section(L.t("MINISTERIO", "MINISTRY")) {
                        filaFiltro(L.t("Todos", "All"), activo: vm.filtroMinisterio == nil) {
                            vm.filtroMinisterio = nil
                        }
                        ForEach(vm.ministeriosDisponibles, id: \.self) { min in
                            filaFiltro(min, activo: vm.filtroMinisterio == min) { vm.filtroMinisterio = min }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L.t("Filtros", "Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t("Limpiar", "Clear")) {
                        vm.filtroEstado = nil
                        vm.filtroMinisterio = nil
                    }
                    .foregroundStyle(filtrosActivos > 0 ? Paleta.brand : .secondary)
                    .disabled(filtrosActivos == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("Listo", "Done")) { mostrarFiltros = false }
                        .fontWeight(.semibold).foregroundStyle(Paleta.brand)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Una opción de la hoja de filtros. Va con `.buttonStyle(.plain)`: sin él,
    /// el estilo automático del `Button` dentro del `List` pinta el label con
    /// el tint heredado del TabView, por encima del `.foregroundStyle(.primary)`
    /// que ya llevaba escrito, y las seis opciones salían en verde de marca
    /// —también las NO seleccionadas—, así que no se distinguía lo elegido de
    /// lo disponible. La palomita queda como único indicador.
    private func filaFiltro(_ texto: String, activo: Bool,
                            _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text(texto).foregroundStyle(.primary)
                Spacer()
                if activo {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Paleta.brand).fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func colorPct(_ p: Int) -> Color {
        p >= 85 ? Paleta.brand : (p >= 65 ? Paleta.aviso : Paleta.negativo)
    }

    private func abrir(_ m: Miembro) {
        vm.seleccionId = m.id
        abierto = m
    }
}

// MARK: - Panel congregacional de Asistencia

private struct PanelAsistencia: View {
    let asistencia: AsistenciaResumen
    let masConstantes: [Miembro]
    let ausentes: [Miembro]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                graficaMeses
                kpisAsistencia
                porTipoServicio
                masConstantesSeccion
                sinAsistirSeccion
            }
            .padding(20)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
    }

    // Gráfica de barras doble (Presentes + En roster por mes)
    private var graficaMeses: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                TituloSeccion(texto: L.t("ASISTENCIA POR SERVICIO", "ATTENDANCE BY SERVICE"))

                // Leyenda
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Paleta.brand).frame(width: 12, height: 8)
                        Text(L.t("Presentes", "Present")).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(.tertiarySystemFill)).frame(width: 12, height: 8)
                        Text(L.t("En roster", "In roster")).font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(asistencia.meses) { m in
                        VStack(spacing: 4) {
                            Text("\(m.presentes)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Paleta.brand)
                            GeometryReader { g in
                                let h = g.size.height
                                let rosterH = h  // siempre llena
                                let presentesH = h * CGFloat(m.presentes) / CGFloat(m.enRoster)
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: rosterH)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Paleta.brand)
                                        .frame(height: presentesH)
                                }
                            }
                            .frame(height: 60)
                            Text(m.mes).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // KPIs del periodo
    private var kpisAsistencia: some View {
        HStack(spacing: 12) {
            kpiCard(L.t("Promedio del periodo", "Period average"),
                    "\(asistencia.promedioPct)%",
                    L.t("del roster", "of roster"))
            kpiCard(L.t("Servicios del periodo", "Services in period"),
                    "\(asistencia.serviciosPeriodo)", "")
            kpiCard(L.t("Presentes en promedio", "Average attendance"),
                    "\(asistencia.presentesPromedio)", "")
            kpiCard(L.t("Mejor servicio", "Best service"),
                    asistencia.mejorServicio, "")
        }
    }

    private func kpiCard(_ titulo: String, _ valor: String, _ nota: String) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(valor)
                    .font(.title3.weight(.bold)).monospacedDigit()
                    .foregroundStyle(Paleta.brand)
                if !nota.isEmpty {
                    Text(nota).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Por tipo de servicio
    private var porTipoServicio: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                TituloSeccion(texto: L.t("POR TIPO DE SERVICIO", "BY SERVICE TYPE"))
                    .padding(.bottom, 12)
                ForEach(asistencia.porTipo) { t in
                    HStack {
                        Text(t.tipo).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(L.t("\(t.promedio) en promedio", "\(t.promedio) avg"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Paleta.brand)
                    }
                    .padding(.vertical, 8)
                    if t.id != asistencia.porTipo.last?.id { Divider() }
                }
            }
        }
    }

    // Los más constantes
    private var masConstantesSeccion: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                TituloSeccion(texto: L.t("LOS MÁS CONSTANTES", "MOST CONSISTENT"))
                    .padding(.bottom, 12)
                ForEach(masConstantes) { m in
                    HStack(spacing: 10) {
                        Text(m.iniciales)
                            .font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(m.estado.color, in: Circle())
                        Text(m.nombre).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(m.asistenciaPct)%")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Paleta.brand)
                    }
                    .padding(.vertical, 7)
                    if m.id != masConstantes.last?.id { Divider() }
                }
            }
        }
    }

    // Sin asistir últimamente
    private var sinAsistirSeccion: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TituloSeccion(texto: L.t("SIN ASISTIR ÚLTIMAMENTE", "RECENTLY ABSENT"))
                    Spacer()
                    Button { } label: {
                        Text(L.t("Ver seguimiento", "View follow-up"))
                            .font(.caption).foregroundStyle(Paleta.enlace)
                    }
                }
                .padding(.bottom, 12)

                if ausentes.isEmpty {
                    Text(L.t("Todos asistieron recientemente.", "Everyone attended recently."))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(ausentes) { m in
                        HStack(spacing: 10) {
                            Text(m.iniciales)
                                .font(.caption.weight(.bold)).foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(m.estado.color, in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.nombre).font(.subheadline).lineLimit(1)
                                Text(L.t("Última visita \(m.ultimaVisita)\(m.ausenciaNota ?? "")",
                                     "Last visit \(m.ultimaVisita)\(m.ausenciaNota ?? "")"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(m.rachaSinAsistir)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Paleta.negativo)
                        }
                        .padding(.vertical, 7)
                        if m.id != ausentes.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

// MARK: - Sheet de alta de nuevo miembro

private struct NuevoMiembroSheet: View {
    let proximoId: Int
    let miembroExistente: Miembro?
    let onGuardar: (Miembro) -> Void

    // QUIÉN ES
    @State private var nombre: String
    @State private var telefono: String
    @State private var correo: String

    // MEMBRESÍA
    @State private var estado: EstadoMiembro
    @State private var fechaIngreso: Date

    // Vida espiritual
    @State private var bautizadoAgua: Bool
    @State private var bautizadoEspiritu: Bool
    @State private var cursoCompletado: Bool

    // Servicio y habilidades
    @State private var ministerios: Set<String>
    @State private var ministeriosCustom: [String]
    @State private var cargos: Set<String>
    @State private var cargosCustom: [String]
    @State private var ministeriosInteres: Set<String>
    @State private var instrumentos: Set<String>
    @State private var instrumentosCustom: [String]
    @State private var habilidades: Set<String>
    @State private var habilidadesCustom: [String]
    @State private var disponibilidad: String
    @State private var interesServir: Bool

    // Datos de la persona
    @State private var tieneFechaNac: Bool
    @State private var fechaNacimiento: Date
    @State private var estadoCivil: String
    @State private var direccion: String

    // Más datos personales
    @State private var idFiscal: String
    @State private var notas: String
    @State private var iglesiaAnterior: String
    @State private var tieneRecibido: Bool
    @State private var fechaRecibido: Date

    @Environment(\.dismiss) private var dismiss

    init(proximoId: Int, miembroExistente: Miembro? = nil, onGuardar: @escaping (Miembro) -> Void) {
        self.proximoId = proximoId
        self.miembroExistente = miembroExistente
        self.onGuardar = onGuardar

        guard let m = miembroExistente else {
            _nombre = State(initialValue: "")
            _telefono = State(initialValue: "")
            _correo = State(initialValue: "")
            _estado = State(initialValue: .activo)
            _fechaIngreso = State(initialValue: Date())
            _bautizadoAgua = State(initialValue: false)
            _bautizadoEspiritu = State(initialValue: false)
            _cursoCompletado = State(initialValue: false)
            _ministerios = State(initialValue: [])
            _ministeriosCustom = State(initialValue: [])
            _cargos = State(initialValue: [])
            _cargosCustom = State(initialValue: [])
            _ministeriosInteres = State(initialValue: [])
            _instrumentos = State(initialValue: [])
            _instrumentosCustom = State(initialValue: [])
            _habilidades = State(initialValue: [])
            _habilidadesCustom = State(initialValue: [])
            _disponibilidad = State(initialValue: "")
            _interesServir = State(initialValue: false)
            _tieneFechaNac = State(initialValue: false)
            _fechaNacimiento = State(initialValue: Date())
            _estadoCivil = State(initialValue: "Sin especificar")
            _direccion = State(initialValue: "")
            _idFiscal = State(initialValue: "")
            _notas = State(initialValue: "")
            _iglesiaAnterior = State(initialValue: "")
            _tieneRecibido = State(initialValue: false)
            _fechaRecibido = State(initialValue: Date())
            return
        }

        // Pre-populate from existing member
        func d(_ es: String, _ en: String) -> String {
            m.datos.first { $0.etiqueta == L.t(es, en) }?.valor ?? ""
        }
        func flag(_ es: String, _ en: String) -> Bool {
            m.datos.contains { $0.etiqueta == L.t(es, en) && $0.valor == "✓" }
        }
        let fmt = NuevoMiembroSheet.fmtCorto

        _nombre = State(initialValue: m.nombre)
        _telefono = State(initialValue: d("Teléfono", "Phone"))
        _correo = State(initialValue: d("Correo", "Email"))
        _estado = State(initialValue: m.estado)
        let fechaIngStr = d("Fecha de ingreso", "Join date")
        _fechaIngreso = State(initialValue: fmt.date(from: fechaIngStr) ?? Date())

        _bautizadoAgua = State(initialValue: flag("Bautismo en agua", "Water baptism"))
        _bautizadoEspiritu = State(initialValue: flag("Bautismo Espíritu", "Spirit baptism"))
        _cursoCompletado = State(initialValue: flag("Curso de membresía", "Membership course"))

        let knownMin: [String] = ["Música", "Ujieres", "Enseñanza", "Evangelismo",
                                   "Niños", "Jóvenes", "Medios", "Cocina", "Mantenimiento", "Intercesión"]
        let minStr = d("Ministerios", "Ministries")
        let allMin: [String] = minStr.isEmpty ? [] : minStr.components(separatedBy: ", ")
        _ministerios = State(initialValue: Set(allMin.filter { knownMin.contains($0) }))
        _ministeriosCustom = State(initialValue: allMin.filter { !knownMin.contains($0) })

        let knownCargos: [String] = ["Diácono", "Anciano", "Maestro(a)", "Líder de jóvenes",
                                      "Líder de damas", "Líder de caballeros", "Jefe de ujieres", "Misionero(a)"]
        let cargosStr = d("Cargos", "Roles")
        let allCargos: [String] = cargosStr.isEmpty ? [] : cargosStr.components(separatedBy: ", ")
        _cargos = State(initialValue: Set(allCargos.filter { knownCargos.contains($0) }))
        _cargosCustom = State(initialValue: allCargos.filter { !knownCargos.contains($0) })

        _ministeriosInteres = State(initialValue: [])

        let knownInstr: [String] = ["Piano", "Guitarra", "Bajo", "Batería", "Percusión", "Metales", "Voz"]
        let instrStr = d("Instrumentos", "Instruments")
        let allInstr: [String] = instrStr.isEmpty ? [] : instrStr.components(separatedBy: ", ")
        _instrumentos = State(initialValue: Set(allInstr.filter { knownInstr.contains($0) }))
        _instrumentosCustom = State(initialValue: allInstr.filter { !knownInstr.contains($0) })

        let knownHab: [String] = ["Electricidad", "Plomería", "Carpintería", "Construcción",
                                   "Contabilidad", "Informática", "Diseño", "Fotografía",
                                   "Conducción", "Cocina", "Enfermería"]
        let habStr = d("Habilidades", "Skills")
        let allHab: [String] = habStr.isEmpty ? [] : habStr.components(separatedBy: ", ")
        _habilidades = State(initialValue: Set(allHab.filter { knownHab.contains($0) }))
        _habilidadesCustom = State(initialValue: allHab.filter { !knownHab.contains($0) })

        _disponibilidad = State(initialValue: "")
        _interesServir = State(initialValue: false)

        let nacStr = d("Nacimiento", "Birth date")
        _tieneFechaNac = State(initialValue: !nacStr.isEmpty)
        _fechaNacimiento = State(initialValue: nacStr.isEmpty ? Date() : (fmt.date(from: nacStr) ?? Date()))

        let ecStr = d("Estado civil", "Marital status")
        _estadoCivil = State(initialValue: ecStr.isEmpty ? "Sin especificar" : ecStr)
        _direccion = State(initialValue: d("Dirección", "Address"))

        _idFiscal = State(initialValue: d("ID fiscal", "Tax ID"))
        _notas = State(initialValue: d("Notas", "Notes"))
        _iglesiaAnterior = State(initialValue: d("Iglesia anterior", "Previous church"))

        let recStr = d("Recibido como miembro", "Received as member")
        _tieneRecibido = State(initialValue: !recStr.isEmpty)
        _fechaRecibido = State(initialValue: recStr.isEmpty ? Date() : (fmt.date(from: recStr) ?? Date()))
    }

    private var puedeGuardar: Bool { !nombre.trimmingCharacters(in: .whitespaces).isEmpty }

    private var cntVida: Int {
        (bautizadoAgua ? 1 : 0) + (bautizadoEspiritu ? 1 : 0) + (cursoCompletado ? 1 : 0)
    }
    private var cntServicio: Int {
        ministerios.count + ministeriosCustom.count + cargos.count + cargosCustom.count +
        instrumentos.count + instrumentosCustom.count + habilidades.count + habilidadesCustom.count
    }
    private var cntDatos: Int {
        (tieneFechaNac ? 1 : 0) + (estadoCivil != "Sin especificar" ? 1 : 0) + (!direccion.isEmpty ? 1 : 0)
    }
    private var cntMas: Int {
        (!idFiscal.isEmpty ? 1 : 0) + (!notas.isEmpty ? 1 : 0) +
        (!iglesiaAnterior.isEmpty ? 1 : 0) + (tieneRecibido ? 1 : 0)
    }

    private static let fmtCorto: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = L.t("d MMM yyyy", "MMM d, yyyy"); f.locale = Locale.current; return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("QUIÉN ES", "WHO THEY ARE")) {
                    TextField(L.t("Nombre completo o de familia", "Full name or family name"), text: $nombre)
                    HStack {
                        Text(L.t("Teléfono", "Phone"))
                            .foregroundStyle(.primary)
                        Text(L.t("(opcional)", "(optional)"))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Spacer()
                        TextField(L.t("Número de teléfono", "Phone number"), text: $telefono)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L.t("Correo electrónico", "Email"))
                            .foregroundStyle(.primary)
                        Text(L.t("(opcional)", "(optional)"))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Spacer()
                        TextField("correo@ejemplo.com", text: $correo)
                            .keyboardType(.emailAddress)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section(L.t("MEMBRESÍA", "MEMBERSHIP")) {
                    Picker(L.t("Estado", "Status"), selection: $estado) {
                        Text(L.t("Activo", "Active")).tag(EstadoMiembro.activo)
                        Text(L.t("Nuevo", "New")).tag(EstadoMiembro.nuevo)
                        Text(L.t("Recibido", "Received")).tag(EstadoMiembro.recibido)
                    }
                    DatePicker(L.t("Comenzó a congregarse", "Started attending"),
                               selection: $fechaIngreso, displayedComponents: .date)
                        .tint(Paleta.brand)
                }

                Section {
                    NavigationLink {
                        VidaEspiritualPage(bautizadoAgua: $bautizadoAgua,
                                           bautizadoEspiritu: $bautizadoEspiritu,
                                           cursoCompletado: $cursoCompletado)
                    } label: { badgeRow(L.t("Vida espiritual", "Spiritual life"), count: cntVida) }

                    NavigationLink {
                        ServicioHabilidadesPage(
                            ministerios: $ministerios, ministeriosCustom: $ministeriosCustom,
                            cargos: $cargos, cargosCustom: $cargosCustom,
                            ministeriosInteres: $ministeriosInteres,
                            instrumentos: $instrumentos, instrumentosCustom: $instrumentosCustom,
                            habilidades: $habilidades, habilidadesCustom: $habilidadesCustom,
                            disponibilidad: $disponibilidad, interesServir: $interesServir)
                    } label: { badgeRow(L.t("Servicio y habilidades", "Service & skills"), count: cntServicio) }

                    NavigationLink {
                        DatosPersonaPage(tieneFecha: $tieneFechaNac,
                                         fechaNacimiento: $fechaNacimiento,
                                         estadoCivil: $estadoCivil,
                                         direccion: $direccion)
                    } label: { badgeRow(L.t("Datos de la persona", "Personal data"), count: cntDatos) }

                    NavigationLink {
                        MasDatosPage(idFiscal: $idFiscal, notas: $notas,
                                     iglesiaAnterior: $iglesiaAnterior,
                                     tieneRecibido: $tieneRecibido, fechaRecibido: $fechaRecibido)
                    } label: { badgeRow(L.t("Más datos personales", "More personal data"), count: cntMas) }

                } header: {
                    Text(L.t("COMPLETAR AHORA (OPCIONAL)", "COMPLETE NOW (OPTIONAL)"))
                } footer: {
                    Text(L.t("El ID fiscal, las notas, la iglesia anterior y la fecha de recepción están aquí dentro.",
                              "Tax ID, notes, previous church, and reception date are inside."))
                }
            }
            .navigationTitle(miembroExistente != nil ? L.t("Editar miembro", "Edit member") : L.t("Nuevo miembro", "New member"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(miembroExistente != nil ? L.t("Guardar cambios", "Save changes") : L.t("Guardar", "Save")) {
                        onGuardar(construirMiembro())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(puedeGuardar ? Paleta.brand : .secondary)
                    .disabled(!puedeGuardar)
                }
            }
        }
    }

    private func badgeRow(_ titulo: String, count: Int) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }

    // MARK: - construirMiembro

    private func construirMiembro() -> Miembro {
        let fmt = Self.fmtCorto
        let fechaStr = fmt.string(from: fechaIngreso)
        let año = Calendar.current.component(.year, from: fechaIngreso)

        let todasMin = Array(ministerios) + ministeriosCustom
        let todosCargos = Array(cargos) + cargosCustom
        let todosInstr = Array(instrumentos) + instrumentosCustom
        let todosHab = Array(habilidades) + habilidadesCustom
        let areaFinal = todasMin.isEmpty ? L.t("Sin área", "No area") : todasMin.joined(separator: ", ")

        var datos: [Dato] = [
            Dato(etiqueta: L.t("Fecha de ingreso", "Join date"), valor: fechaStr),
        ]
        if !correo.isEmpty     { datos.append(Dato(etiqueta: L.t("Correo", "Email"),          valor: correo)) }
        if !telefono.isEmpty   { datos.append(Dato(etiqueta: L.t("Teléfono", "Phone"),         valor: telefono)) }
        if !direccion.isEmpty  { datos.append(Dato(etiqueta: L.t("Dirección", "Address"),      valor: direccion)) }
        if bautizadoAgua       { datos.append(Dato(etiqueta: L.t("Bautismo en agua", "Water baptism"), valor: "✓")) }
        if bautizadoEspiritu   { datos.append(Dato(etiqueta: L.t("Bautismo Espíritu", "Spirit baptism"), valor: "✓")) }
        if cursoCompletado     { datos.append(Dato(etiqueta: L.t("Curso de membresía", "Membership course"), valor: "✓")) }
        if !todasMin.isEmpty   { datos.append(Dato(etiqueta: L.t("Ministerios", "Ministries"),  valor: todasMin.joined(separator: ", "))) }
        if !todosCargos.isEmpty{ datos.append(Dato(etiqueta: L.t("Cargos", "Roles"),            valor: todosCargos.joined(separator: ", "))) }
        if !todosInstr.isEmpty { datos.append(Dato(etiqueta: L.t("Instrumentos", "Instruments"),valor: todosInstr.joined(separator: ", "))) }
        if !todosHab.isEmpty   { datos.append(Dato(etiqueta: L.t("Habilidades", "Skills"),      valor: todosHab.joined(separator: ", "))) }
        if !estadoCivil.isEmpty && estadoCivil != "Sin especificar" {
            datos.append(Dato(etiqueta: L.t("Estado civil", "Marital status"), valor: estadoCivil))
        }
        if !idFiscal.isEmpty   { datos.append(Dato(etiqueta: L.t("ID fiscal", "Tax ID"),        valor: idFiscal)) }
        if !notas.isEmpty      { datos.append(Dato(etiqueta: L.t("Notas", "Notes"),             valor: notas)) }
        if !iglesiaAnterior.isEmpty { datos.append(Dato(etiqueta: L.t("Iglesia anterior", "Previous church"), valor: iglesiaAnterior)) }
        if tieneFechaNac       { datos.append(Dato(etiqueta: L.t("Nacimiento", "Birth date"),   valor: fmt.string(from: fechaNacimiento))) }
        if tieneRecibido       { datos.append(Dato(etiqueta: L.t("Recibido como miembro", "Received as member"), valor: fmt.string(from: fechaRecibido))) }

        let expediente: [ItemExpediente] = [
            ItemExpediente(campo: L.t("Nombre y apellidos", "Full name"),    completo: true),
            ItemExpediente(campo: L.t("Teléfono", "Phone"),                  completo: !telefono.isEmpty),
            ItemExpediente(campo: L.t("Correo", "Email"),                    completo: !correo.isEmpty),
            ItemExpediente(campo: L.t("Dirección", "Address"),               completo: !direccion.isEmpty),
            ItemExpediente(campo: L.t("Bautismo", "Baptism"),                completo: bautizadoAgua),
            ItemExpediente(campo: L.t("Fecha de nacimiento", "Birth date"),  completo: tieneFechaNac),
            ItemExpediente(campo: L.t("Estado civil", "Marital status"),     completo: estadoCivil != "Sin especificar"),
        ]

        let subtitulo: String
        switch estado {
        case .recibido: subtitulo = L.t("Recibido por traslado · 0%", "Received by transfer · 0%")
        case .nuevo:    subtitulo = L.t("Nuevo · 0%", "New · 0%")
        default:        subtitulo = L.t("Ingresó \(String(año)) · \(areaFinal.lowercased()) · 0%",
                                        "Joined \(String(año)) · \(areaFinal.lowercased()) · 0%")
        }

        let movimientos: [MovMembresia]
        if let m = miembroExistente {
            movimientos = [MovMembresia(titulo: L.t("Información actualizada", "Information updated"), fecha: fechaStr)] + m.movimientos
        } else {
            let tituloAlta = estado == .recibido
                ? L.t("Recibido por traslado", "Received by transfer")
                : L.t("Alta como miembro", "Added as member")
            movimientos = [MovMembresia(titulo: tituloAlta, fecha: fechaStr)]
        }

        return Miembro(
            id: miembroExistente?.id ?? proximoId,
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            subtitulo: subtitulo,
            estado: estado,
            asistenciaPct: miembroExistente?.asistenciaPct ?? 0,
            area: areaFinal,
            miembroDesde: L.t("Ingresó \(String(año))", "Joined \(String(año))"),
            asistencia: miembroExistente?.asistencia ?? [],
            enRoster: miembroExistente?.enRoster ?? "0 de 27",
            rachaSinAsistir: miembroExistente?.rachaSinAsistir ?? L.t("0 servicios", "0 services"),
            ultimaVisita: miembroExistente?.ultimaVisita ?? "—",
            seguimientoRazon: miembroExistente?.seguimientoRazon ?? (estado == .nuevo ? L.t("Nuevo en el periodo", "New in the period") : nil),
            ausenciaNota: miembroExistente?.ausenciaNota,
            datos: datos,
            expediente: expediente,
            movimientos: movimientos,
            seguimientoNotas: miembroExistente?.seguimientoNotas ?? []
        )
    }
}

// MARK: - Sub-página: Vida espiritual

private struct VidaEspiritualPage: View {
    @Binding var bautizadoAgua: Bool
    @Binding var bautizadoEspiritu: Bool
    @Binding var cursoCompletado: Bool

    var body: some View {
        Form {
            Section {
                Toggle(L.t("Bautizado en agua", "Baptized in water"),
                       isOn: $bautizadoAgua).tint(Paleta.brand)
                Toggle(L.t("Bautizado con el Espíritu Santo", "Baptized with the Holy Spirit"),
                       isOn: $bautizadoEspiritu).tint(Paleta.brand)
                Toggle(L.t("Curso de membresía completado", "Membership course completed"),
                       isOn: $cursoCompletado).tint(Paleta.brand)
            }
        }
        .navigationTitle(L.t("Vida espiritual", "Spiritual life"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-página: Servicio y habilidades

private struct ServicioHabilidadesPage: View {
    @Binding var ministerios: Set<String>
    @Binding var ministeriosCustom: [String]
    @Binding var cargos: Set<String>
    @Binding var cargosCustom: [String]
    @Binding var ministeriosInteres: Set<String>
    @Binding var instrumentos: Set<String>
    @Binding var instrumentosCustom: [String]
    @Binding var habilidades: Set<String>
    @Binding var habilidadesCustom: [String]
    @Binding var disponibilidad: String
    @Binding var interesServir: Bool

    private let opMinisterios = ["Música", "Ujieres", "Enseñanza", "Evangelismo",
                                  "Niños", "Jóvenes", "Medios", "Cocina", "Mantenimiento", "Intercesión"]
    private let opCargos = ["Diácono", "Anciano", "Maestro(a)", "Líder de jóvenes",
                             "Líder de damas", "Líder de caballeros", "Jefe de ujieres", "Misionero(a)"]
    private let opInstrumentos = ["Piano", "Guitarra", "Bajo", "Batería", "Percusión", "Metales", "Voz"]
    private let opHabilidades  = ["Electricidad", "Plomería", "Carpintería", "Construcción",
                                   "Contabilidad", "Informática", "Diseño", "Fotografía",
                                   "Conducción", "Cocina", "Enfermería"]

    var body: some View {
        Form {
            ChipSection(
                titulo: L.t("MINISTERIOS EN LOS QUE SIRVE", "MINISTRIES THEY SERVE IN"),
                opciones: opMinisterios,
                seleccionados: $ministerios,
                custom: $ministeriosCustom,
                placeholder: L.t("Otro ministerio...", "Other ministry...")
            )

            ChipSection(
                titulo: L.t("CARGOS Y FUNCIONES", "ROLES & FUNCTIONS"),
                opciones: opCargos,
                seleccionados: $cargos,
                custom: $cargosCustom,
                placeholder: L.t("Otro cargo o función...", "Other role or function...")
            )

            ChipSection(
                titulo: L.t("MINISTERIOS DE INTERÉS", "MINISTRIES OF INTEREST"),
                opciones: opMinisterios,
                seleccionados: $ministeriosInteres,
                custom: .constant([]),
                placeholder: ""
            )

            ChipSection(
                titulo: L.t("INSTRUMENTOS QUE TOCA", "INSTRUMENTS PLAYED"),
                opciones: opInstrumentos,
                seleccionados: $instrumentos,
                custom: $instrumentosCustom,
                placeholder: L.t("Otro instrumento...", "Other instrument...")
            )

            ChipSection(
                titulo: L.t("OFICIOS Y HABILIDADES", "TRADES & SKILLS"),
                opciones: opHabilidades,
                seleccionados: $habilidades,
                custom: $habilidadesCustom,
                placeholder: L.t("Otro oficio o habilidad...", "Other trade or skill...")
            )

            Section {
                TextField(L.t("Disponibilidad para servir", "Availability to serve"),
                          text: $disponibilidad)
                Toggle(L.t("Interés en servir en algún ministerio", "Interested in serving"),
                       isOn: $interesServir).tint(Paleta.brand)
            }
        }
        .navigationTitle(L.t("Servicio y habilidades", "Service & skills"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-página: Datos de la persona

private struct DatosPersonaPage: View {
    @Binding var tieneFecha: Bool
    @Binding var fechaNacimiento: Date
    @Binding var estadoCivil: String
    @Binding var direccion: String

    private let estadosCiviles = ["Sin especificar", "Soltero(a)", "Casado(a)",
                                   "Unión libre", "Divorciado(a)", "Viudo(a)", "Separado(a)"]

    var body: some View {
        Form {
            Section {
                Toggle(L.t("Fecha de nacimiento conocida", "Birth date known"),
                       isOn: $tieneFecha).tint(Paleta.brand)
                if tieneFecha {
                    DatePicker(L.t("Nacimiento", "Birth"),
                               selection: $fechaNacimiento, displayedComponents: .date)
                        .tint(Paleta.brand)
                }
                Picker(L.t("Estado civil", "Marital status"), selection: $estadoCivil) {
                    ForEach(estadosCiviles, id: \.self) { Text($0).tag($0) }
                }
                TextField(L.t("Dirección (opcional)", "Address (optional)"), text: $direccion)
            } footer: {
                Text(L.t("Se pueden cambiar cuando quieras: una dirección se muda y un estado civil cambia.",
                          "These can be changed anytime."))
            }
        }
        .navigationTitle(L.t("Datos de la persona", "Personal data"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-página: Más datos personales

private struct MasDatosPage: View {
    @Binding var idFiscal: String
    @Binding var notas: String
    @Binding var iglesiaAnterior: String
    @Binding var tieneRecibido: Bool
    @Binding var fechaRecibido: Date

    var body: some View {
        Form {
            Section {
                TextField(L.t("ID fiscal (opcional)", "Tax ID (optional)"), text: $idFiscal)
                    .autocorrectionDisabled()
                TextField(L.t("Notas (opcional)", "Notes (optional)"), text: $notas)
                TextField(L.t("Iglesia anterior (si aplica)", "Previous church (if applicable)"),
                          text: $iglesiaAnterior)
                Toggle(L.t("Recibido como miembro", "Received as member"),
                       isOn: $tieneRecibido).tint(Paleta.brand)
                if tieneRecibido {
                    DatePicker(L.t("Fecha de recepción", "Reception date"),
                               selection: $fechaRecibido, displayedComponents: .date)
                        .tint(Paleta.brand)
                }
            } footer: {
                Text(L.t("(opcional — necesario para constancias deducibles)",
                          "(optional — required for deductible receipts)"))
            }
        }
        .navigationTitle(L.t("Más datos personales", "More personal data"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Componente: Sección de chips con agregar custom

private struct ChipSection: View {
    let titulo: String
    let opciones: [String]
    @Binding var seleccionados: Set<String>
    @Binding var custom: [String]
    let placeholder: String

    @State private var nuevoTexto = ""

    var body: some View {
        Section(titulo) {
            FlowLayout(spacing: 8) {
                ForEach(opciones + custom, id: \.self) { op in
                    let sel = seleccionados.contains(op)
                    Button {
                        if sel { seleccionados.remove(op) }
                        else   { seleccionados.insert(op) }
                    } label: {
                        Text(op)
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(sel ? Paleta.brand : Color(.tertiarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(sel ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            if !placeholder.isEmpty {
                HStack {
                    TextField(placeholder, text: $nuevoTexto)
                    Button(L.t("Agregar", "Add")) {
                        let txt = nuevoTexto.trimmingCharacters(in: .whitespaces)
                        guard !txt.isEmpty,
                              !opciones.contains(txt),
                              !custom.contains(txt) else { return }
                        custom.append(txt)
                        seleccionados.insert(txt)
                        nuevoTexto = ""
                    }
                    .foregroundStyle(nuevoTexto.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? .secondary : Paleta.brand)
                    .disabled(nuevoTexto.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Sheet de seguimiento pastoral

private struct SeguimientoSheet: View {
    let miembro: Miembro
    let onGuardar: (SeguimientoNota) -> Void

    @State private var tipo: TipoSeguimiento = .llamada
    @State private var fecha = Date()
    @State private var descripcion = ""
    @State private var completado = false

    @Environment(\.dismiss) private var dismiss

    private static let fmtFecha: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale.current
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text(miembro.iniciales)
                            .font(.headline.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(miembro.estado.color, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(miembro.nombre).font(.headline)
                            Text(miembro.miembroDesde).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    if let razon = miembro.seguimientoRazon {
                        Label(razon, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Paleta.aviso)
                    }
                }

                if !miembro.seguimientoNotas.isEmpty {
                    Section(L.t("HISTORIAL", "HISTORY")) {
                        ForEach(miembro.seguimientoNotas.reversed()) { n in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: n.completado ? "checkmark.circle.fill" : n.tipo.icono)
                                    .foregroundStyle(n.completado ? Paleta.brand : Color(.secondaryLabel))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(n.tipo.etiqueta).font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text(Self.fmtFecha.string(from: n.fecha))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    if !n.descripcion.isEmpty {
                                        Text(n.descripcion).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section(L.t("REGISTRAR ACCIÓN", "LOG ACTION")) {
                    Picker(L.t("Tipo", "Type"), selection: $tipo) {
                        ForEach(TipoSeguimiento.allCases, id: \.self) { t in
                            Label(t.etiqueta, systemImage: t.icono).tag(t)
                        }
                    }
                    DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
                        .tint(Paleta.brand)
                    TextField(L.t("Descripción (opcional)", "Description (optional)"),
                              text: $descripcion, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle(L.t("Acción completada", "Action completed"), isOn: $completado)
                        .tint(Paleta.brand)
                }
            }
            .navigationTitle(L.t("Seguimiento", "Follow-up"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) {
                        let nota = SeguimientoNota(
                            tipo: tipo, fecha: fecha,
                            descripcion: descripcion.trimmingCharacters(in: .whitespaces),
                            completado: completado
                        )
                        onGuardar(nota)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Paleta.brand)
                }
            }
        }
        .hojaGrande()
    }
}
