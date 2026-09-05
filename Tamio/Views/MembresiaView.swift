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
                            filaFiltro(Padron.etiqueta(min), activo: vm.filtroMinisterio == min) { vm.filtroMinisterio = min }
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

/// Alta y edición. **Se lee y se escribe sobre los campos de `Miembro`**, no
/// sobre una lista de pares etiqueta-valor: antes cada campo se guardaba como
/// `Dato("Correo", …)` y al editar se buscaba por la etiqueta traducida, y
/// por ahí se perdían tres campos de Servicio y la fecha de la baja. Ahora no
/// hay traducción de ida y vuelta: la hoja edita una copia y la devuelve.
private struct NuevoMiembroSheet: View {
    let proximoId: String
    let miembroExistente: Miembro?
    /// La baja es un acto de Secretaría; a quien no le toca, ni se le enseña
    /// el interruptor.
    let puedeDarDeBaja: Bool
    let onGuardar: (Miembro) -> Void

    /// La ficha que se está editando. Empieza como copia de la existente o
    /// vacía, y `Guardar` la devuelve tal cual.
    @State private var m: Miembro

    // Lo que la hoja pide con controles que no son el campo: fechas como
    // `Date` y la baja con su interruptor.
    @State private var fechaIngreso: Date
    @State private var tieneFechaNac: Bool
    @State private var fechaNacimiento: Date
    @State private var tieneCongrega: Bool
    @State private var fechaCongrega: Date
    @State private var deBaja: Bool
    @State private var fechaBaja: Date
    /// Clave del catálogo; con "otro", lo que se escriba en `motivoOtro`.
    @State private var motivoBaja: String
    @State private var motivoOtro: String

    @Environment(\.dismiss) private var dismiss

    init(proximoId: String, miembroExistente: Miembro? = nil, puedeDarDeBaja: Bool,
         onGuardar: @escaping (Miembro) -> Void) {
        self.proximoId = proximoId
        self.miembroExistente = miembroExistente
        self.puedeDarDeBaja = puedeDarDeBaja
        self.onGuardar = onGuardar

        let base = miembroExistente ?? Miembro(id: proximoId, nombre: "")
        _m = State(initialValue: base)
        _fechaIngreso = State(initialValue: Fechas.desdeTextoFlexible(base.fechaIngreso) ?? Date())
        _tieneFechaNac = State(initialValue: !base.nacimiento.isEmpty)
        _fechaNacimiento = State(initialValue: Fechas.desdeTextoFlexible(base.nacimiento) ?? Date())
        _tieneCongrega = State(initialValue: !base.fechaCongregacion.isEmpty)
        _fechaCongrega = State(initialValue: Fechas.desdeTextoFlexible(base.fechaCongregacion) ?? Date())

        // La baja se lee del estado, no de `datos`: antes se guardaba como un
        // par etiqueta-valor y no se volvía a leer, así que al editar a
        // alguien dado de baja la fecha volvía a hoy y el motivo en blanco.
        let baja = base.estado.baja
        _deBaja = State(initialValue: baja != nil)
        _fechaBaja = State(initialValue: Fechas.desdeTextoFlexible(baja?.fecha ?? "") ?? Date())
        let delCatalogo = baja.map { Baja.motivos.contains($0.motivo) && $0.motivo != "otro" } ?? false
        _motivoBaja = State(initialValue: delCatalogo ? baja!.motivo : (baja == nil ? "traslado" : "otro"))
        _motivoOtro = State(initialValue: delCatalogo || baja == nil ? "" : baja!.motivo)
    }

    private var puedeGuardar: Bool { !m.nombre.trimmingCharacters(in: .whitespaces).isEmpty }

