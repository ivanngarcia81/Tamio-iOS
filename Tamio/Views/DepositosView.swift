import SwiftUI

/// Pantalla Depósitos: lista de cortes (Pendientes/Depositados) + detalle del
/// corte. Reusa el mismo layout adaptativo que Movimientos (lado a lado en
/// amplio; empuja el detalle en compacto/portrait).
struct DepositosView: View {
    @State private var vm = DepositosViewModel()
    @State private var abierto: Corte?
    @State private var mostrarNuevo = false
    @Environment(Navegacion.self) private var nav: Navegacion?
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// **La rama del teléfono.** No es la misma pregunta que "¿caben la lista y
    /// el detalle a la vez?", que la decide el ancho contra
    /// `Esp.anchoMaestroDetalle`. Aquí se decide si los controles suben a la
    /// barra de navegación, y eso solo tiene sentido en el teléfono: en iPad la
    /// barra es de la pantalla entera, así que el segmentado acabaría lejos de
    /// la lista que filtra y compartiendo sitio con las acciones del detalle.
    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna(wide: true)
                        .frame(width: Esp.columnaMaestra)
                    Divider()
                    if let c = vm.seleccion {
                        detalle(c)
                    } else {
                        ContentUnavailableView(
                            L.t("Selecciona un corte", "Select a cut"),
                            systemImage: "banknote"
                        )
                    }
                }
            } else {
                listaColumna(wide: false)
                    .navigationDestination(item: $abierto) { c in
                        // Siempre el corte fresco del VM, para reflejar las
                        // acciones (selección, cuenta, ficha) al instante.
                        detalle(vm.corte(c.id) ?? c)
                            // El H1 del detalle ya dice el título del corte.
                            .navigationTitle("")
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .modifier(EncabezadoDepositos(compacto: compacto, subtitulo: subtituloBarra))
        .toolbar { barra }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoCorteView(cuentas: vm.cuentas) { titulo, cuenta, estimado in
                Task { await vm.crearCorte(titulo: titulo, cuenta: cuenta,
                                           efectivoEstimado: estimado) }
            }
        }
        .task { await vm.cargar() }
    }

    // MARK: - Barra

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        // El segmentado ocupa el lugar del título: Pendientes/Depositados son
        // ESTADOS de un corte, no secciones distintas, así que nombran la
        // pantalla igual que el título y gana el control, que además se toca.
        // Mismo criterio que Ingresos/Gastos y Aportantes.
        if compacto {
            ToolbarItem(placement: .title) {
                pickerEstado.frame(maxWidth: 200)
            }
        }
        // Item PROPIO, no un `ToolbarItemGroup` compartido con "Nuevo": dentro
        // de un grupo los dos comparten UNA cápsula, y el de ordenar se quedaba
        // sin fondo propio, pegado al `+`. Es el mismo arreglo que ya se hizo
        // en Aportantes con Archivo y "Nuevo".
        ToolbarItem(placement: .topBarTrailing) { menuOrdenar }
        // En iPad el `+` se queda arriba, apartado con su espaciador; en el
        // teléfono baja a la barra inferior, como en las otras dos pantallas.
        if !compacto {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) { botonNuevo }
        }
    }

    /// Lleva su nombre escrito. Era un `arrow.up.arrow.down.circle` mudo: un
    /// icono solo en la barra no dice que ordena la lista, y el orden vigente
    /// no se leía en ningún sitio hasta abrir el menú.
    private var menuOrdenar: some View {
        Menu {
            Picker(L.t("Ordenar", "Sort"), selection: $vm.orden) {
                ForEach(OrdenCorte.allCases) { Text($0.etiqueta).tag($0) }
            }
        } label: {
            // Texto explícito, no `Label`: dentro de la barra el sistema
            // colapsa un `Label` a solo icono —y `.labelStyle(.titleAndIcon)`
            // tampoco lo impide, medido en pantalla—, que es exactamente el
            // icono mudo que había antes. Mismo patrón que `selectorMes` de
            // Ingresos/Gastos: palabra + chevron.
            HStack(spacing: 4) {
                Text(L.t("Ordenar", "Sort")).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.glass)
    }

    private var botonNuevo: some View {
        Button { mostrarNuevo = true } label: {
            Label(L.t("Nuevo", "New"), systemImage: "plus")
        }
        .buttonStyle(.glass)
        .tint(Paleta.brand)
    }

    private var pickerEstado: some View {
        Picker(L.t("Estado", "Status"), selection: $vm.estado) {
            Text(L.t("Pendientes", "Pending")).tag(EstadoDeposito.pendiente)
            Text(L.t("Depositados", "Deposited")).tag(EstadoDeposito.depositado)
        }
        .pickerStyle(.segmented)
    }

    /// **La barra inferior del teléfono**, del mismo componente que Ingresos y
    /// Aportantes. A la izquierda el `+`; a la derecha lo que quedó huérfano al
    /// borrar el título: cuántos cortes esperan y CUÁNTO DINERO hay sin
    /// depositar, que es el dato por el que se abre esta pantalla.
    ///
    /// Sin lupa: Depósitos no tiene buscador ni lo tenía. Una lista de cortes
    /// pendientes es corta por definición —si crece, el problema es que nadie
    /// va al banco, no que falte un buscador—.
    @ViewBuilder
    private var barraInferior: some View {
        if compacto {
            BarraInferior { botonNuevo } resumen: { resumenPie }
        }
    }

    private var resumenPie: some View {
        HStack(spacing: 6) {
            Text("\(vm.pendientesCount)").foregroundStyle(.secondary)
            Text("·").foregroundStyle(.tertiary)
            Text(Money.fmt(vm.pendientesMonto))
                .fontWeight(.semibold)
                .foregroundStyle(Paleta.aviso)
        }
        .font(.footnote)
        .monospacedDigit()
    }

    /// Un `CorteDetalle` con todas sus acciones cableadas al ViewModel.
    private func detalle(_ c: Corte) -> some View {
        CorteDetalle(
            corte: c,
            cuentas: vm.cuentas,
            onNuevoCorte: { mostrarNuevo = true },
            onToggleMovimiento: { movId in Task { await vm.toggleMovimiento(corteId: c.id, movId: movId) } },
            onMarcarTodos: { valor in Task { await vm.marcarTodos(corteId: c.id, valor) } },
            onAgregarMovimiento: { mov in Task { await vm.agregarMovimiento(corteId: c.id, mov) } },
            onQuitarMovimiento: { movId in Task { await vm.quitarMovimiento(corteId: c.id, movId: movId) } },
            onAsignarCuenta: { cta in Task { await vm.asignarCuenta(corteId: c.id, cuenta: cta) } },
            onAgregarCuenta: { nombre in Task { await vm.agregarCuenta(nombre, aCorte: c.id) } },
            onCambiarPeriodo: { p in Task { await vm.cambiarPeriodo(corteId: c.id, p) } },
            onCambiarFecha: { f in Task { await vm.cambiarFecha(corteId: c.id, f) } },
            onAdjuntarFicha: { nombre in Task { await vm.adjuntarFicha(corteId: c.id, nombre: nombre) } },
            onMarcarDepositado: { Task { await vm.marcarDepositado(corteId: c.id) } },
            onIrAPorRevisar: irAPorRevisar
        )
    }

    /// Mueve la sidebar en iPad y la pestaña en iPhone. Poner solo `seccion`
    /// no hacía nada en el teléfono, donde Depósitos vive dentro de la pila de
    /// Tesorería y "Por revisar" es otra pestaña.
    private func irAPorRevisar() {
        nav?.seccion = "porRevisar"
        nav?.pestana = .revisar
    }

    /// La cuenta solo se nombra si TODOS los cortes pendientes van a la misma.
    /// Era "· Banorte ··4821" escrito a mano, y seguía ahí con los pendientes
    /// repartidos entre dos bancos o sin cuenta asignada.
    private var subtituloBarra: String {
        let n = vm.pendientesCount
        let cortes = L.t("\(n) corte\(n == 1 ? "" : "s") pendiente\(n == 1 ? "" : "s")",
                         "\(n) pending cut\(n == 1 ? "" : "s")")
        guard let cuenta = vm.cuentaResumen else { return cortes }
        return "\(cortes) · \(cuenta)"
    }

    private func listaColumna(wide: Bool) -> some View {
        lista(wide: wide)
            .safeAreaInset(edge: .top, spacing: 0) { cabeceraLista }
            .safeAreaInset(edge: .bottom, spacing: 0) { barraInferior }
            .colchonInferior()
    }

    /// **Solo en iPad.** En el teléfono el segmentado se fue al lugar del
    /// título, y una cabecera con el material y nada dentro seguía comiéndose
    /// su franja de alto y empujando la primera fila hacia abajo: por eso la
    /// rama compacta no devuelve una cabecera vacía, sino ninguna.
    ///
    /// En iPad se queda, y ahí el material tiene sentido: es lo que la lista
    /// atraviesa al desplazarse. Vive en la CABECERA y no detrás de la columna
    /// entera, donde no tenía nada que difuminar y se resolvía como gris plano.
    @ViewBuilder
    private var cabeceraLista: some View {
        if !compacto {
            pickerEstado
                .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
                .background(.regularMaterial)
        }
    }

    private func lista(wide: Bool) -> some View {
        List {
            Section {
                ForEach(vm.items) { c in
                    fila(c, wide: wide)
                }
            }
            if vm.estado == .pendiente {
                Section {
                    Text(L.t("Un corte queda pendiente hasta que registres la ficha del banco.",
                             "A cut stays pending until you record the bank slip."))
                        .font(.caption).foregroundStyle(.secondary)
                        .listRowBackground(Color(.clear))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        // Desvanecido de borde: la fila deja de aparecer y desaparecer de golpe
        // al cruzar por detrás de la cabecera.
        .scrollEdgeEffectStyle(.soft, for: .all)
        .overlay {
            if vm.items.isEmpty {
                ContentUnavailableView(
                    vm.estado == .pendiente
                        ? L.t("Sin cortes pendientes", "No pending cuts")
                        : L.t("Sin depósitos registrados", "No deposits recorded"),
                    systemImage: "banknote",
                    description: Text(vm.estado == .pendiente
                        ? L.t("Crea un corte con «Nuevo» para juntar el dinero en caja de un culto.",
                              "Create a cut with “New” to gather a service's cash.")
                        : L.t("Los cortes aparecen aquí al marcarlos como depositados.",
                              "Cuts show up here once you mark them deposited."))
                )
            }
        }
    }

    private func fila(_ c: Corte, wide: Bool) -> some View {
        // Misma convención que Ingresos/Gastos y Aportantes: tarjeta solo en
        // compacto, y barra de selección solo donde la selección se ve (en
        // compacto se navega fuera, así que no hay nada seleccionado a la vista).
        let esSel = c.id == vm.seleccionId && wide
        return Button {
            vm.seleccionId = c.id
            abierto = c
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.titulo).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(c.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Money.fmt(c.montoTotal)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    if c.sinDepositar {
                        Text(L.t("Sin depositar", "Not deposited"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Paleta.aviso)
                            .padding(.horizontal, Esp.hueco).padding(.vertical, 2)
                            .background(Paleta.avisoFill, in: Capsule())
                    }
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .filaDeLista(seleccionada: esSel, tarjeta: !wide)
    }
}

/// El título de Depósitos existe SOLO en iPad.
///
/// En el teléfono el segmentado Pendientes/Depositados ocupa su sitio y dice lo
/// mismo, así que "Depósitos" sería el rótulo repetido encima del control que ya
/// nombra la pantalla. Lo que NO se pierde es el subtítulo: el conteo de cortes
/// pendientes baja a la barra inferior, con el monto al lado.
///
/// En iPad el título grande se queda como está: allí la barra es de la pantalla
/// entera y el segmentado vive en la columna, así que nada más nombra la vista.
private struct EncabezadoDepositos: ViewModifier {
    let compacto: Bool
    let subtitulo: String

    func body(content: Content) -> some View {
        if compacto {
            content.navigationBarTitleDisplayMode(.inline)
        } else {
            content
                .encabezadoNav(L.t("Depósitos", "Deposits"), subtitulo)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
