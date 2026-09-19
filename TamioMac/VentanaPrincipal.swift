import SwiftUI

/// **La ventana: barra lateral, contenido, inspector y pie.**
struct VentanaPrincipal: View {
    @Environment(EstadoVentana.self) private var estado
    @Environment(\.openWindow) private var abrirVentana
    @State private var columnas: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var estado = estado

        NavigationSplitView(columnVisibility: $columnas) {
            BarraLateral(seleccion: $estado.seccion)
                .navigationSplitViewColumnWidth(min: 220, ideal: 252, max: 320)
        } detail: {
            VStack(spacing: 0) {
                ContenidoSeccion(seccion: estado.seccion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                BarraEstado(estado: textoEstado)
            }
            .navigationTitle(estado.seccion.titulo)
            .navigationSubtitle(subtitulo)
            .toolbar { barraDeHerramientas }
        }
        .inspector(isPresented: $estado.inspectorAbierto) {
            InspectorTamio(seccion: estado.seccion,
                           seleccion: estado.seleccion[estado.seccion.rawValue])
        }
        // El campo "Filtrar" de la maqueta. Es por sección: ver
        // `EstadoVentana.filtros` para el porqué.
        .searchable(text: Binding(
            get: { estado.filtro(estado.seccion) },
            set: { estado.ponerFiltro($0, en: estado.seccion) }
        ), placement: .toolbar, prompt: L.t("Filtrar", "Filter"))
    }

    // MARK: - Barra de herramientas

    @ToolbarContentBuilder
    private var barraDeHerramientas: some ToolbarContent {
        @Bindable var estado = estado

        // **El selector de periodo solo donde significa algo.** En la maqueta
        // aparece en Inicio y en ningún otro sitio: en Configuración o en
        // Actas no hay nada que encuadrar en un mes.
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
            // el mismo ⌥⌘N. El `help` lo escribe para quien pase el ratón.
            .help(L.t("Nuevo movimiento (⌥⌘N)", "New movement (⌥⌘N)"))
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                estado.inspectorAbierto.toggle()
            } label: {
                Label(L.t("Inspector", "Inspector"),
                      systemImage: "sidebar.trailing")
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

    /// **Sin cifras inventadas.** La maqueta enseña aquí "14 registros ·
    /// $19.257,15", pero esos números salen de los repositorios y todavía no
    /// están enchufados a esta ventana. Escribir un número de adorno en la
    /// barra de una app de contabilidad es justo lo que no se puede hacer.
    private var subtitulo: String {
        switch estado.seccion {
        case .config: return L.t("Iglesia, accesos y respaldos", "Church, access & backups")
        default:      return ""
        }
    }

    private var textoEstado: String {
        L.t("Andamiaje: las pantallas todavía no leen del motor",
            "Scaffolding: screens are not reading from the engine yet")
    }
}

/// El enrutador. Cada sección enseña, por ahora, qué va a ir aquí.
struct ContenidoSeccion: View {
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
