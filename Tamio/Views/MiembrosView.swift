import SwiftUI

/// Pantalla Aportantes (Tesorería): lista de aportantes (Activos/Bajas/Todos)
/// con el total aportado por cada uno y el total general, + ficha con datos y
/// aportes. Layout adaptativo y seguro (sin el combo que colgaba la app).
struct MiembrosView: View {
    @State private var vm = MiembrosViewModel()
    @State private var abierto: Aportante?
    @State private var hoja: HojaAportante?
    /// Archivo recién generado, a la espera de que se elija dónde mandarlo.
    @State private var csvParaCompartir: URL?
    @State private var mostrarImportador = false
    @State private var analisis: ImportadorAportantes.Analisis?
    @State private var mostrarImportadorAportes = false
    @State private var analisisAportes: ImportadorAportes.Analisis?
    @State private var errorImportacion: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private enum HojaAportante: Identifiable {
        case nueva
        case editar(Aportante)
        var id: String { switch self { case .nueva: return "n"; case .editar(let a): return "e\(a.id)" } }
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: Esp.columnaMaestra)
                        .background(.regularMaterial)
                    Divider()
                    if let a = vm.seleccion {
                        AportanteDetalle(a: a, onEditar: { hoja = .editar(a) })
                    } else {
                        ContentUnavailableView(L.t("Selecciona un aportante", "Select a giver"),
                                               systemImage: "person.crop.circle")
                    }
                }
            } else {
                listaColumna
                    .background(.regularMaterial)
                    .navigationDestination(item: $abierto) { a in
                        AportanteDetalle(a: a, onEditar: { hoja = .editar(a) })
                            .navigationTitle(a.nombre)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Aportantes", "Contributors"),
                       L.t("\(vm.activosCount) activos · \(vm.bajasCount) bajas", "\(vm.activosCount) active · \(vm.bajasCount) removed"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                menuArchivo
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
        .sheet(item: $csvParaCompartir) { url in
            CompartirArchivo(url: url)
        }
        .fileImporter(isPresented: $mostrarImportador,
                      allowedContentTypes: [.commaSeparatedText, .text, .data],
                      allowsMultipleSelection: false) { analizar($0) }
        .sheet(item: $analisis) { a in
            ImportarAportantesView(analisis: a) { lista in
                Task { await vm.importar(lista) }
            }
        }
        .fileImporter(isPresented: $mostrarImportadorAportes,
                      allowedContentTypes: [.commaSeparatedText, .text, .data],
                      allowsMultipleSelection: false) { analizarAportes($0) }
        .sheet(item: $analisisAportes) { a in
            ImportarAportesView(analisis: a) { porAportante in
                Task { await vm.importarAportes(porAportante) }
            }
        }
        .alert(L.t("No se pudo importar", "Couldn't import"),
               isPresented: Binding(get: { errorImportacion != nil },
                                    set: { if !$0 { errorImportacion = nil } })) {
            Button(L.t("Entendido", "OK"), role: .cancel) { errorImportacion = nil }
        } message: {
            Text(errorImportacion ?? "")
        }
        .task { await vm.cargar() }
    }

    /// Exporta lo que se está viendo, con los filtros y la búsqueda ya
    /// aplicados: es lo que se espera de un botón de exportar, y para sacarlo
    /// todo basta con quitar el filtro.
    private var menuArchivo: some View {
        Menu {
            Button {
                mostrarImportador = true
            } label: {
                Label(L.t("Importar aportantes…", "Import givers…"),
                      systemImage: "square.and.arrow.down")
            }
            Button {
                mostrarImportadorAportes = true
            } label: {
                Label(L.t("Importar aportes…", "Import gifts…"),
                      systemImage: "square.and.arrow.down.on.square")
            }
            Button {
                csvParaCompartir = ExportadorAportantes.plantilla()
            } label: {
                Label(L.t("Descargar plantilla", "Download template"),
                      systemImage: "doc.badge.plus")
            }
            Divider()
            Button {
                csvParaCompartir = ExportadorAportantes.aportantes(vm.itemsFiltrados)
            } label: {
                Label(L.t("Aportantes (CSV)", "Givers (CSV)"), systemImage: "person.2")
            }
            Button {
                csvParaCompartir = ExportadorAportantes.aportes(vm.itemsFiltrados)
            } label: {
                Label(L.t("Aportes (CSV)", "Gifts (CSV)"), systemImage: "list.bullet.rectangle")
            }
        } label: {
            Label(L.t("Archivo", "File"), systemImage: "square.and.arrow.up")
        }
    }

    /// Analiza el archivo y enseña el resumen. Nada se escribe hasta que se
    /// confirma en la pantalla siguiente.
    private func analizar(_ resultado: Result<[URL], Error>) {
        conArchivo(resultado) { url in
            analisis = try ImportadorAportantes.analizar(url, existentes: vm.items)
        }
    }

    private func analizarAportes(_ resultado: Result<[URL], Error>) {
        conArchivo(resultado) { url in
            analisisAportes = try ImportadorAportes.analizar(url, existentes: vm.items)
        }
    }

    private func conArchivo(_ resultado: Result<[URL], Error>,
                            _ accion: (URL) throws -> Void) {
        switch resultado {
        case .success(let urls):
            guard let url = urls.first else { return }
            do { try accion(url) }
            catch { errorImportacion = error.localizedDescription }
        case .failure(let error):
            errorImportacion = error.localizedDescription
        }
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

                // El equivalente en Tesorería de "SIN ASISTIR ÚLTIMAMENTE" de
                // Membresía: mismo gesto, un lado para la secretaria y otro
                // para el tesorero. Solo aparece si hay a quien mirar.
                if vm.atrasadosCount > 0 {
                    Button { vm.soloAtrasados.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(L.t("\(vm.atrasadosCount) sin aportar últimamente",
                                     "\(vm.atrasadosCount) lapsed givers"))
                            Spacer()
                            if vm.soloAtrasados {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(vm.soloAtrasados ? .white : Paleta.aviso)
                        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(vm.soloAtrasados ? Paleta.aviso : Paleta.avisoFill,
                                    in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
            Divider()

            listaMiembros

            Divider()
            HStack {
                Text(L.t("\(vm.itemsFiltrados.count) aportantes · \(String(vm.anio))",
                         "\(vm.itemsFiltrados.count) givers · \(String(vm.anio))"))
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
        return HStack(spacing: 12) {
            Avatar(iniciales: a.iniciales, color: a.estado.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.nombre).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(a.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.fmt(a.total(anio: vm.anio))).font(.subheadline.weight(.semibold)).monospacedDigit()
                if a.estado == .traslado {
                    Text(L.t("Traslado", "Transfer"))
                        .font(.caption2.weight(.semibold)).foregroundStyle(Paleta.aviso)
                        .padding(.horizontal, Esp.hueco).padding(.vertical, 2)
                        .background(Paleta.avisoFill, in: Capsule())
                } else if let atraso = a.periodosSinAportar, a.atrasadoEnAportes {
                    Text(a.frecuencia.periodos(atraso))
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
