import SwiftUI

/// Pantalla Depósitos: lista de cortes (Pendientes/Depositados) + detalle del
/// corte. Reusa el mismo layout adaptativo que Movimientos (lado a lado en
/// amplio; empuja el detalle en compacto/portrait).
struct DepositosView: View {
    @State private var vm = DepositosViewModel()
    @State private var abierto: Corte?
    @State private var mostrarNuevo = false

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna(wide: true)
                        .frame(width: Esp.columnaMaestra)
                        .background(.regularMaterial)
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
                    .background(.regularMaterial)
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
        .navigationBarTitleDisplayMode(.large)
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
                    HStack(spacing: 5) { Image(systemName: "plus"); Text(L.t("Nuevo", "New")) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
        }
        .sheet(isPresented: $mostrarNuevo) {
            NuevoCorteView(cuentas: vm.cuentas) { titulo, cuenta, monto in
                Task { await vm.crearCorte(titulo: titulo, cuenta: cuenta, monto: monto) }
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
            onAsignarCuenta: { cta in Task { await vm.asignarCuenta(corteId: c.id, cuenta: cta) } },
            onAdjuntarFicha: { nombre in Task { await vm.adjuntarFicha(corteId: c.id, nombre: nombre) } },
            onMarcarDepositado: { Task { await vm.marcarDepositado(corteId: c.id) } }
        )
    }

    private var subtituloBarra: String {
        let n = vm.pendientesCount
        return L.t("\(n) corte\(n == 1 ? "" : "s") pendiente\(n == 1 ? "" : "s") · Banorte ··4821",
                   "\(n) pending cut\(n == 1 ? "" : "s") · Banorte ··4821")
    }

    private func listaColumna(wide: Bool) -> some View {
        VStack(spacing: 0) {
            Picker(L.t("Estado", "Status"), selection: $vm.estado) {
                Text(L.t("Pendientes", "Pending")).tag(EstadoDeposito.pendiente)
                Text(L.t("Depositados", "Deposited")).tag(EstadoDeposito.depositado)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Esp.pantalla).padding(.vertical, Esp.chip)
            Divider()

            List {
                Section {
                    ForEach(vm.items) { c in
                        fila(c, tarjeta: !wide)
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
        }
    }

    private func fila(_ c: Corte, tarjeta: Bool) -> some View {
        let esSel = c.id == vm.seleccionId
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
        .filaDeLista(seleccionada: esSel, tarjeta: tarjeta)
    }
}