    private var cntVida: Int {
        (m.bautizadoAgua ? 1 : 0) + (m.bautizadoEspiritu ? 1 : 0) + (m.cursoMembresia ? 1 : 0)
    }
    private var cntServicio: Int {
        m.ministerios.count + m.cargos.count + m.instrumentos.count + m.habilidades.count
        + m.ministeriosInteres.count + (m.disponibilidad.isEmpty ? 0 : 1) + (m.interesServir ? 1 : 0)
    }
    private var cntDatos: Int {
        (tieneFechaNac ? 1 : 0) + (m.estadoCivil.isEmpty ? 0 : 1) + (m.direccion.isEmpty ? 0 : 1)
    }
    private var cntMas: Int {
        (m.idFiscal.isEmpty ? 0 : 1) + (m.notas.isEmpty ? 0 : 1)
        + (m.iglesiaAnterior.isEmpty ? 0 : 1) + (tieneCongrega ? 1 : 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("QUIÉN ES", "WHO THEY ARE")) {
                    TextField(L.t("Nombre completo o de familia", "Full name or family name"), text: $m.nombre)
                    HStack {
                        Text(L.t("Teléfono", "Phone")).foregroundStyle(.primary)
                        Text(L.t("(opcional)", "(optional)")).foregroundStyle(.secondary).font(.subheadline)
                        Spacer()
                        TextField("81 1234 5678", text: $m.telefono)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L.t("Correo", "Email")).foregroundStyle(.primary)
                        Text(L.t("(opcional)", "(optional)")).foregroundStyle(.secondary).font(.subheadline)
                        Spacer()
                        TextField("correo@ejemplo.com", text: $m.correo)
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
                    Picker(L.t("Estado", "Status"), selection: $m.estado.registro) {
                        ForEach(EstadoRegistro.allCases, id: \.self) {
                            Text($0.etiqueta).tag($0)
                        }
                    }
                    DatePicker(L.t("Recibido como miembro", "Received as member"),
                               selection: $fechaIngreso, displayedComponents: .date)
                        .tint(Paleta.brand)
                } header: {
                    Text(L.t("MEMBRESÍA", "MEMBERSHIP"))
                } footer: {
                    Text(L.t("La fecha de ingreso es la que cuenta como alta en los informes.",
                             "The join date is what counts as an addition in reports."))
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
                        VidaEspiritualPage(m: $m)
                    } label: { badgeRow(L.t("Vida espiritual", "Spiritual life"), count: cntVida) }
                    NavigationLink {
                        ServicioHabilidadesPage(m: $m)
                    } label: { badgeRow(L.t("Servicio y habilidades", "Service & skills"), count: cntServicio) }
                    NavigationLink {
                        DatosPersonaPage(m: $m, tieneFecha: $tieneFechaNac, fechaNacimiento: $fechaNacimiento)
                    } label: { badgeRow(L.t("Datos de la persona", "Personal data"), count: cntDatos) }
                    NavigationLink {
                        MasDatosPage(m: $m, tieneCongrega: $tieneCongrega, fechaCongrega: $fechaCongrega)
                    } label: { badgeRow(L.t("Más datos personales", "More personal data"), count: cntMas) }
                } header: {
                    Text(L.t("COMPLETAR AHORA (OPCIONAL)", "COMPLETE NOW (OPTIONAL)"))
                } footer: {
                    Text(L.t("El ID fiscal, las notas, la iglesia anterior y desde cuándo se congrega están aquí dentro.",
                              "Tax ID, notes, previous church, and attendance start date are inside."))
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

    /// La copia editada, con las fechas y la baja puestas en su sitio. Nada
    /// más: lo que la ficha enseña lo calcula `Miembro`.
    private func construirMiembro() -> Miembro {
        var r = m
        r.nombre = m.nombre.trimmingCharacters(in: .whitespaces)
        r.fechaIngreso = Fechas.claveDia(fechaIngreso)
        r.nacimiento = tieneFechaNac ? Fechas.claveDia(fechaNacimiento) : ""
        r.fechaCongregacion = tieneCongrega ? Fechas.claveDia(fechaCongrega) : ""
        if deBaja {
            let motivo = motivoBaja == "otro" ? motivoOtro.trimmingCharacters(in: .whitespaces) : motivoBaja
            r.estado.baja = Baja(fecha: Fechas.claveDia(fechaBaja), motivo: motivo)
        } else {
            r.estado.baja = nil
        }
        return r
    }
}

// MARK: - Sub-página: Vida espiritual

private struct VidaEspiritualPage: View {
    @Binding var m: Miembro

