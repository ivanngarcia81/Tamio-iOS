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
    @Environment(SesionSupabase.self) private var sesion: SesionSupabase?

    /// Dar de alta y de baja es de Secretaría. El tesorero puede llegar aquí
    /// —si la iglesia le abre el padrón— para mirar, no para mover a nadie.
    private var administraPadron: Bool { Permisos.vigentes(sesion).administraPadron }

    /// **La rama del teléfono.** Mismo criterio que en Ingresos y en
    /// Aportantes: no es "¿caben lista y detalle?" —eso lo decide el ancho—
    /// sino "¿los controles suben a la barra?", que solo tiene sentido en el
    /// teléfono. En iPad la barra es de la pantalla entera y el buscador
    /// acabaría lejos de la lista que filtra.
    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        pantalla
            .toolbar { barra }
            .task { await vm.cargar() }
            .onChange(of: subtab) { _, nuevo in
                vm.sincronizarSeleccion(enSeguimiento: nuevo == 2)
            }
            .sheet(isPresented: $mostrarFiltros) { filtrosSheet }
            .sheet(isPresented: $mostrarNuevo) {
                NuevoMiembroSheet(proximoId: vm.proximoId, puedeDarDeBaja: administraPadron) { nuevo in
                    vm.agregarMiembro(nuevo)
                }
            }
            .sheet(item: $miembroAEditar) { m in
                NuevoMiembroSheet(proximoId: m.id, miembroExistente: m,
                                  puedeDarDeBaja: administraPadron) { editado in
                    vm.editarMiembro(editado)
                }
            }
            .sheet(item: $miembroParaSeguimiento) { m in
                SeguimientoSheet(miembro: m) { nota in
                    vm.agregarSeguimiento(miembroId: m.id, nota: nota)
                }
            }
    }

    /// Teléfono: buscador nativo y el título en línea, con los controles en la
    /// barra. iPad: título y subtítulo como las demás pantallas, y los
    /// controles abajo, pegados a la lista que filtran.
    ///
    /// **El buscador no acompaña a Asistencia**: esa vista no es una lista de
    /// personas, así que la lupa no tendría nada que filtrar, y un campo de
    /// búsqueda que no busca es de las cosas que esta pantalla ya tenía.
    @ViewBuilder
    private var pantalla: some View {
        if compacto {
            if subtab == 1 {
                columnas
                    .navigationTitle(L.t("Membresía", "Membership"))
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                columnas
                    // La lupa se queda arriba por el límite del sistema que
                    // documenta `MovimientosView.pantalla`: con `.searchable`
                    // no hay forma de tenerla solo en la barra inferior.
                    .searchable(text: $vm.busqueda,
                                prompt: Text(L.t("Buscar por nombre o correo",
                                                 "Search by name or email")))
                    .searchToolbarBehavior(.minimize)
                    .navigationTitle(L.t("Membresía", "Membership"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            columnas
                .encabezadoNav(L.t("Membresía", "Membership"),
                               L.t("Padrón, altas, bajas y traslados",
                                   "Roster, additions, removals & transfers"))
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
                    panelDerecho
                }
            } else {
                contenidoCompacto
                    .navigationDestination(item: $abierto) { m in
                        // **La ficha se busca por id, no se usa la copia que
                        // abrió la pantalla.** `abierto` guarda un valor, y un
                        // valor no cambia: añadir un pariente o una nota de
                        // seguimiento escribía en el ViewModel y la ficha
                        // seguía enseñando la foto de antes, así que el botón
                        // parecía no hacer nada. En iPad no se notaba porque
                        // el panel derecho ya se leía de la lista.
                        let vigente = vm.items.first { $0.id == m.id } ?? m
                        MiembroDetalle(miembro: vigente, resumen: vm.resumen,
                                       // Y las dos hojas se abren con la ficha
                                       // vigente: con la copia, editar volvía
                                       // a cargar los datos de antes y al
                                       // guardar deshacía lo último.
                                       onEditar: { miembroAEditar = vigente },
                                       onSeguimiento: { miembroParaSeguimiento = vigente },
                                       onFiltrarAccion: { filtro in
                                           // La lista no está a la vista en
                                           // iPhone: aplicar el filtro sin
                                           // volver a ella no se vería.
                                           vm.filtroAccion = filtro
                                           subtab = 0
                                           abierto = nil
                                       },
                                       onAgregarPariente: { p in
                                           vm.agregarPariente(miembroId: m.id, pariente: p)
                                       },
                                       onQuitarPariente: { id in
                                           vm.quitarPariente(miembroId: m.id, parienteId: id)
                                       })
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
    }

    /// **Asistencia no existía en el teléfono.** El panel congregacional solo
    /// se dibujaba en la columna derecha del iPad, así que en el teléfono
    /// tocar "Asistencia" volvía a enseñar la lista de miembros: la pestaña
    /// cambiaba de nombre y no de contenido.
    @ViewBuilder
    private var contenidoCompacto: some View {
        if subtab == 1 { panelAsistencia } else { listaColumna }
    }

    // MARK: - Barra

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        // **En el teléfono, menú; en iPad, segmentado.** Es la medida que ya
        // se tomó en Aportantes: un segmentado de tres opciones conviviendo
        // con los filtros, el `+` y la lupa se parte en "Mie… Asi… Seg…", y en
        // inglés "Attendance" y "Follow-up" son más largas todavía. La
        // etiqueta del menú dice dónde estás y el menú las enseña enteras.
        if compacto {
            ToolbarItem(placement: .title) { menuVista }
            ToolbarItemGroup(placement: .topBarTrailing) {
                // En Asistencia no hay lista que filtrar, así que el botón no
                // se dibuja en vez de quedarse sin efecto.
                if subtab != 1 { botonFiltros }
                if administraPadron { botonNuevo }
            }
        } else if administraPadron {
            ToolbarItem(placement: .topBarTrailing) { botonNuevo }
        }
    }

    /// Las tres vistas del padrón. **El conteo va en la etiqueta**, como en
    /// las bandejas de Mail y como en Aportantes: al irse el pie de la lista
    /// del teléfono, este es el único sitio que dice cuántas personas se están
    /// viendo, y ese número es lo que revela que la lista está filtrada.
    private var menuVista: some View {
        Menu {
            ForEach(Self.vistas, id: \.0) { valor, nombre in
                Button { subtab = valor } label: {
                    if subtab == valor { Label(nombre, systemImage: "checkmark") }
                    else { Text(nombre) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                // Asistencia no cuenta personas: es la congregación entera.
                Text(subtab == 1
                     ? Self.nombreVista(1)
                     : "\(Self.nombreVista(subtab)) (\(conteoVista))")
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
    }

    /// Un solo sitio con los tres nombres: el menú del teléfono y el segmentado
    /// del iPad los leían por separado y podían separarse sin que nadie lo
    /// decidiera.
    private static var vistas: [(Int, String)] {
        [(0, L.t("Miembros", "Members")),
         (1, L.t("Asistencia", "Attendance")),
         (2, L.t("Seguimiento", "Follow-up"))]
    }

    private static func nombreVista(_ v: Int) -> String {
        vistas.first { $0.0 == v }?.1 ?? ""
    }

    private var conteoVista: Int {
        subtab == 2 ? vm.itemsSeguimiento.count : vm.itemsFiltrados.count
    }

    private var pickerVista: some View {
        Picker(L.t("Vista", "View"), selection: $subtab) {
            ForEach(Self.vistas, id: \.0) { valor, nombre in
                Text(nombre).tag(valor)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var botonNuevo: some View {
        Button { mostrarNuevo = true } label: {
            Label(L.t("Nuevo", "New"), systemImage: "plus")
        }
        .buttonStyle(.glass)
        .tint(Paleta.brand)
    }

    /// Botón de filtros. La cápsula, el borde y la sombra las pone `.glass`;
    /// el verde tiñe el material cuando hay algo aplicado y el contador dice
    /// cuánto. Esa señal no se puede perder: un filtro puesto explica una
    /// lista vacía.
    ///
    /// **En el teléfono, solo el icono**, como en Ingresos: las dos palabras
    /// gastan el ancho que necesitan la etiqueta de vista y el `+`.
    private var botonFiltros: some View {
        Button { mostrarFiltros = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                if !compacto { Text(L.t("Más filtros", "More filters")) }
                if filtrosActivos > 0 {
                    Text("\(filtrosActivos)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Paleta.brand, in: Circle())
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .tint(filtrosActivos > 0 ? Paleta.brand : nil)
        .accessibilityLabel(L.t("Más filtros", "More filters"))
    }

    // MARK: - Panel derecho según pestaña

    @ViewBuilder
    private var panelDerecho: some View {
        switch subtab {
        case 1:
            panelAsistencia
        default:
            let listActiva = subtab == 2 ? vm.itemsSeguimiento : vm.itemsFiltrados
            if let m = listActiva.first(where: { $0.id == vm.seleccionId }) ?? listActiva.first {
                MiembroDetalle(miembro: m, resumen: vm.resumen,
                               onEditar: { miembroAEditar = m },
                               onSeguimiento: { miembroParaSeguimiento = m },
                               onFiltrarAccion: { filtro in
                                   vm.filtroAccion = filtro
                                   subtab = 0
                               },
                               onAgregarPariente: { p in
                                   vm.agregarPariente(miembroId: m.id, pariente: p)
                               },
                               onQuitarPariente: { id in
                                   vm.quitarPariente(miembroId: m.id, parienteId: id)
                               })
            } else {
                ContentUnavailableView(L.t("Selecciona un miembro", "Select a member"),
                                       systemImage: "person.crop.circle")
                    .background(Color(.systemGroupedBackground))
            }
        }
    }

    /// El panel congregacional de asistencia, compartido por las dos ramas: en
    /// iPad ocupa la columna derecha y en el teléfono la pantalla entera.
    @ViewBuilder
    private var panelAsistencia: some View {
        if let a = vm.asistencia {
            PanelAsistencia(asistencia: a, masConstantes: vm.masConstantes,
                            ausentes: vm.itemsAusentes,
                            onVerSeguimiento: { subtab = 2 })
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Columna izquierda

    /// **Capas, no hermanos.** Mismo arreglo que en Ingresos y en Aportantes:
    /// la cabecera y el pie eran hermanos de la lista dentro de un `VStack`,
    /// así que una fila que subía al desplazarse se recortaba contra el borde
    /// del `VStack` y desaparecía de golpe en la línea del `Divider` —no había
    /// nada que difuminar porque nada llegaba a pasar por detrás— y el pie
    /// cortaba la última fila a media altura. Con `safeAreaInset` la lista
    /// ocupa todo y el contenido corre por debajo de las dos barras, que es lo
    /// único que le da al material algo que refractar.
    private var listaColumna: some View {
        lista
            .safeAreaInset(edge: .top, spacing: 0) { cabeceraLista }
            // **El pie, solo en iPad.** En el teléfono apilaba una segunda
            // barra sobre la de pestañas y cortaba la última fila; el conteo
            // que decía vive ahora en la etiqueta del menú de vista. En iPad
            // no hay barra de pestañas contra la que apilarse, y este pie es
            // el único sitio de la columna que dice cuántos hay.
            .safeAreaInset(edge: .bottom, spacing: 0) { pieLista }
            .colchonInferior()
    }

    /// La tira de controles. **En el teléfono queda reducida al aviso de
    /// filtro**: la vista, el buscador y los filtros viven en la barra. En
    /// iPad se queda entera —la barra es de la pantalla completa y estos
    /// controles filtran solo la columna— pero con los controles en glass en
    /// vez de dibujados a mano con `secondarySystemFill`.
    @ViewBuilder
    private var cabeceraLista: some View {
        if !compacto || vm.filtroAccion != nil {
            VStack(spacing: 10) {
                if !compacto {
                    pickerVista
                    if subtab != 1 {
                        buscadorColumna
                        // Se agrupan para que las dos cápsulas se fundan entre
                        // sí al acercarse, que es lo que hace un contenedor de
                        // glass.
                        GlassEffectContainer(spacing: Esp.hueco) {
                            HStack(spacing: Esp.hueco) {
                                menuAño
                                Spacer()
                                botonFiltros
                            }
                        }
                    }
                }
                avisoFiltroAccion
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.vertical, compacto ? Esp.hueco : Esp.chip)
            // El material vive AQUÍ, no detrás de la columna entera: detrás de
            // la lista se resolvía como un gris plano porque no tenía nada que
            // difuminar.
            .background(.regularMaterial)
        }
    }

    /// El filtro que llega desde los indicadores de la ficha del miembro. Se
    /// queda también en el teléfono: es lo único que explica por qué la lista
    /// se ha quedado corta, y el globito del botón dice cuántos filtros hay
    /// pero no cuál.
    @ViewBuilder
    private var avisoFiltroAccion: some View {
        if let etiqueta = vm.etiquetaFiltroAccion {
            HStack(spacing: 6) {
                Text(etiqueta).font(.subheadline.weight(.medium))
                Button { vm.filtroAccion = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Paleta.aviso)
            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
            .background(Capsule().fill(Paleta.avisoFill))
            .overlay(Capsule().stroke(Paleta.avisoStroke, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// El buscador de la columna del iPad. No usa `.searchable` a propósito:
    /// ese lo coloca el sistema en la barra de la pantalla, que en iPad está
    /// encima de las dos columnas y del detalle. Filtra esta lista, así que
    /// vive pegado a ella. Lo que se va es el `RoundedRectangle` con
    /// `tertiarySystemFill` que hacía de fondo.
    private var buscadorColumna: some View {
        HStack(spacing: Esp.hueco) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L.t("Buscar por nombre o correo", "Search by name or email"),
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

    /// El año de ingreso, solo en iPad. En el teléfono no hay cápsula libre en
    /// la barra, así que baja a la hoja de filtros y allí sí cuenta en el
    /// globito — ver `filtrosActivos`.
    private var menuAño: some View {
        Menu {
            Button { vm.filtroAño = nil } label: {
                if vm.filtroAño == nil { Label(Self.todosLosAños, systemImage: "checkmark") }
                else { Text(Self.todosLosAños) }
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
                Text(etiquetaAño)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
        .tint(vm.filtroAño != nil ? Paleta.brand : nil)
    }

    private static let todosLosAños = L.t("Todos los años", "All years")

    private var etiquetaAño: String {
        vm.filtroAño.map { L.t("Año \(String($0))", "Year \(String($0))") } ?? Self.todosLosAños
    }

    /// El pie de la columna del iPad. En el teléfono devuelve vacío: no queda
    /// un `safeAreaInset` reservando altura en su lugar.
    @ViewBuilder
    private var pieLista: some View {
        if !compacto {
            HStack {
                Text(textoPie)
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
    }

    private var textoPie: String {
        let total = conteoVista
        let roster = vm.items.count
        if subtab == 2 {
            return L.t("\(total) de \(roster) miembros", "\(total) of \(roster) members")
        }
        let hayFiltros = vm.filtroAño != nil || filtrosActivos > 0 || !vm.busqueda.isEmpty
        return hayFiltros
            ? L.t("\(total) de \(roster) en el padrón", "\(total) of \(roster) on the roster")
            : L.t("\(roster) miembros en el padrón", "\(roster) members on the roster")
    }

    @ViewBuilder
    private var lista: some View {
        if subtab == 2 && vm.itemsSeguimiento.isEmpty {
            ContentUnavailableView(L.t("Sin alertas", "No alerts"),
                                   systemImage: "checkmark.circle",
                                   description: Text(L.t("Todos los miembros están al corriente.", "All members are up to date.")))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else {
            // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`, no
            // `insetGrouped`, que metía la lista un escalón más que la cabecera.
            listaCuerpo
                .listStyle(.plain)
                // El suelo va en la LISTA, no en la columna: detrás de la
                // columna entera el material no tenía nada que difuminar y se
                // resolvía como un gris plano.
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                // El desvanecido de borde: la fila deja de aparecer y
                // desaparecer de golpe al cruzar por detrás de la cabecera.
                // Sustituye al margen de scroll que había como parche, de
                // cuando la cabecera todavía era hermana de la lista.
                .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    @ViewBuilder
    private var listaCuerpo: some View {
        List {
            if subtab == 2 {
                ForEach(vm.itemsSeguimiento) { m in
                    filaSeguimiento(m)
                        .contentShape(Rectangle())
                        .onTapGesture { abrir(m) }
                }
            } else {
                ForEach(vm.itemsFiltrados) { m in
                    filaMiembro(m)
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
            Avatar(iniciales: m.iniciales, color: m.estado.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.nombre).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(m.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                // Sin guion cuando no hay dato: un "—" suelto se lee como un
                // fallo de render. Quien está de baja no tiene asistencia que
                // enseñar y su pastilla ya lo dice.
                if !m.estado.esBaja {
                    Text("\(m.asistenciaPct)%")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(colorPct(m.asistenciaPct))
                }
                Pill(texto: m.estado.etiqueta, color: m.estado.color)
            }
        }
        .padding(.vertical, 10)
        .filaDeLista(seleccionada: esSel, tarjeta: sizeClass != .regular)
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
        .padding(.vertical, 10)
        .filaDeLista(seleccionada: esSel, tarjeta: sizeClass != .regular)
    }

    // MARK: - Helpers

    /// **El año cuenta como filtro solo en el teléfono.** En iPad tiene chip
    /// propio, que ya se tiñe de verde cuando hay uno puesto, y contarlo aquí
    /// dejaría el globito encendido por partida doble. En el teléfono el año
    /// vive dentro de la hoja, así que si no se cuenta aquí no se cuenta en
    /// ningún sitio: una lista corta no se explica sola. Es la misma lección
    /// que dejó Ingresos, donde el periodo no se contaba y la lista de un mes
    /// que no era el actual no decía por qué era corta.
    private var filtrosActivos: Int {
        (vm.filtroEstado != nil ? 1 : 0) + (vm.filtroMinisterio != nil ? 1 : 0)
            + (vm.filtroAccion != nil ? 1 : 0)
            + (compacto && vm.filtroAño != nil ? 1 : 0)
    }

    private var filtrosSheet: some View {
        NavigationStack {
            List {
                // **El año solo aquí en el teléfono.** Arriba no queda cápsula
                // libre —la etiqueta de vista, los filtros, el `+` y la lupa
                // ya son cuatro, y la quinta el sistema la tira sin avisar—,
                // así que el chip de año baja a la hoja. En iPad se queda en la
                // cabecera de la columna y esta sección no se dibuja.
                if compacto && !vm.añosDisponibles.isEmpty {
                    Section(L.t("AÑO DE INGRESO", "YEAR JOINED")) {
                        filaFiltro(Self.todosLosAños, activo: vm.filtroAño == nil) {
                            vm.filtroAño = nil
                        }
                        ForEach(vm.añosDisponibles, id: \.self) { año in
                            filaFiltro(String(año), activo: vm.filtroAño == año) {
                                vm.filtroAño = año
                            }
                        }
                    }
                }
                Section(L.t("ESTADO", "STATUS")) {
                    filaFiltro(L.t("Todos", "All"), activo: vm.filtroEstado == nil) {
                        vm.filtroEstado = nil
                    }
                    ForEach(EstadoMiembro.claves, id: \.self) { c in
                        filaFiltro(EstadoMiembro.etiqueta(clave: c),
                                   activo: vm.filtroEstado == c) { vm.filtroEstado = c }
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
            // `.inset` y no `.insetGrouped`: la hoja ya es una superficie, y
            // el estilo agrupado metía otra tarjeta con fondo dentro de ella.
            .listStyle(.inset)
            .navigationTitle(L.t("Filtros", "Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Mismo criterio que la hoja de filtros de Ingresos: uno
                // destruye y el otro confirma, así que no pueden pesar igual ni
                // compartir el verde de marca.
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t("Limpiar", "Clear")) {
                        vm.filtroEstado = nil
                        vm.filtroMinisterio = nil
                        vm.filtroAccion = nil
                        // El año se limpia solo donde se pone: en iPad su chip
                        // vive fuera de esta hoja y borrarlo desde aquí sería
                        // deshacer algo que no se ve.
                        if compacto { vm.filtroAño = nil }
                    }
                    .disabled(filtrosActivos == 0)
                }
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
    /// Lleva a la vista de Seguimiento, que es donde se resuelven las
    /// ausencias que esta tarjeta enumera. El botón existía desde el principio
    /// con la acción vacía: prometía un sitio al que ir y no iba a ninguno.
    let onVerSeguimiento: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                graficaMeses
                kpisAsistencia
                porTipoServicio
                masConstantesSeccion
                sinAsistirSeccion
            }
            .padding(Esp.panel)
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
    /// **Cuatro en fila solo caben en la columna del iPad.** Este panel ahora
    /// también es la pantalla de Asistencia del teléfono, y a 390 pt las
    /// cuatro tarjetas salían de unos 85 pt: "Presentes en promedio" ocupaba
    /// tres renglones encima de su número. En compacto van de dos en dos.
    private var kpisAsistencia: some View {
        let columnas: [GridItem] = sizeClass == .compact
            ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            : Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
        return LazyVGrid(columns: columnas, spacing: 12) {
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
                        Avatar(iniciales: m.iniciales, color: m.estado.color, lado: 30)
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
                    Button { onVerSeguimiento() } label: {
                        Text(L.t("Ver seguimiento", "View follow-up"))
                            .font(.caption).foregroundStyle(Paleta.enlace)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)

                if ausentes.isEmpty {
                    Text(L.t("Todos asistieron recientemente.", "Everyone attended recently."))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(ausentes) { m in
                        HStack(spacing: 10) {
                            Avatar(iniciales: m.iniciales, color: m.estado.color, lado: 30)
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
    let proximoId: String
    let miembroExistente: Miembro?
    /// La baja es un acto de Secretaría; a quien no le toca, ni se le enseña
    /// el interruptor.
    let puedeDarDeBaja: Bool
    let onGuardar: (Miembro) -> Void

    // QUIÉN ES
    @State private var nombre: String
    @State private var telefono: String
    @State private var correo: String

    // MEMBRESÍA
    /// El estado dentro del registro, y aparte la baja: son cosas distintas
    /// y en el servidor son columnas distintas. Ver `EstadoMiembro`.
    @State private var registro: EstadoRegistro
    @State private var fechaIngreso: Date
    /// Una baja no es solo un cambio de etiqueta: hay que poder decir cuándo y
    /// por qué, o dentro de dos años nadie sabrá qué pasó con esa persona.
    @State private var deBaja = false
    @State private var fechaBaja = Date()
    /// Clave del catálogo; con "otro", lo que se escriba en `motivoOtro`.
    @State private var motivoBaja = "traslado"
    @State private var motivoOtro = ""

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

    init(proximoId: String, miembroExistente: Miembro? = nil, puedeDarDeBaja: Bool,
         onGuardar: @escaping (Miembro) -> Void) {
        self.proximoId = proximoId
        self.miembroExistente = miembroExistente
        self.puedeDarDeBaja = puedeDarDeBaja
        self.onGuardar = onGuardar

        guard let m = miembroExistente else {
            _nombre = State(initialValue: "")
            _telefono = State(initialValue: "")
            _correo = State(initialValue: "")
            _registro = State(initialValue: .activo)
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
        _registro = State(initialValue: m.estado.registro)
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

        let interesStr = d("Ministerios de interés", "Ministries of interest")
        _ministeriosInteres = State(initialValue: interesStr.isEmpty
                                    ? [] : Set(interesStr.components(separatedBy: ", ")))

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

        _disponibilidad = State(initialValue: d("Disponibilidad", "Availability"))
        _interesServir = State(initialValue: flag("Interés en servir", "Interested in serving"))

        // La baja se lee del estado, no de `datos`: antes se guardaba como un
        // par etiqueta-valor y no se volvía a leer, así que al editar a
        // alguien dado de baja la fecha volvía a hoy y el motivo en blanco.
        if let baja = m.estado.baja {
            _deBaja = State(initialValue: true)
            _fechaBaja = State(initialValue: Fechas.desdeTextoFlexible(baja.fecha) ?? Date())
            let esDelCatalogo = Baja.motivos.contains(baja.motivo) && baja.motivo != "otro"
            _motivoBaja = State(initialValue: esDelCatalogo ? baja.motivo : "otro")
            _motivoOtro = State(initialValue: esDelCatalogo ? "" : baja.motivo)
        }

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
        instrumentos.count + instrumentosCustom.count + habilidades.count + habilidadesCustom.count +
        // Los tres que la página pedía y el guardado tiraba: si no cuentan
        // aquí, rellenarlos deja la fila con el mismo número que antes.
        ministeriosInteres.count + (disponibilidad.isEmpty ? 0 : 1) + (interesServir ? 1 : 0)
    }
    private var cntDatos: Int {
        (tieneFechaNac ? 1 : 0) + (estadoCivil != "Sin especificar" ? 1 : 0) + (!direccion.isEmpty ? 1 : 0)
    }
    private var cntMas: Int {
        (!idFiscal.isEmpty ? 1 : 0) + (!notas.isEmpty ? 1 : 0) +
        (!iglesiaAnterior.isEmpty ? 1 : 0) + (tieneRecibido ? 1 : 0)
    }

    private static let fmtCorto: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = L.t("d MMM yyyy", "MMM d, yyyy"); f.locale = L.locale; return f
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

                Section {
                    // Los cuatro del registro, con las claves del app web.
                    // "Nuevo" y "Recibido" ya no se eligen: se deducen de la
                    // fecha de ingreso y de la iglesia anterior. Y "Traslado"
                    // era un expediente, no un estado.
                    Picker(L.t("Estado", "Status"), selection: $registro) {
                        ForEach(EstadoRegistro.allCases, id: \.self) {
                            Text($0.etiqueta).tag($0)
                        }
                    }
                    DatePicker(L.t("Comenzó a congregarse", "Started attending"),
                               selection: $fechaIngreso, displayedComponents: .date)
                        .tint(Paleta.brand)
                } header: {
                    Text(L.t("MEMBRESÍA", "MEMBERSHIP"))
                }

                // **La baja va aparte del estado**, como en el servidor: la
                // persona conserva el estado que tenía y se le añade cuándo y
                // por qué se fue. Solo la ve quien puede darla.
                if puedeDarDeBaja {
                    Section {
                        Toggle(L.t("Dar de baja del padrón", "Remove from roster"), isOn: $deBaja)
                            .tint(Paleta.negativo)
                        if deBaja {
                            DatePicker(L.t("Fecha de baja", "Removal date"),
                                       selection: $fechaBaja, displayedComponents: .date)
                                .tint(Paleta.brand)
                            Picker(L.t("Motivo", "Reason"), selection: $motivoBaja) {
                                ForEach(Baja.motivos, id: \.self) {
                                    Text(Baja.etiquetaMotivo($0)).tag($0)
                                }
                            }
                            if motivoBaja == "otro" {
                                TextField(L.t("¿Cuál?", "Which?"), text: $motivoOtro, axis: .vertical)
                                    .lineLimit(2...4)
                            }
                        }
                    } header: {
                        Text(L.t("BAJA", "REMOVAL"))
                    } footer: {
                        if deBaja {
                            Text(L.t("La persona sale del padrón activo. Su historial y sus aportes se conservan.",
                                     "The person leaves the active roster. Their history and giving are kept."))
                        }
                    }
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
        .hojaFormulario()
    }

    private func badgeRow(_ titulo: String, count: Int) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Esp.hueco).padding(.vertical, 3)
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
        // La baja vive en el estado. Aquí solo se enseña, para que en la
        // ficha no quede como una etiqueta gris sin explicación.
        let estadoFinal: EstadoMiembro
        if deBaja {
            let motivo = motivoBaja == "otro" ? motivoOtro.trimmingCharacters(in: .whitespaces) : motivoBaja
            estadoFinal = .baja(Fechas.claveDia(fechaBaja), motivo, registro: registro)
            datos.append(Dato(etiqueta: L.t("Fecha de baja", "Removal date"), valor: fmt.string(from: fechaBaja)))
            datos.append(Dato(etiqueta: L.t("Motivo", "Reason"),
                              valor: motivoBaja == "otro" ? motivo : Baja.etiquetaMotivo(motivo)))
        } else {
            estadoFinal = EstadoMiembro(registro: registro, baja: nil)
        }
        // Lo que antes eran dos estados y ahora son dos hechos de la ficha.
        let esRecibido = !iglesiaAnterior.trimmingCharacters(in: .whitespaces).isEmpty
        let esNuevo = año == Calendar.current.component(.year, from: Date())
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
        // **Los tres campos que se escribían en el vacío.** "Ministerios de
        // interés", la disponibilidad y el interés en servir se pedían en
        // Servicio y habilidades y no llegaban a `datos`: al guardar
        // desaparecían, y al reabrir la ficha volvían vacíos. Son justo los
        // datos con los que se arma un equipo, así que no podían ser los
        // únicos que no sobrevivían a Guardar.
        if !ministeriosInteres.isEmpty {
            datos.append(Dato(etiqueta: L.t("Ministerios de interés", "Ministries of interest"),
                              valor: ministeriosInteres.sorted().joined(separator: ", ")))
        }
        if !disponibilidad.trimmingCharacters(in: .whitespaces).isEmpty {
            datos.append(Dato(etiqueta: L.t("Disponibilidad", "Availability"), valor: disponibilidad))
        }
        if interesServir {
            datos.append(Dato(etiqueta: L.t("Interés en servir", "Interested in serving"), valor: "✓"))
        }
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
        if esRecibido {
            subtitulo = L.t("Recibido por traslado · 0%", "Received by transfer · 0%")
        } else if esNuevo {
            subtitulo = L.t("Nuevo · 0%", "New · 0%")
        } else {
            subtitulo = L.t("Ingresó \(String(año)) · \(areaFinal.lowercased()) · 0%",
                            "Joined \(String(año)) · \(areaFinal.lowercased()) · 0%")
        }

        let movimientos: [MovMembresia]
        if let m = miembroExistente {
            movimientos = [MovMembresia(titulo: L.t("Información actualizada", "Information updated"), fecha: fechaStr)] + m.movimientos
        } else {
            let tituloAlta = esRecibido
                ? L.t("Recibido por traslado", "Received by transfer")
                : L.t("Alta como miembro", "Added as member")
            movimientos = [MovMembresia(titulo: tituloAlta, fecha: fechaStr)]
        }

        return Miembro(
            id: miembroExistente?.id ?? proximoId,
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            subtitulo: subtitulo,
            estado: estadoFinal,
            asistenciaPct: miembroExistente?.asistenciaPct ?? 0,
            area: areaFinal,
            miembroDesde: L.t("Ingresó \(String(año))", "Joined \(String(año))"),
            asistencia: miembroExistente?.asistencia ?? [],
            enRoster: miembroExistente?.enRoster ?? "0 de 27",
            rachaSinAsistir: miembroExistente?.rachaSinAsistir ?? L.t("0 servicios", "0 services"),
            ultimaVisita: miembroExistente?.ultimaVisita ?? "—",
            seguimientoRazon: miembroExistente?.seguimientoRazon ?? (esNuevo ? L.t("Nuevo en el periodo", "New in the period") : nil),
            ausenciaNota: miembroExistente?.ausenciaNota,
            datos: datos,
            expediente: expediente,
            movimientos: movimientos,
            seguimientoNotas: miembroExistente?.seguimientoNotas ?? [],
            // **Sin esta línea, "Guardar cambios" borraba los parentescos.**
            // `familia` tiene `= []` por defecto, así que omitirla no era
            // dejarla igual: era vaciarla. Los parentescos se dan de alta en
            // la ficha del miembro, de modo que bastaba con editar cualquier
            // otro dato para perderlos sin aviso.
            familia: miembroExistente?.familia ?? []
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
                            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
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
        f.locale = L.locale
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Avatar(iniciales: miembro.iniciales, color: miembro.estado.color, lado: 44)
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
        .hojaFormulario()
    }
}
