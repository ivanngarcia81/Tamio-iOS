import SwiftUI
import UIKit

struct InformesMembresiaView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var vm = InformesMembresiaViewModel()
    @State private var mostrarFiltros = false
    @State private var mostrarShareCSV = false
    @State private var urlCSV: URL? = nil

    private let informes = [
        (L.t("General", "General"), L.t("Distribuciones, altas por mes y movimientos", "Distributions, monthly additions & transfers")),
        (L.t("Miembros", "Members"), L.t("Padrón del periodo con ocho recortes", "Roster for the period with eight slices")),
        (L.t("Asistencia", "Attendance"), L.t("27 servicios · 78% de asistencia general", "27 services · 78% general attendance")),
        (L.t("Seguimiento", "Follow-up"), L.t("Alertas pastorales sin revisar", "Unreviewed pastoral alerts")),
    ]
    /// **El badge cuenta las alertas de verdad.** Iba escrito a mano como `3`:
    /// la pestaña prometía tres personas que atender y al entrar salía
    /// "Próximamente". Un número inventado al lado de una pantalla vacía.
    private var alertasSeguimiento: Int { vm.alertas.count }

    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        contenidoPrincipal
            .toolbar { barra }
            .task { await vm.cargarPadron() }
            .sincronizable { await vm.cargarPadron() }
            .sheet(isPresented: $mostrarFiltros) { filtrosSheet }
            .sheet(isPresented: $mostrarShareCSV) {
                if let url = urlCSV { ShareSheet(items: [url]) }
            }
    }

    /// En iPad: columna maestra de informes a la izquierda y contenido a la
    /// derecha. En iPhone: solo el contenido, con el selector en el título.
    @ViewBuilder
    private var contenidoPrincipal: some View {
        if compacto {
            cuerpo
                .navigationBarTitleDisplayMode(.inline)
        } else {
            HStack(spacing: 0) {
                sidebarInformes
                Divider()
                cuerpo
            }
            .encabezadoNav(L.t("Informes de membresía", "Membership reports"),
                           L.t("Panorama, seguimiento e informes del padrón",
                               "Overview, follow-up & roster reports"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var cuerpo: some View {
        contenidoInforme
            .colchonInferior()
    }

    // MARK: - Barra

    /// **Dos grupos, no cinco cápsulas sueltas.** Los ítems vecinos de una
    /// toolbar comparten cápsula solos —no hay que ponerles `.glassEffect` a
    /// mano, eso daría cristal sobre cristal—, y `ToolbarSpacer` es lo que
    /// separa un grupo del siguiente. Aquí: filtros y acciones van juntos
    /// porque los dos operan sobre lo que se está viendo; compartir va aparte
    /// porque saca el informe de la app.
    ///
    /// El título es un `ToolbarItem(placement: .title)` y no texto: ver
    /// `encabezado`.
    ///
    /// Esto gasta la cápsula que `sinBotonVolver` había liberado al quitar el
    /// chevron (ver `NavHeader.swift`). Cabe: son tres ítems más el título, y
    /// esta pantalla no tiene buscador.
    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        // En iPhone el título ES el selector; en iPad la selección vive en la
        // columna izquierda y el título queda libre para la barra de navegación.
        if compacto {
            ToolbarItem(placement: .title) { menuInforme }
        }
        ToolbarItem(placement: .topBarTrailing) { botonFiltros }
        ToolbarItem(placement: .topBarTrailing) { menuAcciones }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) { botonCompartir }
    }

    // MARK: - Columna maestra (iPad)

    /// Las cuatro opciones visibles en iPad como columna fija. En el teléfono
    /// caben en un menú del título porque solo muestra una cosa a la vez; en
    /// iPad hay ancho para la lista al lado del contenido y el informe activo
    /// se ve de un vistazo sin abrir nada.
    private var sidebarInformes: some View {
        List {
            ForEach(Array(informes.enumerated()), id: \.offset) { idx, informe in
                Button { vm.informeSeleccionado = idx } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(etiquetaInforme(idx))
                            .font(.subheadline)
                            .fontWeight(vm.informeSeleccionado == idx ? .semibold : .regular)
                            .foregroundStyle(.primary)
                        Text(informe.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .filaDeLista(seleccionada: vm.informeSeleccionado == idx, tarjeta: false)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.secondarySystemGroupedBackground))
        .frame(width: Esp.columnaMaestra)
    }

    /// El informe activo, que es estado y por eso vive en el título y no en el
    /// menú de acciones: se sigue leyendo con el menú abierto.
    ///
    /// **El badge de seguimiento se va DENTRO**, a su fila. En un botón de
    /// barra el "3" tendría que verse siempre, incluso mirando otro informe,
    /// donde no significa nada; en la fila dice qué hay al otro lado antes de
    /// ir.
    private var menuInforme: some View {
        Menu {
            ForEach(Array(informes.enumerated()), id: \.offset) { idx, informe in
                Button { vm.informeSeleccionado = idx } label: {
                    if idx == vm.informeSeleccionado {
                        Label(etiquetaInforme(idx), systemImage: "checkmark")
                    } else {
                        Text(etiquetaInforme(idx))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(informes[vm.informeSeleccionado].0)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
    }

    /// El nombre del informe, con el pendiente pegado cuando lo hay. El menú
    /// no admite una vista cualquiera como etiqueta, así que el badge viaja en
    /// el texto.
    private func etiquetaInforme(_ idx: Int) -> String {
        let nombre = informes[idx].0
        guard idx == 3 && alertasSeguimiento > 0 else { return nombre }
        return "\(nombre) (\(alertasSeguimiento))"
    }

    /// **El badge solo cuando el periodo NO es el año en curso.** Un contador
    /// fijo ahí sería ruido: dice "hay filtros" cuando lo que hay es el estado
    /// de arranque. Así el punto solo aparece cuando la cifra que se está
    /// leyendo no es la del año corriente, que es justo cuando conviene mirar
    /// dos veces antes de creerse el número.
    private var botonFiltros: some View {
        Button { mostrarFiltros = true } label: {
            Label(L.t("Periodo", "Period"), systemImage: "line.3.horizontal.decrease")
        }
        // El globito cuenta el periodo Y los filtros del padrón: si solo
        // contara el periodo, una lista recortada a "los de música" no diría
        // por qué es corta, que es la lección de Ingresos.
        .tint(filtrosPuestos == 0 ? nil : Paleta.brand)
        .badge(filtrosPuestos)
    }

    private var filtrosPuestos: Int {
        (periodoEsElDeSiempre ? 0 : 1)
            + (vm.informeSeleccionado == 1 ? vm.filtrosDePadron : 0)
    }

    private var periodoEsElDeSiempre: Bool {
        vm.periodoTipo == .anio && vm.añoSeleccionado == Self.añoEnCurso
    }

    private static var añoEnCurso: Int {
        Calendar.current.component(.year, from: Date())
    }

    /// Las dos acciones, en la fila compacta de iconos que Fotos enseña arriba
    /// de su menú. Sin `.compactMenu` saldrían como dos filas normales, que es
    /// lo que eran antes.
    private var menuAcciones: some View {
        Menu {
            ControlGroup {
                Button { imprimirInforme() } label: {
                    Label(L.t("Imprimir", "Print"), systemImage: "printer")
                }
                Button { prepararCSV() } label: {
                    Label(L.t("CSV", "CSV"), systemImage: "tablecells")
                }
            }
            .controlGroupStyle(.compactMenu)
        } label: {
            Label(L.t("Más", "More"), systemImage: "ellipsis")
        }
        // Los cuatro informes están en el título, pero solo uno se puede sacar
        // de la pantalla: los otros tres no existen todavía.
        .disabled(vm.informeSeleccionado != 0)
    }

    /// Compartir el informe como texto, que es lo que se pega en un mensaje.
    /// Es otra cosa que imprimir —que va al papel— y que exportar —que da un
    /// archivo—, y por eso va en su propio grupo.
    private var botonCompartir: some View {
        ShareLink(item: vm.textoInforme) {
            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
        }
        .disabled(vm.informeSeleccionado != 0)
    }

    /// Un traslado en el teléfono: dos renglones y nada fuera de la pantalla.
    ///
    /// El folio va con la persona y no en su propia columna —es su
    /// identificador, no una categoría— y la fecha y el estado se juntan en la
    /// línea de abajo, que es donde caben. Se pierde la alineación en columnas;
    /// se gana que las cinco cosas se vean.
    private func filaTrasladoCompacta(_ t: MovimientoTraslado) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Pill(texto: t.tipoTraslado,
                 color: t.sentido == .salida ? Paleta.aviso : Paleta.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.persona).font(.subheadline.weight(.medium)).lineLimit(1)
                if !t.iglesia.isEmpty {
                    Text(t.iglesia).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text([t.folioLegible, t.fecha, t.estado]
                        .filter { !$0.isEmpty && $0 != "—" }
                        .joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers de exportación

    private func imprimirInforme() {
        let pc = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = L.t("Informe de Membresía", "Membership Report") + " \(vm.etiquetaPeriodo)"
        info.outputType = .general
        pc.printInfo = info
        pc.printFormatter = UISimpleTextPrintFormatter(text: vm.textoInforme)
        pc.present(animated: true)
    }

    private func prepararCSV() {
        let nombre = vm.etiquetaPeriodo
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Membresia-\(nombre).csv")
        try? vm.csvExportString.write(to: url, atomically: true, encoding: .utf8)
        urlCSV = url
        mostrarShareCSV = true
    }

    // MARK: - Hoja del periodo

    /// **El periodo entero en una hoja, y el rango DENTRO de ella.** Antes eran
    /// dos franjas de contenido —un menú de tipo con los años al lado y una
    /// segunda fila de meses o trimestres— más una hoja aparte solo para las
    /// dos fechas. Tres sitios para una sola pregunta.
    ///
    /// Las secciones aparecen según hagan falta: el año solo si el tipo lo usa,
    /// los doce meses solo con "Mes", los calendarios solo con "Rango". Una
    /// hoja da sitio a los doce meses; un menú los dejaría en una lista que hay
    /// que recorrer.
    /// Un filtro del padrón: `Menu` y no `Picker`, para que "Todos" pueda ser
    /// `nil` de verdad —"sin filtrar" no es una opción más del catálogo— y para
    /// que la fila diga a la vez qué filtra y por qué valor, sin abrir nada.
    private func filtroDePadron(_ titulo: String, claves: [String],
                                valor: String?,
                                _ poner: @escaping (String?) -> Void) -> some View {
        Menu {
            Button {
                poner(nil)
            } label: {
                if valor == nil { Label(L.t("Todos", "All"), systemImage: "checkmark") }
                else { Text(L.t("Todos", "All")) }
            }
            ForEach(claves, id: \.self) { c in
                Button {
                    poner(c)
                } label: {
                    if valor == c { Label(Padron.etiqueta(c), systemImage: "checkmark") }
                    else { Text(Padron.etiqueta(c)) }
                }
            }
        } label: {
            HStack {
                Text(titulo).foregroundStyle(.primary)
                Spacer()
                Text(valor.map(Padron.etiqueta) ?? L.t("Todos", "All"))
                    .foregroundStyle(valor == nil ? .secondary : Paleta.brand)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var filtrosSheet: some View {
        NavigationStack {
            List {
                // **Los del padrón van PRIMERO, y solo en su informe.** Es la
                // misma medida que ya se tomó en la hoja de Membresía: puesta
                // detrás de PERIODO y AÑO, esta sección quedaba a tres
                // arrastres —cinco periodos y ocho años por delante— de donde
                // tiene que estar a un toque. El periodo se toca una vez por
                // sesión; estos, cada pregunta.
                if vm.informeSeleccionado == 1 {
                    Section(L.t("EL PADRÓN", "THE REGISTRY")) {
                        filtroDePadron(L.t("Estado", "Status"),
                                       claves: EstadoMiembro.claves,
                                       valor: vm.filtroEstado) { vm.filtroEstado = $0 }
                        filtroDePadron(L.t("Ministerio", "Ministry"),
                                       claves: Padron.ministerios,
                                       valor: vm.filtroMinisterio) { vm.filtroMinisterio = $0 }
                        filtroDePadron(L.t("Cargo", "Role"),
                                       claves: Padron.cargos,
                                       valor: vm.filtroCargo) { vm.filtroCargo = $0 }
                        filtroDePadron(L.t("Instrumento", "Instrument"),
                                       claves: Padron.instrumentos,
                                       valor: vm.filtroInstrumento) { vm.filtroInstrumento = $0 }
                        if vm.filtrosDePadron > 0 {
                            Button(L.t("Quitar los filtros del padrón",
                                       "Clear registry filters")) {
                                vm.limpiarFiltrosDePadron()
                            }
                        }
                    }
                }
                Section(L.t("PERIODO", "PERIOD")) {
                    ForEach(PeriodoInforme.allCases, id: \.self) { p in
                        filaFiltro(p.etiqueta, activo: vm.periodoTipo == p) {
                            vm.periodoTipo = p
                        }
                    }
                }
                if periodoUsaAño {
                    Section(L.t("AÑO", "YEAR")) {
                        ForEach(Self.años, id: \.self) { año in
                            filaFiltro(String(año), activo: vm.añoSeleccionado == año) {
                                vm.añoSeleccionado = año
                            }
                        }
                    }
                }
                if vm.periodoTipo == .mes {
                    Section(L.t("MES", "MONTH")) {
                        ForEach(1...12, id: \.self) { m in
                            filaFiltro(InformesMembresiaViewModel.nombreMes(m),
                                       activo: vm.mesSeleccionado == m) {
                                vm.mesSeleccionado = m
                            }
                        }
                    }
                }
                if vm.periodoTipo == .trimestre {
                    Section(L.t("TRIMESTRE", "QUARTER")) {
                        ForEach(1...4, id: \.self) { q in
                            filaFiltro("Q\(q)", activo: vm.trimestreSeleccionado == q) {
                                vm.trimestreSeleccionado = q
                            }
                        }
                    }
                }
                if vm.periodoTipo == .rango {
                    // Lo que era `RangoSheet`. Elegir "Rango" y que se abriera
                    // OTRA hoja encima era pedir dos decisiones para una.
                    Section(L.t("FECHA INICIAL", "START DATE")) {
                        DatePicker("", selection: $vm.rangoDesde, in: ...vm.rangoHasta,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Paleta.brand)
                            .labelsHidden()
                    }
                    Section(L.t("FECHA FINAL", "END DATE")) {
                        DatePicker("", selection: $vm.rangoHasta, in: vm.rangoDesde...,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Paleta.brand)
                            .labelsHidden()
                    }
                }
            }
            // `.inset` y no `.insetGrouped`: la hoja ya es una superficie, y el
            // agrupado metería otra tarjeta con fondo dentro. Mismo criterio
            // que la hoja de filtros de Membresía.
            .listStyle(.inset)
            .navigationTitle(L.t("Periodo", "Period"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("Listo", "Done")) { mostrarFiltros = false }
                        .fontWeight(.semibold)
                        .buttonStyle(.glassProminent)
                        .tint(Paleta.brand)
                }
            }
        }
        .hojaEleccion(grande: true)
    }

    /// Una opción de la hoja. `.buttonStyle(.plain)` es obligatorio: sin él el
    /// estilo automático del `Button` dentro de un `List` pinta la etiqueta con
    /// el tint heredado del TabView y salen todas en verde —también las no
    /// elegidas—, así que no se distingue lo elegido de lo disponible. Misma
    /// lección que dejó la hoja de filtros de Membresía.
    private func filaFiltro(_ texto: String, activo: Bool,
                            _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text(texto).foregroundStyle(.primary)
                Spacer()
                if activo { Image(systemName: "checkmark").foregroundStyle(Paleta.brand) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let años = [2024, 2025, 2026]

    private var periodoUsaAño: Bool {
        vm.periodoTipo == .mes || vm.periodoTipo == .trimestre || vm.periodoTipo == .anio
    }

    // MARK: - Contenido del informe

    // MARK: - Informe de Asistencia

    // MARK: - Informe de Seguimiento

    /// **Las alertas pastorales, del padrón.** Aquí salía "Próximamente" con
    /// un badge que prometía tres. Ver `InformesMembresiaViewModel.alertas`.
    @ViewBuilder
    private var informeSeguimiento: some View {
        let alertas = vm.alertas
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("Seguimiento pastoral", "Pastoral follow-up"))
                    .font(.title3.weight(.semibold))
                Text(alertas.isEmpty
                     ? L.t("Nadie pendiente · \(vm.etiquetaPeriodo)",
                           "No one pending · \(vm.etiquetaPeriodo)")
                     : L.t("\(alertas.count) alertas · \(vm.etiquetaPeriodo)",
                           "\(alertas.count) alerts · \(vm.etiquetaPeriodo)"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if alertas.isEmpty {
                // **Vacío no es lo mismo que "no está hecho".** Un padrón al
                // corriente tiene que poder decirlo.
                ContentUnavailableView(
                    L.t("Todo al corriente", "All up to date"),
                    systemImage: "checkmark.circle",
                    description: Text(L.t("Nadie lleva servicios sin venir ni tiene el expediente a medias.",
                                          "Nobody has missed services or has an incomplete record.")))
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                // Agrupadas por motivo: quien pastorea hace una cosa cada vez
                // —llamar a los que no vienen, o completar expedientes—, no
                // recorre una lista mezclada.
                ForEach(InformesMembresiaViewModel.TipoAlerta.allCases) { tipo in
                    let delTipo = alertas.filter { $0.tipo == tipo }
                    if !delTipo.isEmpty {
                        Tarjeta {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TituloSeccion(texto: tipo.etiqueta.uppercased())
                                    Spacer()
                                    Pill(texto: "\(delTipo.count)", color: tipo.estado.color)
                                }
                                .padding(.bottom, 10)
                                ForEach(delTipo) { a in
                                    filaAlerta(a)
                                    if a.id != delTipo.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func filaAlerta(_ a: InformesMembresiaViewModel.Alerta) -> some View {
        HStack(spacing: 12) {
            Avatar(iniciales: a.miembro.nombre.split(separator: " ").prefix(2)
                                .compactMap(\.first).map(String.init).joined().uppercased(),
                   color: a.tipo.estado.color, lado: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.miembro.nombre)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Text(a.detalle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
    }

    /// Las cuatro cifras del periodo y quiénes vinieron más. Reflejado del web
    /// (`resumenAsistencia` + `topAsistencia`), con sus mismos cuatro
    /// indicadores y su mismo criterio de desempate.
    @ViewBuilder
    private var informeAsistencia: some View {
        if vm.padronCargado {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Asistencia", "Attendance"))
                        .font(.title3.weight(.semibold))
                    Text(vm.etiquetaPeriodo)
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                // **El aviso antes que las cifras**, no después: si no se tomó
                // lista, los cuatro números de abajo son ceros que no
                // significan "nadie vino".
                if vm.sinListasTomadas {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Paleta.aviso)
                        Text(L.t("Hubo \(vm.serviciosDelPeriodo) servicios y en ninguno se tomó lista. Los porcentajes salen vacíos porque falta el dato, no porque nadie viniera.",
                                 "There were \(vm.serviciosDelPeriodo) services and none has a roll call. The percentages are empty because the data is missing, not because nobody came."))
                            .font(.footnote)
                    }
                    .padding(Esp.tarjeta)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paleta.aviso.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
                }

                LazyVGrid(columns: sizeClass == .regular
                          ? [GridItem(.flexible()), GridItem(.flexible()),
                             GridItem(.flexible()), GridItem(.flexible())]
                          : [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 12) {
                    cifraAsistencia(L.t("Servicios", "Services"), "\(vm.serviciosDelPeriodo)")
                    cifraAsistencia(L.t("Asistencia total", "Total attendance"), "\(vm.asistenciaTotal)")
                    cifraAsistencia(L.t("Promedio por servicio", "Average per service"),
                                    "\(vm.promedioPorServicio)")
                    // El "—" es la verdad cuando no hay de dónde sacar el
                    // porcentaje; un 0% diría que no vino nadie.
                    cifraAsistencia(L.t("% general", "Overall %"),
                                    vm.porcentajeGeneral.map { "\($0)%" } ?? "—")
                }

                // **Aquí NO va "mejor servicio".** Sale del resumen
                // congregacional, o sea de la otra fuente, y con la maqueta
                // decía "214 · 23 ago" debajo de una asistencia total de 110:
                // otra contradicción en la misma pantalla. El web tampoco lo
                // pone en este informe. Cuando la asistencia por culto tenga
                // una fuente única, vuelve.

                Text(L.t("Los que más vinieron", "Most consistent"))
                    .font(.headline)

                let top = vm.mejoresPorAsistencia
                if top.isEmpty {
                    ContentUnavailableView(L.t("Sin asistencia registrada", "No attendance recorded"),
                                           systemImage: "person.badge.clock",
                                           description: Text(L.t("Cuando se tome lista en un culto, aquí saldrá quién vino.",
                                                                 "Once a service has a roll call, this will show who came.")))
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { i, m in
                            filaAsistencia(m)
                            if i < top.count - 1 { Divider().padding(.leading, Esp.pantalla) }
                        }
                    }
                    .background(Paleta.superficieFila,
                                in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    private func cifraAsistencia(_ etiqueta: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etiqueta)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            Text(valor)
                .font(.title2.weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.tarjeta)
        .background(Paleta.superficieFila,
                    in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
    }

    /// La fila del top dice las tres cosas que explican el porcentaje: cuántos
    /// de cuántos, cuándo vino la última vez, y el porcentaje. Sin las dos
    /// primeras, un 100% de un culto y un 100% de veintisiete se leen igual.
    private func filaAsistencia(_ m: Miembro) -> some View {
        HStack(spacing: 12) {
            Avatar(iniciales: m.iniciales, color: m.estado.color, lado: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.nombre).font(.subheadline).lineLimit(1)
                Text(m.enRoster + (m.asistenciaResumen?.ultimaVisita.map {
                    " · " + L.t("última: ", "last: ") + Fechas.diaLegible($0)
                } ?? ""))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text("\(m.asistenciaPct)%")
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(Paleta.porcentajeAsistencia(m.asistenciaPct))
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
    }

    // MARK: - Informe de Miembros

    /// **Las ocho cifras del padrón, y cada una filtra la lista de abajo.**
    /// Reflejado del web, incluida su decisión para el teléfono: allí las ocho
    /// pasaron de rejilla de tarjetas a lista agrupada porque *"ocho tarjetas
    /// de media pantalla eran ~900px de resumen antes de la primera fila del
    /// registro"*. La misma razón vale aquí, y es además la lección que ya
    /// dejó escrita `MiembroDetalle` al perder estos mismos ocho.
    ///
    /// En iPad sí van en rejilla: hay ancho, y el informe se lee de un vistazo.
    @ViewBuilder
    private var informeMiembros: some View {
        if vm.padronCargado {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Padrón", "Member registry"))
                        .font(.title3.weight(.semibold))
                    Text("\(vm.cuenta(.todos)) \(L.t("miembros · \(vm.etiquetaPeriodo)", "members · \(vm.etiquetaPeriodo)"))")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                if sizeClass == .regular {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                        GridItem(.flexible()), GridItem(.flexible())],
                              spacing: 12) {
                        ForEach(TarjetaPadron.allCases) { t in tarjetaPadron(t) }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(TarjetaPadron.allCases.enumerated()), id: \.element.id) { i, t in
                            filaPadron(t)
                            if i < TarjetaPadron.allCases.count - 1 {
                                Divider().padding(.leading, Esp.pantalla)
                            }
                        }
                    }
                    .background(Paleta.superficieFila,
                                in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
                }

                // **Lo que está filtrando, dicho en palabras.** Es del web, y
                // por la misma razón: con solo una tarjeta teñida hay que
                // deducir por qué la lista es corta, y una lista corta sin
                // explicación es la lección que ya dejó Ingresos.
                if vm.tarjeta != .todos {
                    HStack(spacing: 8) {
                        Text(L.t("Filtrando por \(vm.tarjeta.etiqueta)",
                                 "Filtered by \(vm.tarjeta.etiqueta)"))
                            .font(.subheadline)
                        Spacer()
                        Button(L.t("Quitar", "Clear")) { vm.tarjeta = .todos }
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
                    .background(Paleta.brandFill,
                                in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
                }

                let filas = vm.miembrosFiltrados
                Text(L.t("\(filas.count) de \(vm.cuenta(.todos))", "\(filas.count) of \(vm.cuenta(.todos))"))
                    .font(.caption).foregroundStyle(.secondary)

                if filas.isEmpty {
                    ContentUnavailableView(L.t("Nadie en este recorte", "No one in this slice"),
                                           systemImage: "person.slash",
                                           description: Text(L.t("Quita el filtro para ver el padrón entero.",
                                                                 "Clear the filter to see the whole registry.")))
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filas.enumerated()), id: \.element.id) { i, m in
                            filaMiembroInforme(m)
                            if i < filas.count - 1 { Divider().padding(.leading, Esp.pantalla) }
                        }
                    }
                    .background(Paleta.superficieFila,
                                in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    /// Un segundo toque en la tarjeta activa la quita, como en el web: si
    /// filtrar es un toque, dejar de filtrar tiene que serlo también.
    private func alTocar(_ t: TarjetaPadron) {
        vm.tarjeta = (vm.tarjeta == t && t != .todos) ? .todos : t
    }

    private func filaPadron(_ t: TarjetaPadron) -> some View {
        let activa = vm.tarjeta == t
        return Button { alTocar(t) } label: {
            HStack(spacing: 10) {
                Text(t.etiqueta).font(.subheadline)
                Spacer(minLength: 8)
                Text("\(vm.cuenta(t))")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(activa ? Paleta.brand : .primary)
                if activa {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(Paleta.brand)
                }
            }
            .padding(.horizontal, Esp.pantalla).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activa ? .isSelected : [])
    }

    private func tarjetaPadron(_ t: TarjetaPadron) -> some View {
        let activa = vm.tarjeta == t
        return Button { alTocar(t) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.etiqueta)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                Text("\(vm.cuenta(t))")
                    .font(.title2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(activa ? Paleta.brand : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Esp.tarjeta)
            .background(activa ? Paleta.brandFill : Paleta.superficieFila,
                        in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activa ? .isSelected : [])
    }

    /// La fila del informe NO es la de Membresía: aquí no se abre a nadie —un
    /// informe se lee y se exporta—, así que enseña lo que el recorte explica,
    /// el estado y el porcentaje, sin chevron que prometa una ficha.
    private func filaMiembroInforme(_ m: Miembro) -> some View {
        HStack(spacing: 12) {
            Avatar(iniciales: m.iniciales, color: m.estado.color, lado: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.nombre).font(.subheadline).lineLimit(1)
                Text(m.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            if !m.estado.esBaja {
                Text("\(m.asistenciaPct)%")
                    .font(.subheadline.weight(.medium)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Pill(texto: m.estado.etiqueta, color: m.estado.color)
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
    }

    private var contenidoInforme: some View {
        let r = vm.resumen
        let maxEstado = r.porEstado.map { $0.1 }.max() ?? 1
        let maxMinisterio = r.porMinisterio.map { $0.1 }.max() ?? 1
        let maxAltas = r.altasPorMes.map { $0.altas }.max() ?? 1
        let totalAltas = r.altasPorMes.map(\.altas).reduce(0, +)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if vm.informeSeleccionado == 1 {
                    informeMiembros
                } else if vm.informeSeleccionado == 2 {
                    informeAsistencia
                } else if vm.informeSeleccionado == 3 {
                    informeSeguimiento
                } else {
                // Encabezado
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("Panorama general", "General overview"))
                        .font(.title3.weight(.semibold))
                    // **El periodo sale de `vm.etiquetaPeriodo`, no de
                    // `r.periodo`.** Al sacar los chips de periodo del
                    // contenido, esta línea pasa a ser el ÚNICO sitio donde se
                    // lee qué periodo se está mirando sin abrir nada, y
                    // `r.periodo` no sirve para eso: con un rango devuelve la
                    // cadena fija "Rango personalizado" —sin las fechas—, así
                    // que el estado se habría escondido sin sustituto.
                    // `etiquetaPeriodo` sí cubre los cinco casos, y es de la
                    // vista: el modelo no se toca.
                    Text("\(r.totalMiembros) \(L.t("miembros · \(vm.etiquetaPeriodo)", "members · \(vm.etiquetaPeriodo)"))")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }

                // Dos columnas de KPIs — siempre 2 en iPad, 1 en iPhone
                let colsKPI: [GridItem] = sizeClass == .regular
                    ? [GridItem(.flexible()), GridItem(.flexible())]
                    : [GridItem(.flexible())]
                LazyVGrid(columns: colsKPI, spacing: 16) {
                    // Por estado
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            TituloSeccion(texto: L.t("MIEMBROS POR ESTADO", "MEMBERS BY STATUS"))
                            ForEach(r.porEstado, id: \.0) { nombre, valor in
                                HStack(spacing: 8) {
                                    Text(nombre).font(.subheadline).frame(minWidth: 80, alignment: .leading)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brandMuted)
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brand)
                                            .scaleEffect(x: max(0.001, Double(valor) / Double(maxEstado)), y: 1, anchor: .leading)
                                    }
                                    .frame(height: 8)
                                    Text("\(valor)")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Paleta.brand)
                                        .frame(width: 32, alignment: .trailing)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxHeight: .infinity)

                    // Por ministerio
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 10) {
                            TituloSeccion(texto: L.t("MIEMBROS POR MINISTERIO", "MEMBERS BY MINISTRY"))
                            ForEach(r.porMinisterio, id: \.0) { nombre, valor in
                                HStack(spacing: 8) {
                                    Text(nombre).font(.subheadline).frame(minWidth: 80, alignment: .leading)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brandMuted)
                                        RoundedRectangle(cornerRadius: 4).fill(Paleta.brand)
                                            .scaleEffect(x: max(0.001, Double(valor) / Double(maxMinisterio)), y: 1, anchor: .leading)
                                    }
                                    .frame(height: 8)
                                    Text("\(valor)")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Paleta.brand)
                                        .frame(width: 32, alignment: .trailing)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxHeight: .infinity)
                }

                // Expediente + Nuevos por mes — siempre 2 en iPad, 1 en iPhone
                LazyVGrid(columns: colsKPI, spacing: 16) {
                    // Expediente
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            TituloSeccion(texto: L.t("ESTADO DEL EXPEDIENTE", "FILE STATUS"))
                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(r.expedienteCompleto)")
                                        .font(.title2.weight(.bold)).monospacedDigit()
                                        .foregroundStyle(Paleta.brand)
                                        .contentTransition(.numericText())
                                    Text(L.t("Completo", "Complete"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                VStack(spacing: 4) {
                                    Text("\(r.expedienteIncompleto)")
                                        .font(.title2.weight(.bold)).monospacedDigit()
                                        .foregroundStyle(Paleta.aviso)
                                        .contentTransition(.numericText())
                                    Text(L.t("Incompleto", "Incomplete"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Nuevos por mes
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 12) {
                            TituloSeccion(texto: L.t("NUEVOS POR MES", "NEW PER MONTH"))
                            Text(L.t("\(totalAltas) altas en el periodo · por fecha de ingreso",
                                     "\(totalAltas) additions in period · by join date"))
                                .font(.caption).foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(r.altasPorMes) { m in
                                    VStack(spacing: 4) {
                                        Text("\(m.altas)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Paleta.brand)
                                            .contentTransition(.numericText())
                                        VStack(spacing: 0) {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Paleta.brand)
                                                .frame(height: 36 * CGFloat(m.altas) / CGFloat(maxAltas))
                                        }
                                        .frame(height: 36)
                                        // Doce meses en el ancho del teléfono
                                        // dan ~25 pt por columna, y "May",
                                        // "Aug", "Nov" y "Dec" se partían en
                                        // dos renglones: "Ma" sobre "y".
                                        Text(m.mes).font(.caption2).foregroundStyle(.secondary)
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Movimientos de membresía
                Tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TituloSeccion(texto: L.t("MOVIMIENTOS DE MEMBRESÍA", "MEMBERSHIP MOVEMENTS"))
                            Spacer()
                            // Estaba escrito con la acción vacía: la tabla de
                            // abajo enumera traslados y el enlace prometía
                            // llevar a donde se resuelven, sin llevar a
                            // ninguna parte. Es un `NavigationLink` y no un
                            // botón para que traiga su chevron de vuelta: se
                            // llega desde aquí, no desde el hub, así que a
                            // esta sí le toca el botón de volver.
                            NavigationLink {
                                CartasView()
                            } label: {
                                Text(L.t("Ir a Cartas y traslados", "Go to Letters & transfers"))
                                    .font(.caption).foregroundStyle(Paleta.enlace)
                            }
                            .buttonStyle(.plain)
                        }

                        // **En el teléfono no hay tabla.** Las cinco columnas
                        // suman 580 puntos y aquí había un scroll horizontal
                        // con `showsIndicators: false`: la fecha y el estado
                        // existían, pero fuera de la pantalla y sin nada que
                        // insinuara que se podía arrastrar. Un informe que se
                        // enseña en una junta no puede esconder dos columnas
                        // detrás de un gesto que nadie sabe que está.
                        if compacto {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(r.traslados) { t in
                                    filaTrasladoCompacta(t)
                                    if t.id != r.traslados.last?.id { Divider() }
                                }
                            }
                        } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Cabecera
                                HStack(spacing: 0) {
                                    Text(L.t("FOLIO", "FOLIO")).frame(width: 110, alignment: .leading)
                                    Text(L.t("MOVIMIENTO", "MOVEMENT")).frame(width: 90, alignment: .leading)
                                    Text(L.t("PERSONA / IGLESIA", "PERSON / CHURCH")).frame(width: 180, alignment: .leading)
                                    Text(L.t("FECHA", "DATE")).frame(width: 80, alignment: .trailing)
                                    Text(L.t("ESTADO", "STATUS")).frame(width: 120, alignment: .trailing)
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)
                                Divider()

                                ForEach(r.traslados) { t in
                                    HStack(spacing: 0) {
                                        Text(t.folioLegible).font(.caption).monospacedDigit().frame(width: 110, alignment: .leading)
                                        Pill(texto: t.tipoTraslado,
                                             color: t.sentido == .salida ? Paleta.aviso : Paleta.brand)
                                            .frame(width: 90, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(t.persona).font(.subheadline.weight(.medium)).lineLimit(1)
                                            Text(t.iglesia).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        .frame(width: 180, alignment: .leading)
                                        Text(t.fecha).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                                        Text(t.estado).font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .trailing)
                                    }
                                    .padding(.vertical, 8)
                                    if t.id != r.traslados.last?.id { Divider() }
                                }
                            }
                        }
                        }
                    }
                }
            }
                } // end else (general content)
            .padding(Esp.panel)
        }
        // El desvanecido, en su variante suave: el mismo `.soft` que ya usan
        // el Dashboard, Servicios y Configuración. Quien lo hace aparecer es
        // `safeAreaBar` (ver `cuerpo`); esto solo elige que sea un degradado y
        // no un corte.
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .animation(.spring(duration: 0.3), value: vm.periodoTipo)
        .animation(.spring(duration: 0.3), value: vm.mesSeleccionado)
        .animation(.spring(duration: 0.3), value: vm.trimestreSeleccionado)
        .animation(.spring(duration: 0.3), value: vm.añoSeleccionado)
    }
}

// MARK: - Share sheet (UIKit bridge)

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Sheet de rango de fechas

