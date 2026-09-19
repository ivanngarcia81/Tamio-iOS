import SwiftUI

/// **La ventana: barra lateral, contenido, inspector y pie.**
struct VentanaPrincipal: View {
    @Environment(EstadoVentana.self) private var estado
    @Environment(\.openWindow) private var abrirVentana
    @State private var columnas: NavigationSplitViewVisibility = .all

    /// **Los dos viven en la ventana y no en la pantalla.**
    ///
    /// Si colgaran de la vista de Ingresos, saltar a Gastos y volver los
    /// destruiría y reconstruiría: se perdería el mes elegido, el filtro y la
    /// selección, y habría que volver a bajar del repositorio. Aquí sobreviven
    /// a moverse por la barra lateral, que es lo que espera cualquiera.
    @State private var ingresos = MovimientosViewModel(tipo: .ingreso)
    @State private var gastos = MovimientosViewModel(tipo: .gasto)
    @State private var selIngresos: Set<Movimiento.ID> = []
    @State private var selGastos: Set<Movimiento.ID> = []

    var body: some View {
        @Bindable var estado = estado

        NavigationSplitView(columnVisibility: $columnas) {
            BarraLateral(seleccion: $estado.seccion)
                .navigationSplitViewColumnWidth(min: 220, ideal: 252, max: 320)
        } detail: {
            VStack(spacing: 0) {
                contenido
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                BarraEstado(estado: textoEstado)
            }
            .navigationTitle(estado.seccion.titulo)
            .navigationSubtitle(subtitulo)
            .toolbar { barraDeHerramientas }
        }
        .inspector(isPresented: $estado.inspectorAbierto) {
            InspectorTamio(seccion: estado.seccion, movimiento: movimientoElegido)
        }
        .searchable(text: bindingFiltro, placement: .toolbar,
                    prompt: L.t("Filtrar", "Filter"))
        .task {
            await ingresos.cargar()
            await gastos.cargar()
        }
        // Cuando la sincronización termina de escribir, releer.
        .onChange(of: estado.recarga) {
            Task {
                await ingresos.cargar()
                await gastos.cargar()
            }
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var contenido: some View {
        switch estado.seccion {
        case .ingresos:
            TablaMovimientos(vm: ingresos, seleccion: $selIngresos)
        case .gastos:
            TablaMovimientos(vm: gastos, seleccion: $selGastos)
        default:
            PantallaPorEscribir(seccion: estado.seccion)
        }
    }

    // MARK: - Lo elegido

    /// El movimiento seleccionado, si la sección tiene tabla y hay UNO solo.
    ///
    /// Con varias filas marcadas el inspector no enseña ninguna: una ficha que
    /// dice los datos de la primera de ocho es una ficha que miente.
    private var movimientoElegido: Movimiento? {
        switch estado.seccion {
        case .ingresos: return unico(selIngresos, en: ingresos)
        case .gastos:   return unico(selGastos, en: gastos)
        default:        return nil
        }
    }

    private func unico(_ sel: Set<Movimiento.ID>, en vm: MovimientosViewModel) -> Movimiento? {
        guard sel.count == 1, let id = sel.first else { return nil }
        return vm.items.first { $0.id == id }
    }

    private var vmActual: MovimientosViewModel? {
        switch estado.seccion {
        case .ingresos: return ingresos
        case .gastos:   return gastos
        default:        return nil
        }
    }

    // MARK: - Barra de herramientas

    @ToolbarContentBuilder
    private var barraDeHerramientas: some ToolbarContent {
        @Bindable var estado = estado

        // **El selector de periodo solo donde significa algo.** En Actas o en
        // Configuración no hay nada que encuadrar en un mes.
        if muestraPeriodo {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $estado.periodo) {
                    ForEach(EstadoVentana.Periodo.allCases) { p in
                        Text(p.titulo).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                abrirVentana(id: CapturaRapida.idVentana)
            } label: {
                Label(L.t("Nuevo", "New"), systemImage: "plus")
            }
            // **El atajo NO se declara aquí.** Vive en el menú Archivo, y
            // ponerlo en los dos sitios deja a SwiftUI con dos destinos para
            // el mismo ⌥⌘N.
            .help(L.t("Nuevo movimiento (⌥⌘N)", "New movement (⌥⌘N)"))
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                estado.inspectorAbierto.toggle()
            } label: {
                Label(L.t("Inspector", "Inspector"), systemImage: "sidebar.trailing")
            }
            .help(L.t("Inspector (⌘I)", "Inspector (⌘I)"))
        }
    }

    private var muestraPeriodo: Bool {
        switch estado.seccion {
        case .inicio, .ingresos, .gastos, .reportes, .depositos: return true
        default: return false
        }
    }

    // MARK: - Textos

    /// **El filtro escribe donde de verdad filtra.**
    ///
    /// En las secciones con tabla va al `busqueda` del ViewModel, que es quien
    /// calcula `itemsFiltrados`; en las demás, a un cajón por sección de
    /// `EstadoVentana` para no perder lo escrito al ir y volver.
    private var bindingFiltro: Binding<String> {
        if let vm = vmActual {
            return Binding(get: { vm.busqueda }, set: { vm.busqueda = $0 })
        }
        let s = estado.seccion
        return Binding(get: { estado.filtro(s) }, set: { estado.ponerFiltro($0, en: s) })
    }

    /// **Aquí ya hay cifras de verdad**, y solo donde las hay.
    ///
    /// Salen de `itemsFiltrados` y de `total`, o sea que siguen al filtro y al
    /// mes elegido: si alguien escribe "diezmo", el recuento y la suma hablan
    /// de lo que está viendo y no de todo el mes. Las secciones sin tabla no
    /// inventan nada.
    private var subtitulo: String {
        if let vm = vmActual {
            let n = vm.itemsFiltrados.count
            let registros = n == 1 ? L.t("registro", "record") : L.t("registros", "records")
            return "\(n) \(registros) · \(Money.fmt(vm.total))"
        }
        if estado.seccion == .config {
            return L.t("Iglesia, accesos y respaldos", "Church, access & backups")
        }
        return ""
    }

    private var textoEstado: String {
        if let vm = vmActual {
            if vm.cargando { return L.t("Cargando…", "Loading…") }
            if let e = vm.error { return e }
            return L.t("\(vm.items.count) movimientos en el aparato",
                       "\(vm.items.count) movements on this device")
        }
        return L.t("Andamiaje: esta pantalla todavía no lee del motor",
                   "Scaffolding: this screen is not reading from the engine yet")
    }
}

/// Lo que se ve en las secciones que aún no tienen pantalla de Mac.
struct PantallaPorEscribir: View {
    let seccion: SeccionMac

    var body: some View {
        ContentUnavailableView {
            Label(seccion.titulo, systemImage: seccion.icono)
        } description: {
            Text(L.t("""
                     Esta pantalla está por escribir para el Mac. El motor —los \
                     repositorios, la sincronización, los cálculos— ya compila \
                     y está disponible desde aquí.
                     """,
                     """
                     This screen is still to be written for the Mac. The engine \
                     — repositories, sync, calculations — already compiles and \
                     is available from here.
                     """))
        }
    }
}
