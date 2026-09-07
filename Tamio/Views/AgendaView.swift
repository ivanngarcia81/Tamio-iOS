import SwiftUI

struct AgendaView: View {
    @State private var vm = AgendaViewModel()
    @State private var mostrarNuevo = false
    @State private var diaAbierto = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Mismo criterio que Membresía, Ingresos, Aportantes y Depósitos: en el
    /// teléfono el título va en la barra —si no, queda detrás del cristal— y
    /// en iPad se queda grande.
    private var compacto: Bool { sizeClass == .compact }

    /// `L.diaSemana` existía justo para esto y había quedado sin usar en el
    /// único sitio que la necesitaba: con la app en inglés el calendario ponía
    /// "DOM LUN MAR" debajo de "August 2026" y "Today".
    private let diasSemana = ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"].map(L.diaSemana)

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    calendarioColumna
                        .frame(minWidth: 300, maxWidth: 420)
                    Divider()
                    detalleDiaColumna
                }
            } else {
                calendarioColumna
                    .navigationDestination(isPresented: $diaAbierto) {
                        detalleDiaColumna
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(
            L.t("Agenda", "Calendar"),
            "\(vm.etiquetaMes) · " + L.plural(vm.pendientesMes,
                                              es: "pendiente", en: "pending", enPlural: "pending")
        )
        // **El título grande no cabe con una barra de cristal.** Con
        // `safeAreaBar` el contenido corre por debajo de la barra, y el título
        // grande vive justo en esa franja: quedaba detrás del desvanecido,
        // gris sobre negro y sin poder leerse. Lo vio Iván en una captura,
        // rodeado con el dedo: *"el título se esconde detrás del frosted
        // glass"*.
        //
        // El arreglo NO es acortar el cristal —mide lo que mide su contenido,
        // y encogerlo apretaría los controles—: es subir el título a la barra
        // de navegación, que es lo que ya hacían Membresía, Ingresos,
        // Aportantes y Depósitos en el teléfono, y por eso a ellas no les
        // pasaba. El subtítulo se conserva: `navigationSubtitle` sigue
        // saliendo bajo el título en modo `.inline`.
        //
        // En iPad se queda `.large`: allí la barra es de la pantalla entera y
        // el título no compite con ninguna cápsula.
        .navigationBarTitleDisplayMode(compacto ? .inline : .large)
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
        .sincronizable { await vm.cargar() }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoEventoSheet(
                mesActual: vm.mesActual,
                diaInicial: vm.diaSeleccionado,
                proximoId: vm.proximoId
            ) { ev in
                Task { await vm.añadir(ev) }
            }
        }
    }

    // MARK: - Columna calendario (izquierda)

    /// **Capas, no hermanos** — la misma lección de Actas y Registro, pero
    /// aquí no era el mismo cambio mecánico: lo que se desplaza no es una
    /// lista sino una de tres vistas, y una de ellas es una rejilla.
    ///
    /// El selector, la navegación de mes y el `Divider` iban apilados con el
    /// contenido en un `VStack`, así que el calendario no corría por debajo de
    /// nada y al desplazar chocaba contra el divisor y se cortaba. Ahora esos
    /// controles son la barra y las tres vistas pasan por debajo.
    @ViewBuilder
    private var calendarioColumna: some View {
        contenidoCalendario
            .scrollEdgeEffectStyle(.soft, for: .all)
            .safeAreaBar(edge: .top, spacing: 0) { cabeceraCalendario }
            .colchonInferior()
    }

    @ViewBuilder
    private var contenidoCalendario: some View {
        switch vm.vistaActual {
        case 1:  vistaSemana
        case 2:  vistaLista
        default: vistaMes
        }
    }

    private var cabeceraCalendario: some View {
        VStack(spacing: 0) {
            selectorVista
                .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)

            navMes

            // **Los nombres de las columnas suben con la barra, y solo en
            // Mes.** Son la cabecera de la rejilla, no contenido suyo: si
            // viajan con el scroll, un mes desplazado deja de decir qué
            // columna es cuál. Semana no los necesita —cada celda lleva el
            // suyo, ver `celdaSemana`— y Lista no tiene columnas.
            if vm.vistaActual == 0 { filaDiasSemana }
        }
    }

    /// **El selector de vista, en cristal.** Era un `Picker(.segmented)`, y un
    /// segmentado dibuja su propio fondo opaco de UIKit: dentro de una barra de
    /// cristal se leía como un parche gris pegado encima en vez de como parte
    /// de la barra. Lo señaló Iván rodeándolo en una captura.
    ///
    /// **El `Picker` no se envuelve en `.glassEffect`**: su fondo es opaco y
    /// taparía el cristal, que es la misma razón por la que las bandas de
    /// `.regularMaterial` había que quitarlas y no esconderlas. Van tres
    /// cápsulas en un `GlassEffectContainer`, como los demás controles de
    /// cristal de la app, y se funden entre sí al estar cerca.
    ///
    /// Y NO es el caso de la barra de Ingresos, donde el segmentado se queda
    /// `Picker` a propósito: allí vive en el `toolbar`, y el sistema ya le pone
    /// su cápsula —glass dentro de glass—. Aquí vive en una `safeAreaBar`, que
    /// no pone ninguna.
    private var selectorVista: some View {
        GlassEffectContainer(spacing: Esp.hueco) {
            HStack(spacing: Esp.hueco) {
                ForEach(Self.vistas, id: \.0) { valor, nombre in
                    chipVista(valor, nombre)
                }
            }
        }
    }

    /// Un solo sitio con los tres nombres, como en Membresía: el selector y
    /// cualquier otra cosa que los necesite los leen de aquí.
    private static var vistas: [(Int, String)] {
        [(0, L.t("Mes", "Month")),
         (1, L.t("Semana", "Week")),
         (2, L.t("Lista", "List"))]
    }

    /// La elegida va `.glassProminent` con la marca: en un control de "elige
    /// uno", el relleno es lo único que dice cuál está activa, y sin él tres
    /// cápsulas iguales se leen como tres acciones. `isSelected` lo dice
    /// también para quien no ve el relleno.
    @ViewBuilder
    private func chipVista(_ valor: Int, _ nombre: String) -> some View {
        let activa = vm.vistaActual == valor
        if activa {
            Button { vm.vistaActual = valor } label: {
                etiquetaVista(nombre, activa: true)
            }
            .buttonStyle(.glassProminent)
            .tint(Paleta.brand)
            .accessibilityAddTraits(.isSelected)
        } else {
            Button { vm.vistaActual = valor } label: {
                etiquetaVista(nombre, activa: false)
            }
            // **El tinte a `.primary` en las NO elegidas.** `.glass` hereda el
            // tinte del TabView, así que las tres salían en verde y las tres se
            // leían como activas: la misma lección que ya dejó escrita
            // `filaFiltro` de Informes. Teñida va solo la elegida.
            //
            // Se hace con `.tint` y NO con `.foregroundStyle` en la etiqueta:
            // probado, el estilo de botón pinta por encima y el verde seguía
            // ahí. Es la palanca que ya usa Servicios.
            .buttonStyle(.glass)
            .tint(Color.primary)
        }
    }

    private func etiquetaVista(_ nombre: String, activa: Bool) -> some View {
        Text(nombre)
            .font(.subheadline.weight(activa ? .semibold : .regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
    }

    private var filaDiasSemana: some View {
        HStack(spacing: 0) {
            ForEach(diasSemana, id: \.self) { d in
                Text(d)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Esp.hueco).padding(.vertical, 4)
    }

    // MARK: - Barra de navegación de mes

    private var navMes: some View {
        HStack(spacing: 0) {
            Button { Task { await vm.irAlMesAnterior() } } label: {
                Image(systemName: "chevron.left").padding(Esp.hueco)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text(vm.etiquetaMes)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button { Task { await vm.irAHoy() } } label: {
                Text(L.t("Hoy", "Today"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Paleta.brand)
            }

            Button { Task { await vm.irAlMesSiguiente() } } label: {
                Image(systemName: "chevron.right").padding(Esp.hueco)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Esp.hueco).padding(.bottom, 4)
    }

    // MARK: - Vista Mes

    /// Sin la fila de nombres de día: esa es cabecera de la rejilla y vive en
    /// `cabeceraCalendario`, para que no se vaya al desplazar.
    private var vistaMes: some View {
        ScrollView {
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
            .padding(Esp.panel)
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
        .padding(Esp.tarjeta)
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

    /// **El mismo array otra vez.** `diasSemana` se creó para que el
    /// calendario no dijera "DOM LUN MAR" con la app en inglés, y aquí había
    /// quedado una segunda copia escrita a mano que no pasaba por
    /// `L.diaSemana`: la vista Lista seguía en español. Se lee del único sitio
    /// que tiene los nombres.
    private func etiquetaDiaLista(_ dia: Int) -> String {
        let offset = (vm.primerDiaOffset + dia - 1) % 7
        return "\(diasSemana[offset])  \(dia)"
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

    /// **El padrón de verdad.** Aquí había ocho nombres a mano que ni siquiera
    /// coincidían con los doce de Servicios ni con los cuatro de Cartas.
    @State private var padron: [PersonaDelPadron] = []

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
                    // **La etiqueta se ve, pero lo que se elige es el id.**
                    // Antes el `tag` era el nombre y eso era lo único que se
                    // guardaba: el web no podía enlazar la actividad con nadie,
                    // y el nombre se quedaba viejo en cuanto la persona
                    // cambiara de apellido.
                    Picker(L.t("Responsable", "Person in charge"), selection: $responsable) {
                        Text(L.t("— Sin asignar —", "— Unassigned —")).tag("")
                        ForEach(padron) { p in Text(p.nombre).tag(p.id) }
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
        // El padrón, al abrir la hoja: el selector de personas lo lee.
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
        .hojaFormulario()
    }

    private func guardar() {
        let horaStr: String? = todoDia ? nil : Self.fmtHora.string(from: horaInicio)
        let horaFinStr: String? = todoDia ? nil : Self.fmtHora.string(from: horaFin)
        // Lo que lleva el selector es un id del padrón, "" o "__ext__". Los
        // dos campos son excluyentes, como en el web: quien está en el padrón
        // viaja como id y quien no, como texto.
        let delPadron = padron.first { $0.id == responsable }
        let externo = responsable == "__ext__"
        let resp = externo ? L.t("Otra persona", "Other person") : (delPadron?.nombre ?? "")

        let ev = EventoAgenda(
            id: proximoId,
            // La fecha entera, no el día del mes. El selector la tenía desde
            // siempre y aquí se tiraba el mes y el año.
            fecha: Fechas.claveDia(fechaEvento),
            hora: horaStr,
            titulo: titulo.trimmingCharacters(in: .whitespaces),
            descripcion: descripcion.trimmingCharacters(in: .whitespaces),
            tipo: tipo,
            completado: false,
            todoDia: todoDia,
            horaFin: horaFinStr,
            lugar: lugar.trimmingCharacters(in: .whitespaces),
            responsable: resp,
            responsableId: delPadron?.id,
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
