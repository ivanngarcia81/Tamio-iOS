import SwiftUI

/// Pantalla Ingresos/Gastos: lista maestra (pestañas, buscador y filtros
/// funcionales, agrupada por fecha, deslizar para editar/eliminar) + detalle.
/// Todas las acciones pasan por el ViewModel → el repositorio, así el motor
/// (GRDB) solo cambia la implementación sin tocar esta vista.
struct MovimientosView: View {
    @State private var vm: MovimientosViewModel
    @State private var abierto: Movimiento?
    @State private var hoja: HojaMov?
    @State private var mostrarFiltros = false
    /// Movimiento cuya eliminación espera confirmación. Borrar un registro
    /// financiero es más grave que marcar un corte, que ya la pide.
    @State private var movimientoAEliminar: Movimiento?
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// La elección Ingresos/Gastos es la MISMA que marca la sidebar, así que
    /// vive aquí y no solo en el ViewModel. El picker de esta pantalla estaba
    /// atado a `vm.tipo` y no tocaba `nav.seccion`: cambiar a Gastos desde
    /// dentro dejaba la sidebar marcando Ingresos.
    @Environment(Navegacion.self) private var nav

    init(tipo: TipoMovimiento) {
        _vm = State(initialValue: MovimientosViewModel(tipo: tipo))
    }

    /// La hoja de crear (con folio sugerido) o editar (movimiento existente).
    private enum HojaMov: Identifiable {
        case nueva(folio: String)
        case editar(Movimiento)
        var id: String {
            switch self {
            case .nueva(let f): return "n\(f)"
            case .editar(let m): return "e\(m.id)"
            }
        }
    }

