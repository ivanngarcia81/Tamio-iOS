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

    /// Si esta persona puede borrar movimientos. El permiso existía en
    /// Supabase —con un disparador que deshace la baja de un tesorero sin
    /// él— y la app enseñaba el botón igual: se borraba, la fila desaparecía,
    /// y a la siguiente sincronización volvía sin que nadie supiera por qué.
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?
    private var puedeEliminar: Bool {
        Permisos(rol: sesion?.perfil.rol ?? .administrador,
                 iglesia: ConfiguracionIglesiaViewModel.compartido.config)
            .puedeEliminarMovimientos
    }

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
                // **La lupa se queda arriba, y no por gusto.** Medido en
                // pantalla, con `.searchable` no hay forma de tenerla solo
                // abajo: sin `.minimize` el campo se queda desplegado en una
                // franja permanente —la tira que había que eliminar—; con
                // `.minimize` el sistema pone SU botón arriba y salen dos
                // lupas; `.toolbar(removing: .search)` no lo quita; y
                // `DefaultToolbarItem(kind: .search, placement: .bottomBar)`
                // sí lo baja, pero dentro del `TabView` de iPhone la barra
                // inferior del sistema queda por DEBAJO de la barra de
                // pestañas flotante y no se ve.
                //
                // Lo que baja en su lugar es el `+`, que es lo que el propio
                // encargo prevé cuando no cabe todo arriba. Así el segmentado
                // se lee entero.
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
        // El segmentado ocupa el lugar del título. Se queda `Picker` y NO se
        // envuelve en glass: el sistema ya le pone su cápsula, y glass dentro
        // de glass es lo que Apple desaconseja. Tampoco se parte en dos
        // botones: un segmentado dice "elige uno de los dos".
        if compacto {
            ToolbarItem(placement: .title) {
                pickerTipo.frame(maxWidth: 190)
            }
            // Arriba solo lo que dice QUÉ SE ESTÁ VIENDO: el mes y los filtros,
            // cada uno su botón. Juntos en uno, el botón parecía una etiqueta
            // y su menú mezclaba elegir periodo con abrir filtros, que no
            // tienen nada que ver. Ahora caben porque la lupa y el `+` se
            // fueron abajo.
            // **Un solo control, no dos.** El mes y los filtros son la misma
            // pregunta —qué recorte de la lista estoy viendo— y ocupaban dos
            // cápsulas seguidas. Ahora el botón DICE el mes, que es lo que
            // tiene que seguir viéndose arriba, y al pulsarlo la hoja abre con
            // el mes dentro, encima de la categoría y el estado.
            ToolbarItem(placement: .topBarTrailing) {
                botonFiltros
            }
        }
        // En iPad el `+` se queda arriba; en el teléfono baja a la barra
        // inferior, porque arriba conviven ya el segmentado, el mes, los
        // filtros y la lupa del sistema, y con cinco el segmentado se trunca.
        if !compacto {
            ToolbarItem(placement: .topBarTrailing) { botonNuevo }
        }
    }

    /// **La barra inferior del teléfono: lupa a la izquierda, resumen a la
    /// derecha.**
    ///
    /// Se dibuja aquí y no con `ToolbarItem(placement: .bottomBar)`, que sería
    /// lo natural, por una razón medida en pantalla: dentro del `TabView` de
    /// iPhone la barra inferior del sistema queda DEBAJO de la barra de
    /// pestañas flotante de iOS 26 y no se ve ninguna de las dos cosas. Con
    /// `safeAreaInset` la barra se apila por encima, que es lo que hace falta.
    ///
    /// A la izquierda va el `+` y no la lupa: la lupa la genera `.searchable`
    /// y el sistema no deja moverla aquí abajo (ver el comentario largo de
    /// `pantalla`). El `+` es entonces lo que baja, que es la salida que el
    /// propio encargo prevé cuando no cabe todo arriba.
    ///
    /// Va DENTRO de la barra y no flotando encima: con el total en la esquina
    /// derecha, un botón suelto ahí lo taparía.
    @ViewBuilder
    private var barraInferior: some View {
        if compacto {
            BarraInferior { botonNuevo } resumen: { resumenPie }
        }
    }

    /// El resumen de la lista: cuántos movimientos y cuánto suman.
    ///
    /// El conteo pierde la palabra pero NO el número: al borrarse el título se
    /// va también su subtítulo, así que este es el único sitio de la pantalla
    /// que dice cuántos hay, que es lo que revela si la lista está filtrada.
    ///
    /// El total pesa más que el conteo a propósito: es el dato de cuadre, el
    /// que el tesorero compara contra el estado financiero y contra el
    /// depósito. Iba en el mismo gris tenue que su etiqueta.
    private var resumenPie: some View {
        HStack(spacing: 6) {
            Text("\(vm.itemsFiltrados.count)")
                .foregroundStyle(.secondary)
            Text("·").foregroundStyle(.tertiary)
            Text(Money.firmado(vm.total, ingreso: vm.tipo == .ingreso))
                .fontWeight(.semibold)
                .foregroundStyle(Money.color(ingreso: vm.tipo == .ingreso))
        }
        .font(.footnote)
        .monospacedDigit()
    }

    /// Con el texto en las dos plataformas: en iPad cabe en la barra, y en el
    /// teléfono vive en la barra inferior, donde también sobra sitio. Un `+`
    /// suelto obliga a adivinar qué crea.
    private var botonNuevo: some View {
        Button {
            Task { hoja = .nueva(folio: await vm.nuevoFolio()) }
        } label: {
            Label(L.t("Nuevo", "New"), systemImage: "plus")
        }
        .buttonStyle(.glass)
        .tint(Paleta.brand)
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
            // El pie solo en iPad: en el teléfono se convirtió en la barra
            // inferior, con la lupa a la izquierda y el resumen a la derecha.
            .safeAreaInset(edge: .bottom, spacing: 0) { pieLista }
            .safeAreaInset(edge: .bottom, spacing: 0) { barraInferior }
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: puedeEliminar) {
                                if puedeEliminar {
                                    Button(role: .destructive) {
                                        movimientoAEliminar = m
                                    } label: {
                                        Label(L.t("Eliminar", "Delete"), systemImage: "trash")
                                    }
                                    // El tint del TabView tapa el rojo del rol.
                                    .tint(.red)
                                }
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
    /// **En el teléfono el botón dice el mes.** Al fundirse con el selector, el
    /// icono a secas habría escondido el único sitio donde se leía qué mes se
    /// está viendo, y eso es justo lo que la barra existe para decir. En iPad
    /// siguen siendo dos controles: allí hay ancho y la cabecera de la columna
    /// tiene sitio para los dos.
    private var botonFiltros: some View {
        Button { mostrarFiltros = true } label: {
            HStack(spacing: 5) {
                if compacto { Text(etiquetaMesCorta).lineLimit(1) }
                Image(systemName: "line.3.horizontal.decrease")
                if !compacto { Text(L.t("Filtros", "Filters")) }
                if filtrosActivos > 0 { contador(filtrosActivos) }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .tint(filtrosActivos > 0 || (compacto && vm.mes == nil) ? Paleta.brand : nil)
        .accessibilityLabel(compacto
                            ? L.t("Periodo y filtros: \(etiquetaMes)", "Period and filters: \(etiquetaMes)")
                            : L.t("Filtros", "Filters"))
    }

    /// Una opción de la hoja de filtros. `.buttonStyle(.plain)` por lo mismo
    /// que las de categoría: sin él el `Button` dentro del `List` pinta el
    /// label con el tint heredado del `TabView` y las opciones salen todas en
    /// verde.
    private func filaFiltro(_ texto: String, marcada: Bool,
                            _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text(texto).foregroundStyle(.primary)
                Spacer()
                if marcada {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Paleta.brand)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                // El periodo va PRIMERO: es el recorte más grande, el que
                // decide de qué mes se está hablando antes que de qué
                // categoría. En iPad esta sección no aparece porque allí el
                // mes tiene su propio selector en la cabecera de la columna.
                if compacto {
                    Section(L.t("PERIODO", "PERIOD")) {
                        ForEach(vm.mesesDisponibles, id: \.self) { m in
                            filaFiltro(Fechas.mes(m), marcada: vm.mes == m) { vm.mes = m }
                        }
                        filaFiltro(Self.todosLosMeses, marcada: vm.mes == nil) { vm.mes = nil }
                    }
                }
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
            .navigationTitle(compacto ? L.t("Periodo y filtros", "Period & filters")
                                      : L.t("Filtros", "Filters"))
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
                // cuando hay etiqueta, las filas marcadas eran más altas que
                // las demás y el monto se desplazaba hacia arriba: el ritmo de
                // la lista se rompía cada dos filas.
                let etiqueta = etiquetaEstado(m)
                Text(etiqueta ?? L.t("Sin depositar", "Not deposited"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Paleta.aviso)
                    .padding(.horizontal, Esp.hueco).padding(.vertical, 2)
                    .background(Paleta.avisoFill, in: Capsule())
                    .opacity(etiqueta == nil ? 0 : 1)
                    .accessibilityHidden(etiqueta == nil)
            }
        }
        .padding(.vertical, 6)
        // La selección persistente es idioma de iPad, donde la lista y el
        // detalle conviven. En iPhone la fila navega y volver dejaba la última
        // tocada con barra verde y fondo tintado, como si siguiera abierta.
        .filaDeLista(seleccionada: esSel && !compacto, tarjeta: compacto)
    }

    /// La señal de estado de una fila, si la hay. **Cada tipo tiene la suya**:
    /// "Sin depositar" es de ingresos —un gasto no entra en un corte— y
    /// "Pendiente" es de gastos.
    ///
    /// La fila solo sabía de la primera, así que un gasto marcado para revisar
    /// no llevaba ninguna marca en la lista, aunque el filtro "Marcados como
    /// pendientes" sí lo encontrara y la ficha sí lo dijera: se filtraba a
    /// ciegas y, al volver de la ficha, la lista no recordaba cuál era.
    private func etiquetaEstado(_ m: Movimiento) -> String? {
        if m.esIngreso {
            return m.sinDepositar ? L.t("Sin depositar", "Not deposited") : nil
        }
        return m.marcadoPendiente ? L.t("Pendiente", "Flagged") : nil
    }

    /// El pie de la columna del iPad. En el teléfono no existe: se convirtió
    /// en la barra inferior, con la lupa a la izquierda y el resumen a la
    /// derecha.
    @ViewBuilder
    private var pieLista: some View {
        if !compacto {
            HStack {
                Text(L.t("\(vm.itemsFiltrados.count) movimientos",
                         "\(vm.itemsFiltrados.count) entries"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Money.firmado(vm.total, ingreso: vm.tipo == .ingreso))
                    .monospacedDigit().fontWeight(.semibold)
                    .foregroundStyle(Money.color(ingreso: vm.tipo == .ingreso))
            }
            .font(.caption)
            .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
            // Igual que la cabecera: el material va donde hay algo que
            // difuminar.
            .background(.regularMaterial)
        }
    }
}
