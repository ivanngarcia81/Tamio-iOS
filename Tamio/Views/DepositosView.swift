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
        .encabezadoNav(L.t("Depósitos", "Deposits"), subtituloBarra)
        // `.large` solo en iPad. En el teléfono la raíz es un `GeometryReader`
        // que no scrollea, así que el título grande no tenía a qué encogerse y
        // dejaba una franja vacía de 60 pt sobre el segmentado. Mismo criterio
        // que Ingresos/Gastos.
        .navigationBarTitleDisplayMode(sizeClass == .compact ? .inline : .large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker(L.t("Ordenar", "Sort"), selection: $vm.orden) {
                        ForEach(OrdenCorte.allCases) { Text($0.etiqueta).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle").foregroundStyle(.secondary)
                }
                Button { mostrarNuevo = true } label: {
                    Label(L.t("Nuevo", "New"), systemImage: "plus")
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)
            }
        }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoCorteView(cuentas: vm.cuentas) { titulo, cuenta, estimado in
                Task { await vm.crearCorte(titulo: titulo, cuenta: cuenta,
                                           efectivoEstimado: estimado) }
            }
        }
        .task { await vm.cargar() }
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
            .colchonInferior()
    }

    /// El material vive en la CABECERA, no detrás de la columna entera: ahí no
    /// tenía nada que difuminar y se resolvía como un gris plano. Mismo cambio
    /// que ya se hizo en Ingresos/Gastos y Aportantes.
    private var cabeceraLista: some View {
        VStack(spacing: 0) {
            Picker(L.t("Estado", "Status"), selection: $vm.estado) {
                Text(L.t("Pendientes", "Pending")).tag(EstadoDeposito.pendiente)
                Text(L.t("Depositados", "Deposited")).tag(EstadoDeposito.depositado)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
        .background(.regularMaterial)
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
