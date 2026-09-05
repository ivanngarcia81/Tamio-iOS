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

    /// **La rama del teléfono.** Mismo criterio que en Ingresos/Gastos: no es
    /// "¿caben lista y detalle?" —eso lo decide el ancho— sino "¿los controles
    /// suben a la barra?", que solo tiene sentido en el teléfono. En iPad la
    /// barra es de la pantalla entera y el buscador acabaría lejos de la lista
    /// que filtra.
    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        pantalla
            .toolbar { barra }
            .sheet(item: $hoja) { item in
                switch item {
                case .nueva:
                    NuevoAportanteView(existente: nil) { a in Task { await vm.crear(a) } }
                case .editar(let a):
                    NuevoAportanteView(existente: a) { a in Task { await vm.actualizar(a) } }
                }
            }
            .sheet(item: $csvParaCompartir) { url in CompartirArchivo(url: url) }
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

    /// Teléfono: buscador nativo y el título borrado, porque el segmentado que
    /// ocupa su sitio dice lo mismo —Activos/Bajas/Todos son estados de los
    /// aportantes, no secciones distintas de la pantalla.
    /// iPad: título como las demás y los controles abajo, junto a la lista.
    @ViewBuilder
    private var pantalla: some View {
        if compacto {
            columnas
                // La lupa se queda arriba por el límite del sistema que
                // documenta `MovimientosView.pantalla`: con `.searchable` no
                // hay forma de tenerla solo en la barra inferior. Lo que baja
                // es el `+`.
                .searchable(text: $vm.busqueda,
                            prompt: Text(L.t("Buscar por nombre, email o ID fiscal",
                                             "Search by name, email or tax ID")))
                .searchToolbarBehavior(.minimize)
                .navigationTitle(L.t("Aportantes", "Contributors"))
                .navigationBarTitleDisplayMode(.inline)
        } else {
            columnas
                .encabezadoNav(L.t("Aportantes", "Contributors"),
                               L.t("\(vm.activosCount) activos · \(vm.bajasCount) bajas",
                                   "\(vm.activosCount) active · \(vm.bajasCount) removed"))
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
                    if let a = vm.seleccion {
                        AportanteDetalle(a: a, onEditar: { hoja = .editar(a) })
                    } else {
                        ContentUnavailableView(L.t("Selecciona un aportante", "Select a giver"),
                                               systemImage: "person.crop.circle")
                    }
                }
            } else {
                listaColumna
                    .navigationDestination(item: $abierto) { a in
                        AportanteDetalle(a: a, onEditar: { hoja = .editar(a) })
                            .navigationTitle(a.nombre)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
    }

    // MARK: - Barra

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        // El segmentado ocupa el lugar del título: Activos/Bajas/Todos son
        // ESTADOS de los aportantes, no secciones distintas, así que nombran la
        // pantalla igual que el título y gana el control, que además se toca.
        if compacto {
            ToolbarItem(placement: .title) {
                menuFiltro
            }
        }
        // Compartir y "Nuevo" compartían un `ToolbarItemGroup`, así que
        // compartían UNA cápsula y Compartir no tenía la suya. Separados en
        // dos items, cada uno recupera la suya.
        // **El `+` vuelve arriba y Archivo se va a la izquierda.** Con los dos
        // a la derecha, medido en pantalla, no caben: el segmentado se recorta
        // a "Remo…" y el `+` se cae de la barra sin avisar. Crear es la acción
        // frecuente y se queda donde la busca el pulgar; Archivo —importar y
        // exportar CSV— se usa una vez cada mucho.
        ToolbarItem(placement: compacto ? .topBarLeading : .topBarTrailing) { menuArchivo }
        if !compacto { ToolbarSpacer(.fixed, placement: .topBarTrailing) }
        ToolbarItem(placement: .topBarTrailing) { botonNuevo }
    }

    private var botonNuevo: some View {
        Button { hoja = .nueva } label: {
            Label(L.t("Nuevo", "New"), systemImage: "plus")
        }
        .buttonStyle(.glass)
        .tint(Paleta.brand)
    }

    /// **En el teléfono, menú; en iPad, segmentado.** Medido en pantalla: con
    /// el botón de volver, Archivo, el `+` y la lupa, un segmentado de tres
    /// opciones se parte en "Act… Re… All", que no dice ninguna de las tres.
    /// Es la misma salida que en Reportes y en la ficha del aportante cuando el
    /// ancho no da: la etiqueta dice dónde estás y el menú las enseña enteras.
    private var menuFiltro: some View {
        Menu {
            // **El año y el total encabezan el menú.** Eran el pie, y el pie se
            // fue del teléfono. Aquí no estorban y siguen juntos: el total es
            // del año que está escrito a su lado, y leerlos separados sería
            // peor que no leerlos.
            Section(L.t("\(String(vm.anio)) · \(Money.fmt(vm.total)) \(Money.codigo)",
                        "\(String(vm.anio)) · \(Money.fmt(vm.total)) \(Money.codigo)")) {
                ForEach(Self.filtros, id: \.0) { valor, nombre in
                    Button { vm.filtro = valor } label: {
                        if vm.filtro == valor { Label(nombre, systemImage: "checkmark") }
                        else { Text(nombre) }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                // **El conteo va en la etiqueta, como las bandejas de Mail.**
                // Al borrarse el título de la pantalla se fue también su
                // subtítulo, y el pie era el único sitio que decía cuántos
                // aportantes se están viendo: ese número es lo que revela que
                // la lista está filtrada. Aquí lo dice quien filtra.
                Text("\(Self.nombreFiltro(vm.filtro)) (\(vm.itemsFiltrados.count))")
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
    private static var filtros: [(FiltroMiembro, String)] {
        [(.activos, L.t("Activos", "Active")),
         (.bajas, L.t("Bajas", "Removed")),
         (.todos, L.t("Todos", "All"))]
    }

    private static func nombreFiltro(_ f: FiltroMiembro) -> String {
        filtros.first { $0.0 == f }?.1 ?? ""
    }

    private var pickerFiltro: some View {
        Picker(L.t("Filtro", "Filter"), selection: $vm.filtro) {
            ForEach(Self.filtros, id: \.0) { valor, nombre in
                Text(nombre).tag(valor)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
        .buttonStyle(.glass)
        .labelStyle(.iconOnly)
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

    /// **Capas, no hermanos.** Mismo arreglo que en Ingresos/Gastos: la
    /// cabecera y el pie eran hermanos de la lista dentro de un `VStack`, así
    /// que una fila que subía se recortaba contra el borde y desaparecía de
    /// golpe en la línea del `Divider`, y el pie cortaba la última a media
    /// altura —el nombre partido y el subtítulo tapado. Con `safeAreaInset` el
    /// contenido corre por debajo de las dos barras, que es lo único que
    /// necesita material para difuminar algo.
    private var listaColumna: some View {
        listaMiembros
            .safeAreaInset(edge: .top, spacing: 0) { cabeceraLista }
            // **El pie, solo en iPad.** En el teléfono apilaba una segunda
            // barra sobre la de pestañas y cortaba la última fila; lo que
            // decía se reparte ahora entre el menú de filtro —que lleva el
            // conteo en la etiqueta y el año y el total en su cabecera— y la
            // lista misma. En iPad no hay barra de pestañas contra la que
            // apilarse, y este pie es el único sitio de la columna donde se
            // leen el año y el total: allí se queda.
            .safeAreaInset(edge: .bottom, spacing: 0) { pieLista }
            .colchonInferior()
    }

    /// En el teléfono aquí solo queda el aviso: el buscador y el segmentado se
    /// fueron a la barra. En iPad se quedan los tres, que es donde filtran algo
    /// que tienen al lado.
    @ViewBuilder
    private var cabeceraLista: some View {
        if !compacto || vm.atrasadosCount > 0 {
            VStack(spacing: 10) {
                if !compacto {
                    buscadorColumna
                    pickerFiltro
                }
                avisoAtrasados
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.vertical, compacto ? Esp.hueco : Esp.chip)
            .background(.regularMaterial)
        }
    }

    /// El buscador de la columna del iPad. No usa `.searchable` a propósito:
    /// ese lo coloca el sistema en la barra de la pantalla, que en iPad está
    /// encima de las dos columnas. Filtra esta lista, así que vive pegado a
    /// ella. Lo que sí se va es el `RoundedRectangle` con `tertiarySystemFill`.
    private var buscadorColumna: some View {
        HStack(spacing: Esp.hueco) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L.t("Buscar por nombre, email o ID fiscal…", "Search by name, email or tax ID…"),
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

    /// El equivalente en Tesorería de "SIN ASISTIR ÚLTIMAMENTE" de Membresía:
    /// mismo gesto, un lado para la secretaria y otro para el tesorero. Solo
    /// aparece si hay a quien mirar.
    ///
    /// **No sube a la barra ni al overflow**, a propósito: es un aviso sobre la
    /// lista que hay debajo y ahí es donde tiene sentido leerlo. Que además
    /// filtre al tocarlo no lo convierte en un control de barra: escondido
    /// dejaría de avisar, que es su primer trabajo. Se queda flotando sobre la
    /// lista, en la única franja que le queda al teléfono.
    @ViewBuilder
    private var avisoAtrasados: some View {
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

    /// El pie, en las dos plataformas: anclado y del ancho de la columna. En el
    /// teléfono era una barra flotante con el `+` y el resumen, y flotar aquí
    /// significa tapar la última fila.
    @ViewBuilder
    private var pieLista: some View {
        if !compacto {
            HStack {
                Text(L.t("\(vm.itemsFiltrados.count) aportantes · \(String(vm.anio))",
                         "\(vm.itemsFiltrados.count) givers · \(String(vm.anio))"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Money.fmt(vm.total)) \(Money.codigo)").monospacedDigit().fontWeight(.semibold)
            }
            .font(.caption)
            .padding(.horizontal, Esp.pantalla).padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private var listaMiembros: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaMiembrosCuerpo
            .listStyle(.plain)
            // El suelo va en la LISTA, no en la columna: el material se fue a
            // la cabecera y al pie, que es lo único que difumina algo.
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            // El desvanecido de borde: la fila deja de aparecer y desaparecer
            // de golpe al cruzar por detrás del aviso o del pie.
            .scrollEdgeEffectStyle(.soft, for: .all)
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
        // La selección persistente es idioma de iPad, donde lista y detalle
        // conviven. En iPhone la fila navega y volver la dejaba marcada como si
        // siguiera abierta. Mismo arreglo que en Ingresos/Gastos.
        .filaDeLista(seleccionada: esSel && !compacto, tarjeta: compacto)
    }

    private func abrir(_ a: Aportante) {
        vm.seleccionId = a.id
        abierto = a
    }
}
