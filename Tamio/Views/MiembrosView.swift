import SwiftUI

/// Pantalla Aportantes (Tesorería): lista de aportantes (Activos/Bajas/Todos)
/// con el total aportado por cada uno y el total general, + ficha con datos y
/// aportes. Layout adaptativo y seguro (sin el combo que colgaba la app).
struct MiembrosView: View {
    @State private var vm = MiembrosViewModel()
    @State private var abierto: Aportante?
    @State private var hoja: HojaAportante?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private enum HojaAportante: Identifiable {
        case nueva
        case editar(Aportante)
        var id: String { switch self { case .nueva: return "n"; case .editar(let a): return "e\(a.id)" } }
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 640 {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: 360)
                        .background(.regularMaterial)
                    Divider()
                    if let a = vm.seleccion {
                        AportanteDetalle(a: a,
                                         onEditar: { hoja = .editar(a) },
                                         onEliminar: { Task { await vm.eliminar(a) } })
                    } else {
                        ContentUnavailableView(L.t("Selecciona un aportante", "Select a giver"),
                                               systemImage: "person.crop.circle")
                    }
                }
            } else {
                listaColumna
                    .background(.regularMaterial)
                    .navigationDestination(item: $abierto) { a in
                        AportanteDetalle(a: a,
                                         onEditar: { hoja = .editar(a) },
                                         onEliminar: { Task { await vm.eliminar(a) } })
                            .navigationTitle(a.nombre)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Atribuyentes", "Contributors"),
                       L.t("\(vm.activosCount) activos · \(vm.bajasCount) bajas", "\(vm.activosCount) active · \(vm.bajasCount) removed"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { } label: { Label(L.t("Importar CSV", "Import CSV"), systemImage: "square.and.arrow.down") }
                Button { hoja = .nueva } label: {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text(L.t("Nuevo", "New")) }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
        }
        .sheet(item: $hoja) { item in
            switch item {
            case .nueva:
                NuevoAportanteView(existente: nil) { a in Task { await vm.crear(a) } }
            case .editar(let a):
                NuevoAportanteView(existente: a) { a in Task { await vm.actualizar(a) } }
            }
        }
        .task { await vm.cargar() }
    }

    private var listaColumna: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L.t("Buscar por nombre, email o ID fiscal…", "Search by name, email or tax ID…"), text: $vm.busqueda)
                        .textFieldStyle(.plain)
                    if !vm.busqueda.isEmpty {
                        Button { vm.busqueda = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))

                Picker(L.t("Filtro", "Filter"), selection: $vm.filtro) {
                    Text(L.t("Activos", "Active")).tag(FiltroMiembro.activos)
                    Text(L.t("Bajas", "Removed")).tag(FiltroMiembro.bajas)
                    Text(L.t("Todos", "All")).tag(FiltroMiembro.todos)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
            Divider()

            listaMiembros

            Divider()
            HStack {
                Text(L.t("\(vm.itemsFiltrados.count) aportantes", "\(vm.itemsFiltrados.count) givers"))
                Spacer()
                Text("\(Money.fmt(vm.total)) MXN").monospacedDigit().fontWeight(.semibold)
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var listaMiembros: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaMiembrosCuerpo
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var listaMiembrosCuerpo: some View {
        List {
            ForEach(vm.itemsFiltrados) { a in
                fila(a)
                    .contentShape(Rectangle())
                    .onTapGesture { abrir(a) }
            }
        }
    }

    private func fila(_ a: Aportante) -> some View {
        let esSel = a.id == vm.seleccionId
        let rowBG: Color = sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)
        return HStack(spacing: 12) {
            Text(a.iniciales)
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(a.estado.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(a.nombre).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(a.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.fmt(a.aportesTotal)).font(.subheadline.weight(.semibold)).monospacedDigit()
                if a.estado == .traslado {
                    Text(L.t("Traslado", "Transfer"))
                        .font(.caption2.weight(.semibold)).foregroundStyle(Paleta.aviso)
                        .padding(.horizontal, Esp.hueco).padding(.vertical, 2)
                        .background(Paleta.avisoFill, in: Capsule())
                }
            }
        }
        .padding(.vertical, 10)
        .filaDeLista(seleccionada: esSel, tarjeta: sizeClass != .regular)
    }

    private func abrir(_ a: Aportante) {
        vm.seleccionId = a.id
        abierto = a
    }
}