    var body: some View {
        Form {
            Section {
                Toggle(L.t("Bautizado en agua", "Baptized in water"), isOn: $m.bautizadoAgua)
                    .tint(Paleta.brand)
                if m.bautizadoAgua {
                    FechaOpcional(titulo: L.t("Fecha del bautismo", "Baptism date"), texto: $m.fechaBautismoAgua)
                }
                Toggle(L.t("Bautizado con el Espíritu Santo", "Baptized with the Holy Spirit"), isOn: $m.bautizadoEspiritu)
                    .tint(Paleta.brand)
                if m.bautizadoEspiritu {
                    FechaOpcional(titulo: L.t("Fecha", "Date"), texto: $m.fechaBautismoEspiritu)
                }
                Toggle(L.t("Curso de membresía completado", "Membership course completed"), isOn: $m.cursoMembresia)
                    .tint(Paleta.brand)
            } footer: {
                Text(L.t("La fecha es opcional: lo que la secretaria suele saber es si pasó, no cuándo.",
                         "The date is optional: what's usually known is whether it happened, not when."))
            }
        }
        .navigationTitle(L.t("Vida espiritual", "Spiritual life"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Una fecha "YYYY-MM-DD" que puede no saberse. El interruptor dice si se
/// sabe; el `DatePicker` solo aparece cuando sí.
private struct FechaOpcional: View {
    let titulo: String
    @Binding var texto: String
    @State private var conocida: Bool
    @State private var fecha: Date

    init(titulo: String, texto: Binding<String>) {
        self.titulo = titulo
        _texto = texto
        _conocida = State(initialValue: !texto.wrappedValue.isEmpty)
        _fecha = State(initialValue: Fechas.desdeTextoFlexible(texto.wrappedValue) ?? Date())
    }

    var body: some View {
        Toggle(L.t("\(titulo) conocida", "\(titulo) known"), isOn: $conocida)
            .tint(Paleta.brand)
            .onChange(of: conocida) { _, on in texto = on ? Fechas.claveDia(fecha) : "" }
        if conocida {
            DatePicker(titulo, selection: $fecha, displayedComponents: .date)
                .tint(Paleta.brand)
                .onChange(of: fecha) { _, d in texto = Fechas.claveDia(d) }
        }
    }
}

// MARK: - Sub-página: Servicio y habilidades

private struct ServicioHabilidadesPage: View {
    @Binding var m: Miembro

    var body: some View {
        Form {
            ChipSection(titulo: L.t("MINISTERIOS EN LOS QUE SIRVE", "MINISTRIES THEY SERVE IN"),
                        catalogo: Padron.ministerios, seleccionados: $m.ministerios,
                        placeholder: L.t("Otro ministerio…", "Other ministry…"))
            ChipSection(titulo: L.t("CARGOS Y FUNCIONES", "ROLES & FUNCTIONS"),
                        catalogo: Padron.cargos, seleccionados: $m.cargos,
                        placeholder: L.t("Otro cargo o función…", "Other role or function…"))
            ChipSection(titulo: L.t("MINISTERIOS DE INTERÉS", "MINISTRIES OF INTEREST"),
                        catalogo: Padron.ministerios, seleccionados: $m.ministeriosInteres,
                        placeholder: "")
            ChipSection(titulo: L.t("INSTRUMENTOS QUE TOCA", "INSTRUMENTS PLAYED"),
                        catalogo: Padron.instrumentos, seleccionados: $m.instrumentos,
                        placeholder: L.t("Otro instrumento…", "Other instrument…"))
            ChipSection(titulo: L.t("OFICIOS Y HABILIDADES", "TRADES & SKILLS"),
                        catalogo: Padron.habilidades, seleccionados: $m.habilidades,
                        placeholder: L.t("Otro oficio o habilidad…", "Other trade or skill…"))
            Section {
                TextField(L.t("Disponibilidad para servir", "Availability to serve"), text: $m.disponibilidad)
                Toggle(L.t("Interés en servir en algún ministerio", "Interested in serving"), isOn: $m.interesServir)
                    .tint(Paleta.brand)
            }
        }
        .navigationTitle(L.t("Servicio y habilidades", "Service & skills"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-página: Datos de la persona

private struct DatosPersonaPage: View {
    @Binding var m: Miembro
    @Binding var tieneFecha: Bool
    @Binding var fechaNacimiento: Date

    var body: some View {
        Form {
            Section {
                Toggle(L.t("Fecha de nacimiento conocida", "Birth date known"), isOn: $tieneFecha)
                    .tint(Paleta.brand)
                if tieneFecha {
                    DatePicker(L.t("Nacimiento", "Birth"), selection: $fechaNacimiento, displayedComponents: .date)
                        .tint(Paleta.brand)
                }
                // Claves del web. Sin valor no es "soltero": es que no se ha
                // preguntado, y así se guarda.
                Picker(L.t("Estado civil", "Marital status"), selection: $m.estadoCivil) {
                    Text(L.t("Sin especificar", "Not specified")).tag("")
                    ForEach(Padron.estadosCiviles, id: \.self) { Text(Padron.etiqueta($0)).tag($0) }
                }
                TextField(L.t("Dirección (opcional)", "Address (optional)"), text: $m.direccion)
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
    @Binding var m: Miembro
    @Binding var tieneCongrega: Bool
    @Binding var fechaCongrega: Date

    var body: some View {
        Form {
            Section {
                TextField(L.t("ID fiscal (opcional)", "Tax ID (optional)"), text: $m.idFiscal)
                    .autocorrectionDisabled()
                TextField(L.t("Notas (opcional)", "Notes (optional)"), text: $m.notas, axis: .vertical)
                    .lineLimit(2...5)
                TextField(L.t("Iglesia anterior (si aplica)", "Previous church (if applicable)"),
                          text: $m.iglesiaAnterior)
                Toggle(L.t("Se congrega desde", "Attends since"), isOn: $tieneCongrega)
                    .tint(Paleta.brand)
                if tieneCongrega {
                    DatePicker(L.t("Desde", "Since"), selection: $fechaCongrega, displayedComponents: .date)
                        .tint(Paleta.brand)
                }
            } footer: {
                Text(L.t("Con iglesia anterior, la ficha se lee como recibida por traslado. El ID fiscal hace falta para constancias deducibles.",
                          "With a previous church, the profile reads as received by transfer. The tax ID is needed for deductible receipts."))
            }
        }
        .navigationTitle(L.t("Más datos personales", "More personal data"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Componente: Sección de chips con agregar custom

/// Chips sobre un catálogo de CLAVES. Lo elegido —del catálogo o escrito a
/// mano— va a la misma lista, que es la que se guarda: una clave que no está
/// en el catálogo es texto libre y se pinta tal cual.
private struct ChipSection: View {
    let titulo: String
    let catalogo: [String]
    @Binding var seleccionados: [String]
    let placeholder: String

    @State private var nuevoTexto = ""

    /// El catálogo más lo escrito a mano que ya esté elegido, sin repetir.
    private var opciones: [String] {
        catalogo + seleccionados.filter { !catalogo.contains($0) }
    }

    var body: some View {
        Section(titulo) {
            FlowLayout(spacing: 8) {
                ForEach(opciones, id: \.self) { op in
                    let sel = seleccionados.contains(op)
                    Button {
                        if sel { seleccionados.removeAll { $0 == op } }
                        else   { seleccionados.append(op) }
                    } label: {
                        Text(Padron.etiqueta(op))
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
                        guard !txt.isEmpty, !seleccionados.contains(txt) else { return }
                        seleccionados.append(txt)
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
