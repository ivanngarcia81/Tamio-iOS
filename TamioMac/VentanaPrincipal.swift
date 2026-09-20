import SwiftUI

/// **La ventana: barra lateral, contenido, inspector y pie.**
struct VentanaPrincipal: View {
    @Environment(EstadoVentana.self) private var estado
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
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
    @State private var registro = RegistroViewModel()
    @State private var servicios = ServiciosViewModel()
    @State private var cartas = CartasViewModel()
    @State private var informes = InformesMembresiaViewModel()
    @State private var aportantes = MiembrosViewModel()
    @State private var depositos = DepositosViewModel()
    @State private var membresia = MembresiaViewModel()
    @State private var inicio = DashboardViewModel()
    @State private var selIngresos: Set<Movimiento.ID> = []
    @State private var selGastos: Set<Movimiento.ID> = []
    @State private var selRegistro: Set<Apunte.ID> = []
    @State private var selServicios: Set<Servicio.ID> = []
    /// **Una sola, no un conjunto.** Cartas no es una tabla: a la derecha hay
    /// una hoja, y una hoja solo puede enseñar un documento.
    @State private var selCarta: String?
    @State private var selAportantes: Set<Aportante.ID> = []
    @State private var selDepositos: Set<Corte.ID> = []
    @State private var selMembresia: Set<Miembro.ID> = []
    @State private var escribiendoNota = false

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
        // **En las pantallas de documento no hay inspector, y no es un
        // olvido.** El detalle de una carta es la carta, y el de un informe es
        // el informe: ya ocupan la mitad derecha de la ventana. Un tercer
        // panel al lado dejaría la hoja en una rendija donde no se puede leer
        // lo único que se ha venido a leer.
        .inspector(isPresented: Binding(
            get: { estado.inspectorAbierto && !estado.seccion.esDeDocumento },
            set: { estado.inspectorAbierto = $0 }
        )) {
            InspectorTamio(seccion: estado.seccion, ficha: ficha)
        }
        .searchable(text: bindingFiltro, placement: .toolbar,
                    prompt: L.t("Filtrar", "Filter"))
        .task { await cargarTodo() }
        // Cuando la sincronización termina de escribir, releer.
        .onChange(of: estado.recarga) { Task { await cargarTodo() } }
        .sheet(isPresented: $escribiendoNota) {
            NuevaNotaMac(vm: registro, autor: sesion?.perfil.firma ?? "")
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var contenido: some View {
        switch estado.seccion {
        case .inicio:
            PantallaInicio(vm: inicio,
                           nombre: sesion?.perfil.firma ?? "",
                           ir: { estado.seccion = $0 })
        case .ingresos:
            TablaMovimientos(vm: ingresos, seleccion: $selIngresos)
        case .gastos:
            TablaMovimientos(vm: gastos, seleccion: $selGastos)
        case .registro:
            TablaRegistro(vm: registro, seleccion: $selRegistro)
        case .servicios:
            TablaServicios(vm: servicios, seleccion: $selServicios)
        case .cartas:
            PantallaCartas(vm: cartas, seleccion: $selCarta)
        case .informes:
            PantallaInformes(vm: informes)
        case .miembros:
            TablaAportantes(vm: aportantes, seleccion: $selAportantes)
        case .depositos:
            TablaDepositos(vm: depositos, seleccion: $selDepositos)
        case .membresia:
            TablaMembresia(vm: membresia, seleccion: $selMembresia)
        default:
            PantallaPorEscribir(seccion: estado.seccion)
        }
    }

    private func cargarTodo() async {
        await ingresos.cargar()
        await gastos.cargar()
        await registro.cargar()
        await servicios.cargar()
        await cartas.cargar()
        await aportantes.cargar()
        await depositos.cargar()
        await membresia.cargar()
    }

    // MARK: - Lo elegido

    /// El movimiento seleccionado, si la sección tiene tabla y hay UNO solo.
    ///
    /// Con varias filas marcadas el inspector no enseña ninguna: una ficha que
    /// dice los datos de la primera de ocho es una ficha que miente.
    private var ficha: FichaInspector {
        switch estado.seccion {
        case .ingresos:
            return unico(selIngresos, en: ingresos).map(FichaInspector.movimiento) ?? .nada
        case .gastos:
            return unico(selGastos, en: gastos).map(FichaInspector.movimiento) ?? .nada
        case .registro:
            guard selRegistro.count == 1, let id = selRegistro.first,
                  let a = registro.todos.first(where: { $0.id == id }) else { return .nada }
            return .apunte(a)
        case .servicios:
            guard selServicios.count == 1, let id = selServicios.first,
                  let s = servicios.lista.first(where: { $0.id == id }) else { return .nada }
            return .servicio(s)
        case .miembros:
            guard selAportantes.count == 1, let id = selAportantes.first,
                  let a = aportantes.items.first(where: { $0.id == id }) else { return .nada }
            return .aportante(a, anio: aportantes.anio)
        case .membresia:
            guard selMembresia.count == 1, let id = selMembresia.first,
                  let m = membresia.items.first(where: { $0.id == id }) else { return .nada }
            return .miembro(m)
        case .depositos:
            guard selDepositos.count == 1, let id = selDepositos.first,
                  let c = depositos.items.first(where: { $0.id == id }) else { return .nada }
            return .corte(c)
        default:
            return .nada
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
                .fixedSize()
            }
        }

        // **El Registro se encuadra por ÁREA, no por mes.** Lo que se busca
        // aquí es "qué tocó Secretaría" o "qué notas hay", no "qué pasó en
        // septiembre": un registro de auditoría se lee entero.
        if estado.seccion == .registro {
            ToolbarItem(placement: .principal) {
                Picker("", selection: Binding(
                    get: { registro.filtro },
                    set: { registro.filtro = $0 }
                )) {
                    ForEach(registro.filtrosVisibles()) { f in
                        Text("\(f.etiqueta) (\(registro.count(f)))").tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // **`fixedSize` y NO un ancho a mano.**
                //
                // Estaba en 340 pt, y con cuatro etiquetas más su recuento no
                // cabían: en una ventana estrecha se leía "Notes (" con el
                // paréntesis sin cerrar y "All" comido por la izquierda. Un
                // ancho fijo es una apuesta sobre cuánto ocupa un texto que
                // cambia con el idioma y con los números — y la pierde.
                //
                // Con esto el control pide lo que mide. Si la ventana no da,
                // macOS manda los elementos que sobran al menú de la doble
                // flecha, que es lo que hace cualquier barra del sistema:
                // esconderlos enteros, nunca cortarlos por la mitad.
                .fixedSize()
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                // **El botón "Nuevo" hace lo de la pantalla en la que estás.**
                // En el Registro, lo único que una persona puede añadir es una
                // nota: lo demás lo escribe la app sola y no se toca.
                if estado.seccion == .registro {
                    escribiendoNota = true
                } else {
                    abrirVentana(id: CapturaRapida.idVentana)
                }
            } label: {
                Label(estado.seccion == .registro ? L.t("Anotar", "Add note")
                                                  : L.t("Nuevo", "New"),
                      systemImage: estado.seccion == .registro ? "square.and.pencil" : "plus")
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
        if estado.seccion == .miembros {
            return Binding(get: { aportantes.busqueda }, set: { aportantes.busqueda = $0 })
        }
        if estado.seccion == .membresia {
            return Binding(get: { membresia.busqueda }, set: { membresia.busqueda = $0 })
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
        if estado.seccion == .registro {
            let n = registro.visibles.count
            return n == 1 ? L.t("1 apunte", "1 entry") : L.t("\(n) apuntes", "\(n) entries")
        }
        if estado.seccion == .servicios {
            let n = servicios.lista.count
            let cultos = n == 1 ? L.t("culto", "service") : L.t("cultos", "services")
            let sin = servicios.lista.filter { $0.estadoRoster == .sinAsignar }.count
            // Lo que falta por resolver, solo si falta algo.
            return sin == 0 ? "\(n) \(cultos)"
                            : L.t("\(n) \(cultos) · \(sin) sin equipo",
                                  "\(n) \(cultos) · \(sin) without a team")
        }
        if estado.seccion == .miembros {
            let n = aportantes.itemsFiltrados.count
            let atrasados = aportantes.atrasadosCount
            let p = n == 1 ? L.t("aportante", "contributor") : L.t("aportantes", "contributors")
            let base = "\(n) \(p) · \(Money.fmt(aportantes.total))"
            return atrasados == 0 ? base
                : L.t("\(base) · \(atrasados) atrasados", "\(base) · \(atrasados) behind")
        }
        if estado.seccion == .membresia {
            let n = membresia.itemsFiltrados.count
            return n == 1 ? L.t("1 miembro", "1 member")
                          : L.t("\(n) miembros", "\(n) members")
        }
        if estado.seccion == .depositos {
            let n = depositos.items.count
            let c = n == 1 ? L.t("corte", "cut") : L.t("cortes", "cuts")
            let pend = depositos.pendientesCount
            return pend == 0 ? "\(n) \(c)"
                : L.t("\(n) \(c) · \(pend) en caja", "\(n) \(c) · \(pend) in the cash box")
        }
        if estado.seccion == .informes {
            return informes.resumen.periodo
        }
        if estado.seccion == .cartas {
            let n = cartas.emitidas.count
            let borradores = cartas.emitidas.filter { $0.estado == "borrador" }.count
            let c = n == 1 ? L.t("carta", "letter") : L.t("cartas", "letters")
            return borradores == 0 ? "\(n) \(c)"
                                   : L.t("\(n) \(c) · \(borradores) en borrador",
                                         "\(n) \(c) · \(borradores) in draft")
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
        if estado.seccion == .registro {
            return L.t("\(registro.totalCount) apuntes en el aparato",
                       "\(registro.totalCount) entries on this device")
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
