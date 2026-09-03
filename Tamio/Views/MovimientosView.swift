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

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 640 {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: 320)
                        .background(.regularMaterial)
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
                    .background(.regularMaterial)
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
        .encabezadoNav(tituloBarra, subtituloBarra)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { hoja = .nueva(folio: await vm.nuevoFolio()) }
                } label: {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text(L.t("Nuevo", "New")) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
        }
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
        .task { await vm.cargar() }
        .overlay(alignment: .top) { avisoError }
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

    private var tituloBarra: String {
        vm.tipo == .ingreso ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses")
    }

    /// Solo el mes: el conteo y el total viven en el pie de la lista, que es
    /// donde se consultan tras filtrar. Antes el header los repetía literal.
    /// Y decía SIEMPRE el mes en curso, mirara uno el mes que mirara.
    private var subtituloBarra: String { etiquetaMes }

    // MARK: - Columna maestra

    private var listaColumna: some View {
        VStack(spacing: 0) {
            cabeceraLista
            Divider()
            lista
            Divider()
            pieLista
        }
        .colchonInferior()
    }

    @ViewBuilder
    private var lista: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaCuerpo
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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

    private var cabeceraLista: some View {
        VStack(spacing: 10) {
            Picker(L.t("Tipo", "Type"), selection: $vm.tipo) {
                Text(L.t("Ingresos", "Income")).tag(TipoMovimiento.ingreso)
                Text(L.t("Gastos", "Expenses")).tag(TipoMovimiento.gasto)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L.t("Buscar folio, miembro o nota", "Search folio, member or note"),
                          text: $vm.busqueda)
                    .textFieldStyle(.plain)
                if !vm.busqueda.isEmpty {
                    Button { vm.busqueda = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 8) {
                selectorMes
                Spacer()
                botonFiltros
            }
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
    }

    // MARK: - Filtros

    /// El mes no cuenta como filtro: tiene chip propio y siempre hay uno
    /// puesto, así que el globito marcaría "1" permanentemente.
    private var filtrosActivos: Int {
        (vm.filtroCategoria != nil ? 1 : 0)
        + ((vm.tipo == .ingreso ? vm.soloSinDepositar : vm.soloPendientes) ? 1 : 0)
    }

    private var botonFiltros: some View {
        Button { mostrarFiltros = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(L.t("Filtros", "Filters"))
                if filtrosActivos > 0 {
                    Text("\(filtrosActivos)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Paleta.brand, in: Circle())
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(filtrosActivos > 0 ? Paleta.brand : .primary)
            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
            .background(Capsule().fill(filtrosActivos > 0 ? Paleta.brandFill : Color(.secondarySystemFill)))
            .overlay(Capsule().stroke(filtrosActivos > 0 ? Paleta.brandStroke : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
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

    /// El chip del mes. Antes llevaba chevron de desplegable y una acción
    /// VACÍA: parecía un selector, no lo era, y la lista traía todos los meses
    /// aunque el chip nombrara uno. Ofrece solo los meses con movimientos —un
    /// calendario libre dejaría caer en meses vacíos— más "Todos los meses".
    private var selectorMes: some View {
        Menu {
            ForEach(vm.mesesDisponibles, id: \.self) { m in
                opcionMes(Fechas.mes(m), marcada: vm.mes == m) { vm.mes = m }
            }
            Divider()
            opcionMes(Self.todosLosMeses, marcada: vm.mes == nil) { vm.mes = nil }
        } label: {
            chipEtiqueta(etiquetaMes, seleccionado: vm.mes != nil, desplegable: true)
        }
        .buttonStyle(.plain)
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

    private func chipEtiqueta(_ texto: String, seleccionado: Bool,
                              desplegable: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(texto)
            if desplegable { Image(systemName: "chevron.down").font(.caption.weight(.semibold)) }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(seleccionado ? Paleta.brand : .primary)
        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
        .background(Capsule().fill(seleccionado ? Paleta.brandFill : Color(.secondarySystemFill)))
        .overlay(Capsule().stroke(seleccionado ? Paleta.brandStroke : Color.clear, lineWidth: 1))
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
                if m.sinDepositar {
                    Text(L.t("Sin depositar", "Not deposited"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Paleta.aviso)
                        .padding(.horizontal, Esp.hueco).padding(.vertical, 2)
                        .background(Paleta.avisoFill, in: Capsule())
                }
            }
        }
        .padding(.vertical, 6)
        .filaDeLista(seleccionada: esSel, tarjeta: sizeClass != .regular)
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
    }
}