    /// **La rama del teléfono.** No es la misma pregunta que "¿caben la lista y
    /// el detalle a la vez?", que la decide el ancho contra
    /// `Esp.anchoMaestroDetalle`. Aquí se decide si los controles suben a la
    /// barra de navegación, y eso solo tiene sentido en el teléfono: en iPad la
    /// barra es de la pantalla entera, así que el buscador y el segmentado
    /// acabarían lejos de la lista que filtran y compartiendo sitio con las
    /// acciones del detalle.
    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        pantalla
            .toolbar { barra }
            .confirmationDialog(
                L.t("¿Eliminar este movimiento?", "Delete this entry?"),
                isPresented: Binding(get: { movimientoAEliminar != nil },
                                     set: { if !$0 { movimientoAEliminar = nil } }),
                titleVisibility: .visible,
                presenting: movimientoAEliminar
            ) { m in
                Button(L.t("Eliminar", "Delete"), role: .destructive) {
                    Task { await vm.eliminar(m) }
                }
                Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
            } message: { m in
                Text(L.t("Se eliminará «\(m.titular)» por \(Money.fmt(m.monto)). No se puede deshacer.",
                         "«\(m.titular)» for \(Money.fmt(m.monto)) will be deleted. This can't be undone."))
            }
            .sheet(item: $hoja) { item in
                switch item {
                case .nueva(let folio):
                    NuevoMovimientoView(tipo: vm.tipo, folio: folio, existente: nil,
                                        onGuardar: { m in Task { await vm.crear(m) } },
                                        onNuevoFolio: { await vm.nuevoFolio() })
                case .editar(let m):
                    NuevoMovimientoView(tipo: m.tipo, folio: m.folio, existente: m) { nm in
                        Task { await vm.actualizar(nm) }
                    }
                }
            }
            .sheet(isPresented: $mostrarFiltros) { filtrosSheet }
            .onChange(of: nav.seccion) { _, seccion in sincronizarConSidebar(seccion) }
            .task { await vm.cargar() }
            .overlay(alignment: .top) { avisoError }
    }

    /// **Las dos ramas, separadas del todo**, que es lo que distingue esta
    /// pantalla en teléfono y en iPad.
    ///
    /// Teléfono: el buscador nativo (`.minimize` lo deja como cápsula de lupa
    /// en la barra y lo despliega en campo al tocarlo; trae además el foco, el
    /// botón de cancelar y el borrado, que el `TextField` a mano no tenía) y el
    /// título borrado, porque el segmentado que ocupa su sitio dice lo mismo.
    ///
    /// iPad: título y franja de encabezado como las otras quince pantallas, y
    /// los controles se quedan abajo, en la cabecera de la columna.
    @ViewBuilder
    private var pantalla: some View {
        if compacto {
            columnas
                .searchable(text: $vm.busqueda,
                            prompt: Text(L.t("Buscar folio, miembro o nota",
                                             "Search folio, member or note")))
                .searchToolbarBehavior(.minimize)
                .navigationTitle(tituloBarra)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            columnas
                .encabezadoNav(tituloBarra, nil)
                .navigationBarTitleDisplayMode(.large)
        }
    }

    private var columnas: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: Esp.columnaMaestra)
                    Divider()
                    if let m = vm.seleccion {
                        MovimientoDetalle(m: m, onEditar: { hoja = .editar(m) },
                                          onComprobante: { nombre in adjuntarComprobante(m, nombre) })
                    } else {
                        ContentUnavailableView(
                            L.t("Selecciona un movimiento", "Select an entry"),
                            systemImage: "list.bullet.rectangle"
                        )
                    }
                }
            } else {
                listaColumna
                    .navigationDestination(item: $abierto) { m in
                        MovimientoDetalle(m: m, onEditar: { hoja = .editar(m) },
                                          onComprobante: { nombre in adjuntarComprobante(m, nombre) })
                            // El H1 de la ficha ya dice el titular; repetirlo en la
                            // barra lo dejaba tres veces en pantalla, con el chip
                            // de categoría. La barra va vacía.
                            .navigationTitle("")
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
    }

    // MARK: - Barra

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        // El segmentado ocupa el lugar del título. Se queda `Picker`
        // segmentado y NO se envuelve en glass: en iOS 26 el sistema ya le
        // pone su cápsula, y glass dentro de glass es lo que Apple
        // desaconseja. Tampoco se parte en dos botones sueltos: un segmentado
        // dice "elige uno de los dos", dos cápsulas se leen como dos acciones.
        if compacto {
            ToolbarItem(placement: .title) {
                pickerTipo.frame(maxWidth: 190)
            }
        }
        // Cápsula de glass CLARA con el símbolo en verde, no rellena de verde.
        //
        // Empezó siendo `.glassProminent`, que tiñe el material entero: en
        // oscuro `Paleta.brand` es #2FBF71 —un verde pensado para leerse COMO
        // TEXTO sobre negro— y debajo de un símbolo blanco daba ~2.4:1. Con
        // `.glass` el material se queda limpio y el verde pasa al símbolo, que
        // es donde ese tono sí funciona: sobre el glass de una barra oscura se
        // recorta de sobra.
        //
        // Encaja además con la ley de color de `Palette.swift`, que reserva el
        // verde para lo seleccionado y las cifras: un botón no es ninguna de
        // las dos cosas, y rellenarlo lo convertía en el elemento más pesado de
        // la pantalla. El sistema sigue resolviendo forma, sombra, borde y
        // refracción, que es lo que quitó el halo doble.
        // **Mes y filtros separados no caben, medido en pantalla.** Con los
        // seis elementos (volver · segmentado · Sep ⌄ · filtros · + · lupa) el
        // segmentado se queda en ~155 pt y "Income | Expenses" necesita ~190:
        // sale "Inco… | Expe…", que es peor que esconder un filtro. Así que van
        // al overflow, con las dos condiciones: el mes ESCRITO con su chevron
        // —nunca tres puntos— y la señal de filtros activos a la vista.
        if compacto {
            ToolbarItem(placement: .topBarTrailing) { menuPeriodoYFiltros }
        }
        // El espaciador ROMPE el grupo de glass. Sin él, "qué estoy viendo"
        // (el mes) y "qué puedo hacer" (el `+`) se funden en una sola cápsula
        // sin tener nada que ver. Separados, cada cosa es una cápsula, que es
        // lo que hacen las referencias del Teléfono.
        //
        // La lupa NO se puede meter en el mismo grupo que el `+`: la coloca el
        // sistema al declarar `.searchToolbarBehavior(.minimize)` y va siempre
        // en su propio grupo. El grupo compacto lupa+`+` del Calendario no es
        // alcanzable desde `.searchable`.
        if compacto { ToolbarSpacer(.fixed, placement: .topBarTrailing) }
        ToolbarItem(placement: .topBarTrailing) { botonNuevo }
    }

    /// El overflow del teléfono, con las dos condiciones que lo hacen legible:
    ///
    /// - **El mes va escrito, con su chevron.** El chevron es lo que dice que
    ///   despliega algo; sin él el botón se lee como una etiqueta. Y escrito y
    ///   no detrás de tres puntos porque en una tesorería el periodo no es un
    ///   ajuste cualquiera: es la diferencia entre mirar septiembre o agosto.
    ///   Es además donde se recupera el subtítulo que se va con el título.
    /// - **Se tiñe y lleva el contador** cuando hay filtros puestos. Escondida
    ///   esa señal, un filtro activo explicaría una lista vacía sin que se
    ///   pueda saber por qué.
    ///
    /// Va en su propio `ToolbarItem` y no dentro de un grupo: agrupado, el menú
    /// se anclaba al grupo entero y se desplegaba pegado a la izquierda,
    /// tapando el segmentado y saliendo de un sitio que no era el del botón.
    private var menuPeriodoYFiltros: some View {
        Menu {
            Section(L.t("Mes", "Month")) {
                ForEach(vm.mesesDisponibles, id: \.self) { m in
                    opcionMes(Fechas.mes(m), marcada: vm.mes == m) { vm.mes = m }
                }
                opcionMes(Self.todosLosMeses, marcada: vm.mes == nil) { vm.mes = nil }
            }
            Section(L.t("Filtros", "Filters")) {
                Button {
                    mostrarFiltros = true
                } label: {
                    Label(filtrosActivos > 0
                          ? L.t("Categoría y estado · \(filtrosActivos)",
                                "Category and status · \(filtrosActivos)")
                          : L.t("Categoría y estado", "Category and status"),
                          systemImage: "line.3.horizontal.decrease")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(etiquetaMesCorta).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                if filtrosActivos > 0 { contador(filtrosActivos) }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .tint(filtrosActivos > 0 ? Paleta.brand : nil)
        .accessibilityLabel(L.t("Mes y filtros", "Month and filters"))
    }

    /// En el teléfono es solo el `+` —la barra ya va justa con el segmentado y
    /// el menú—; en iPad cabe la palabra. Dos ramas y no un ternario en
    /// `.labelStyle`: los estilos son tipos distintos y un ternario entre ellos
    /// no compila, el mismo motivo por el que `pickerCategoria` de la hoja de
    /// captura está partido en dos.
    @ViewBuilder
    private var botonNuevo: some View {
        let boton = Button {
            Task { hoja = .nueva(folio: await vm.nuevoFolio()) }
        } label: {
            Label(L.t("Nuevo", "New"), systemImage: "plus")
        }
        .buttonStyle(.glass)
        .tint(Paleta.brand)

        if compacto {
            boton.labelStyle(.iconOnly)
        } else {
            boton.labelStyle(.titleAndIcon)
        }
    }

    private var pickerTipo: some View {
        Picker(L.t("Tipo", "Type"), selection: tipoSeleccionado) {
            Text(L.t("Ingresos", "Income")).tag(TipoMovimiento.ingreso)
            Text(L.t("Gastos", "Expenses")).tag(TipoMovimiento.gasto)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// El repositorio real puede fallar por red o porque RLS niegue el acceso.
    /// Sin este aviso la lista se vería simplemente vacía, indistinguible de
    /// "no hay movimientos".
    @ViewBuilder private var avisoError: some View {
        if let error = vm.error {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error).font(.footnote).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    vm.descartarError()
                } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Paleta.negativo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func abrir(_ m: Movimiento) {
        vm.seleccionId = m.id
        abierto = m
    }

    /// Guarda el comprobante elegido en el movimiento, vía el repositorio.
    private func adjuntarComprobante(_ m: Movimiento, _ nombre: String) {
        var actualizado = m
        actualizado.comprobante = nombre
        Task { await vm.actualizar(actualizado) }
    }

    private static let todosLosMeses = L.t("Todos los meses", "All months")

    private var etiquetaMes: String {
        vm.mes.map(Fechas.mes) ?? Self.todosLosMeses
    }

    /// "Sep" · "Todos", para la barra del teléfono, donde el espacio decide.
    private var etiquetaMesCorta: String {
        vm.mes.map(L.mesCorto) ?? L.t("Todos", "All")
    }

    private var tituloBarra: String {
        vm.tipo == .ingreso ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses")
    }

    // MARK: - Columna maestra

    /// **Capas, no hermanos.** La cabecera y el pie eran hermanos de la lista
    /// dentro de un `VStack`, así que una fila que subía al hacer scroll se
    /// recortaba contra el borde del `VStack` y desaparecía de golpe en la
    /// línea del `Divider`: no había nada que difuminar porque nada llegaba a
    /// pasar por detrás. Y en el otro extremo el pie cortaba la última fila a
    /// media altura.
    ///
    /// Con `safeAreaInset` la lista ocupa todo y el contenido corre por debajo
    /// de las dos barras, que es lo único que necesita material para difuminar
    /// algo. Los `Divider` sobran: con material y desvanecido de borde una
    /// línea vuelve a leerse como pared.
    private var listaColumna: some View {
        lista
            .safeAreaInset(edge: .top, spacing: 0) { cabeceraLista }
            .safeAreaInset(edge: .bottom, spacing: 0) { pieLista }
            .colchonInferior()
    }

    @ViewBuilder
    private var lista: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaCuerpo
            .listStyle(.plain)
            // El suelo va en la LISTA, no en la columna. Antes el
            // `.regularMaterial` estaba detrás de la columna entera, donde no
            // tenía nada que difuminar y se resolvía como un gris plano; el
            // material se fue a la cabecera y al pie, así que aquí queda el
            // fondo liso sobre el que corre el contenido.
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            // El desvanecido de borde: la fila deja de aparecer y desaparecer
            // de golpe al cruzar por detrás de la cabecera o del pie. Sustituye
            // al margen de scroll que se puso antes como parche, cuando la
            // cabecera y el pie todavía eran hermanos y no había nada por
            // detrás de lo que desvanecerse.
            .scrollEdgeEffectStyle(.soft, for: .all)
    }

    @ViewBuilder
    private var listaCuerpo: some View {
        List {
            ForEach(vm.grupos, id: \.encabezado) { grupo in
                Section {
                    ForEach(grupo.items) { m in
                        filaContenido(m)
                            .contentShape(Rectangle())
                            .onTapGesture { abrir(m) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    movimientoAEliminar = m
                                } label: {
                                    Label(L.t("Eliminar", "Delete"), systemImage: "trash")
                                }
                                // El tint del TabView tapa el rojo del rol.
                                .tint(.red)
                                Button {
                                    hoja = .editar(m)
                                } label: {
                                    Label(L.t("Editar", "Edit"), systemImage: "pencil")
                                }
                                .tint(Paleta.brand)
                            }
                    }
                } header: {
                    Text(grupo.encabezado)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
    }

    /// La tira de controles. **En el teléfono no existe**: sus cuatro
    /// controles viven en la barra, y esta franja entre el título y la lista
    /// desaparece entera. En iPad se queda donde está —la barra es de la
    /// pantalla completa y estos controles filtran solo la columna— pero con
    /// los controles en glass en vez de dibujados a mano.
    @ViewBuilder
    private var cabeceraLista: some View {
        if !compacto {
            VStack(spacing: 10) {
                pickerTipo
                buscadorColumna
                // Se agrupan para que las dos cápsulas se fundan entre sí al
                // acercarse, que es lo que hace un contenedor de glass.
                GlassEffectContainer(spacing: Esp.hueco) {
                    HStack(spacing: Esp.hueco) {
                        selectorMes
                        Spacer()
                        botonFiltros
                    }
                }
            }
            .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
            // El material vive AQUÍ, no detrás de la columna entera: detrás de
            // la lista se resolvía como un gris plano porque no tenía nada
            // que difuminar.
            .background(.regularMaterial)
        }
    }

    /// El buscador de la columna del iPad. No usa `.searchable` a propósito:
    /// ese lo coloca el sistema en la barra de la pantalla, que en iPad está
    /// encima de las dos columnas y del detalle. Filtra esta lista, así que
    /// vive pegado a ella. Lo que sí se va es el `RoundedRectangle` con
    /// `tertiarySystemFill` que hacía de fondo.
    private var buscadorColumna: some View {
        HStack(spacing: Esp.hueco) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L.t("Buscar folio, miembro o nota", "Search folio, member or note"),
                      text: $vm.busqueda)
                .textFieldStyle(.plain)
            if !vm.busqueda.isEmpty {
                Button { vm.busqueda = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
    }

    /// Escribe en los dos lados a la vez. La sección es la fuente de verdad
    /// para la sidebar; el ViewModel necesita el tipo para recargar.
    private var tipoSeleccionado: Binding<TipoMovimiento> {
        Binding(get: { vm.tipo },
                set: { nuevo in
                    vm.tipo = nuevo
                    nav.seccion = Self.seccion(de: nuevo)
                })
    }

    private static func seccion(de tipo: TipoMovimiento) -> String {
        tipo == .ingreso ? "ingresos" : "gastos"
    }

    /// El camino inverso. Las dos ramas del `switch` de `RootView` construyen
    /// el mismo tipo de vista en la misma posición, así que SwiftUI reutiliza
    /// esta instancia al cambiar de sección desde la sidebar y el `@State` del
    /// ViewModel se quedaría con el tipo anterior.
    private func sincronizarConSidebar(_ seccion: String) {
        if seccion == "ingresos" { vm.tipo = .ingreso }
        if seccion == "gastos" { vm.tipo = .gasto }
    }

    // MARK: - Filtros

    /// El mes no cuenta como filtro: tiene chip propio y siempre hay uno
    /// puesto, así que el globito marcaría "1" permanentemente.
    private var filtrosActivos: Int {
        (vm.filtroCategoria != nil ? 1 : 0)
        + ((vm.tipo == .ingreso ? vm.soloSinDepositar : vm.soloPendientes) ? 1 : 0)
    }

    /// Botón de filtros. La cápsula, el borde y la sombra las pone `.glass`;
    /// el verde tiñe el material cuando hay algo aplicado, y el contador dice
    /// cuánto. Esa señal no se puede perder: un filtro puesto explica una lista
    /// vacía, y sin ella el usuario no tiene forma de saber por qué.
    ///
    /// En el teléfono va solo el icono de deslizadores, que es el símbolo del
    /// sistema para esto; en iPad cabe la palabra.
    private var botonFiltros: some View {
        Button { mostrarFiltros = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                if !compacto { Text(L.t("Filtros", "Filters")) }
                if filtrosActivos > 0 { contador(filtrosActivos) }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .tint(filtrosActivos > 0 ? Paleta.brand : nil)
        .accessibilityLabel(L.t("Filtros", "Filters"))
    }

    private func contador(_ n: Int) -> some View {
        Text("\(n)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(minWidth: 16, minHeight: 16)
            .background(Paleta.brand, in: Circle())
    }

    private var filtrosSheet: some View {
        NavigationStack {
            List {
                Section(L.t("CATEGORÍA", "CATEGORY")) {
                    ForEach(vm.categoriasChip, id: \.self) { c in
                        // `.buttonStyle(.plain)`: sin él el estilo automático del
                        // Button dentro del List pinta el label con el tint
                        // heredado del TabView, por encima del `.primary` que ya
                        // llevaba escrito, y las opciones salían todas en verde.
                        Button {
                            vm.filtroCategoria = (vm.filtroCategoria == c) ? nil : c
                        } label: {
                            HStack {
                                Text(c).foregroundStyle(.primary)
                                Spacer()
                                if vm.filtroCategoria == c {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Paleta.brand)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Cada tipo tiene su estado. "Sin depositar" es de los
                // ingresos —un gasto no entra en un corte—, así que en Gastos
                // el filtro devolvía siempre cero resultados. Ahí lo que se
                // busca es lo que quedó marcado para revisar.
                Section(L.t("ESTADO", "STATUS")) {
                    if vm.tipo == .ingreso {
                        Toggle(L.t("Sin depositar", "Not deposited"), isOn: $vm.soloSinDepositar)
                            .tint(Paleta.brand)
                    } else {
                        Toggle(L.t("Marcados como pendientes", "Flagged for review"),
                               isOn: $vm.soloPendientes)
                            .tint(Paleta.brand)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L.t("Filtros", "Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t("Limpiar", "Clear")) {
                        vm.filtroCategoria = nil
                        vm.soloSinDepositar = false
                        vm.soloPendientes = false
                    }
                    .foregroundStyle(Paleta.brand)
                    .disabled(filtrosActivos == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t("Listo", "Done")) { mostrarFiltros = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(Paleta.brand)
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// El selector de mes, **con el mes escrito y su chevron**. El chevron es
    /// lo que dice que despliega algo; sin él el botón se lee como una
    /// etiqueta. Y el mes va escrito y no detrás de tres puntos porque en una
    /// tesorería el periodo no es un ajuste cualquiera: es la diferencia entre
    /// estar mirando septiembre o agosto. Es además donde se recupera el
    /// subtítulo que se va con el título.
    ///
    /// Ofrece solo los meses con movimientos —un calendario libre dejaría caer
    /// en meses vacíos— más "Todos los meses".
    private var selectorMes: some View {
        Menu {
            ForEach(vm.mesesDisponibles, id: \.self) { m in
                opcionMes(Fechas.mes(m), marcada: vm.mes == m) { vm.mes = m }
            }
            Divider()
            opcionMes(Self.todosLosMeses, marcada: vm.mes == nil) { vm.mes = nil }
        } label: {
            HStack(spacing: 4) {
                // Abreviado en el teléfono, donde el ancho de la barra decide;
                // entero en iPad, donde la cabecera de la columna tiene sitio.
                Text(compacto ? etiquetaMesCorta : etiquetaMes).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .tint(vm.mes != nil ? Paleta.brand : nil)
    }

    /// `Label` con palomita en vez de `Toggle`: dentro de un `Menu` la palomita
    /// es la convención del sistema para "esta es la opción vigente".
    @ViewBuilder
    private func opcionMes(_ texto: String, marcada: Bool,
                           _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            if marcada { Label(texto, systemImage: "checkmark") } else { Text(texto) }
        }
    }

    private func filaContenido(_ m: Movimiento) -> some View {
        let esSel = m.id == vm.seleccionId
        return HStack(spacing: 10) {
            // Símbolo de la categoría dentro de un círculo tintado: el punto de
            // 8×8 no se podía interpretar sin leyenda.
            Image(systemName: Paleta.iconoCategoria(m.claveCategoria))
                .font(.system(size: 13))
                .foregroundStyle(Paleta.categoria(m.claveCategoria))
                .frame(width: 30, height: 30)
                .background(Paleta.categoria(m.claveCategoria).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(m.titular).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(m.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                // Signo y color en la lista, igual que en Inicio y Por revisar.
                Text(Money.firmado(m.monto, ingreso: m.esIngreso))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Money.color(ingreso: m.esIngreso))
                // El hueco de la etiqueta se reserva SIEMPRE. Apareciendo solo
                // cuando hay etiqueta, las filas con "Sin depositar" eran más
                // altas que las demás y el monto se desplazaba hacia arriba: el
                // ritmo de la lista se rompía cada dos filas.
                Text(L.t("Sin depositar", "Not deposited"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Paleta.aviso)
                    .padding(.horizontal, Esp.hueco).padding(.vertical, 2)
                    .background(Paleta.avisoFill, in: Capsule())
                    .opacity(m.sinDepositar ? 1 : 0)
                    .accessibilityHidden(!m.sinDepositar)
            }
        }
        .padding(.vertical, 6)
        // La selección persistente es idioma de iPad, donde la lista y el
        // detalle conviven. En iPhone la fila navega y volver dejaba la última
        // tocada con barra verde y fondo tintado, como si siguiera abierta.
        .filaDeLista(seleccionada: esSel && sizeClass == .regular,
                     tarjeta: sizeClass != .regular)
    }

    private var pieLista: some View {
        HStack {
            Text(L.t("\(vm.itemsFiltrados.count) movimientos", "\(vm.itemsFiltrados.count) entries"))
            Spacer()
            Text(Money.firmado(vm.total, ingreso: vm.tipo == .ingreso))
                .monospacedDigit().fontWeight(.semibold)
                .foregroundStyle(Money.color(ingreso: vm.tipo == .ingreso))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
        // Igual que la cabecera: el material va donde hay algo que difuminar.
        .background(.regularMaterial)
    }
}
