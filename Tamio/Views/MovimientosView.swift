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
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
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

    private var mesActual: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "LLLL"
        return f.string(from: Date()).capitalized
    }

    private var tituloBarra: String {
        vm.tipo == .ingreso ? L.t("Ingresos", "Income") : L.t("Gastos", "Expenses")
    }

    private var subtituloBarra: String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "LLLL"
        let mes = f.string(from: Date()).capitalized
        let n = vm.itemsFiltrados.count
        return L.t("\(mes) · \(n) movimientos · \(Money.fmt(vm.total))",
                   "\(mes) · \(n) entries · \(Money.fmt(vm.total))")
    }

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
        if sizeClass == .regular {
            listaCuerpo.listStyle(.plain)
        } else {
            listaCuerpo.listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var listaCuerpo: some View {
        let rowBG: Color = sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)
        List {
            ForEach(vm.grupos, id: \.encabezado) { grupo in
                Section {
                    ForEach(grupo.items) { m in
                        filaContenido(m)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(rowBG)
                            .contentShape(Rectangle())
                            .onTapGesture { abrir(m) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await vm.eliminar(m) }
                                } label: {
                                    Label(L.t("Eliminar", "Delete"), systemImage: "trash")
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
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 8) {
                chip(mesActual, seleccionado: true, desplegable: true) {}
                Spacer()
                botonFiltros
            }
        }
        .padding(12)
    }

    // MARK: - Filtros

    private var filtrosActivos: Int {
        (vm.filtroCategoria != nil ? 1 : 0) + (vm.soloSinDepositar ? 1 : 0)
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
            .padding(.horizontal, 13).padding(.vertical, 7)
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
                        }
                    }
                }
                Section(L.t("ESTADO", "STATUS")) {
                    Toggle(L.t("Sin depositar", "Not deposited"), isOn: $vm.soloSinDepositar)
                        .tint(Paleta.brand)
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

    private func chip(_ texto: String, seleccionado: Bool, desplegable: Bool = false,
                      accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 4) {
                Text(texto)
                if desplegable { Image(systemName: "chevron.down").font(.caption.weight(.semibold)) }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(seleccionado ? Paleta.brand : .primary)
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(Capsule().fill(seleccionado ? Paleta.brandFill : Color(.secondarySystemFill)))
            .overlay(Capsule().stroke(seleccionado ? Paleta.brandStroke : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func filaContenido(_ m: Movimiento) -> some View {
        let esSel = m.id == vm.seleccionId
        return HStack(spacing: 10) {
            Circle().fill(Paleta.categoria(m.categoria)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.titular).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(m.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.fmt(m.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
                if m.sinDepositar {
                    Text(L.t("Sin depositar", "Not deposited"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Paleta.aviso)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Paleta.avisoFill, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(esSel ? Paleta.brandFill : Color.clear)
        .overlay(alignment: .leading) {
            if esSel { Rectangle().fill(Paleta.brand).frame(width: 3) }
        }
    }

    private var pieLista: some View {
        HStack {
            Text(L.t("\(vm.itemsFiltrados.count) movimientos", "\(vm.itemsFiltrados.count) entries"))
            Spacer()
            Text(Money.fmt(vm.total)).monospacedDigit().fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
