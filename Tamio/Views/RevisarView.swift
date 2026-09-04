import SwiftUI

/// Pantalla "Por revisar": bandeja de asuntos que necesitan atención (esperan
/// visto bueno, sin comprobante, duplicados, etc.). Chips de filtro por tipo,
/// lista maestro-detalle, acciones por tipo (Aprobar/Editar/Devolver/…), toast
/// con Deshacer y "Aprobar todo". Fiel al handoff.
struct RevisarView: View {
    @Environment(Navegacion.self) private var nav: Navegacion?
    @State private var vm = RevisarViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var abierto: Revision?
    @State private var editando: Revision?

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    // Ancha a propósito: las filas llevan sus botones dentro.
                    // Sin material detrás de la columna — ahí no tenía nada que
                    // difuminar y se resolvía como un gris plano; el material
                    // vive donde la lista pasa por debajo. Mismo cambio que ya
                    // se hizo en Ingresos/Gastos, Aportantes y Depósitos.
                    listaColumna
                        .frame(width: Esp.columnaMaestraAncha)
                    Divider()
                    if let a = vm.seleccion { detalle(a) } else { vacio }
                }
            } else {
                listaPhone
                    .background(Color(.systemGroupedBackground))
                    .navigationDestination(item: $abierto) { a in
                        // Barra vacía: el H1 del detalle ya dice el asunto.
                        detalle(a).navigationTitle("").navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Por revisar", "To review"), subtituloBarra)
        // `.large` solo en iPad, igual que en Depósitos: en el teléfono la raíz
        // no scrollea y el título grande dejaba una franja vacía.
        .navigationBarTitleDisplayMode(sizeClass == .compact ? .inline : .large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // El conteo dice cuántos de los pendientes va a tocar: antes
                // decía "Aprobar todo" y aprobaba también el duplicado y el
                // gasto sin comprobante que había en la lista.
                Button { Task { await vm.aprobarTodo() } } label: {
                    Text(vm.aprobablesCount == vm.porRevisarCount
                         ? L.t("Aprobar todo", "Approve all")
                         : L.t("Aprobar \(vm.aprobablesCount) de \(vm.porRevisarCount)",
                               "Approve \(vm.aprobablesCount) of \(vm.porRevisarCount)"))
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)
                .disabled(vm.aprobablesCount == 0)
            }
        }
        .overlay(alignment: .bottom) { toastView }
        .animation(.snappy, value: vm.toast?.id)
        .sheet(item: $editando) { a in
            EditarAsuntoView(r: a) { concepto, importe, categoria, metodo, aportante, fecha in
                Task { await vm.editar(id: a.id, concepto: concepto, importe: importe,
                                       categoria: categoria, metodo: metodo,
                                       aportante: aportante, fecha: fecha) }
            }
        }
        .task { await vm.cargar() }
    }

    /// El subtítulo dice lo que hay, no solo cuántos: "movimientos esperan tu
    /// visto bueno" era falso desde que la bandeja lista siete cosas distintas
    /// y solo una es un visto bueno pendiente.
    private var subtituloBarra: String {
        let n = vm.porRevisarCount
        return L.t("\(n) asunto\(n == 1 ? "" : "s") por revisar",
                   "\(n) item\(n == 1 ? "" : "s") to review")
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastView: some View {
        if let t = vm.toast {
            HStack(spacing: 14) {
                Text(t.mensaje).font(.subheadline).foregroundStyle(.white).lineLimit(2)
                Spacer(minLength: 8)
                Button(L.t("Deshacer", "Undo")) { Task { await vm.deshacer() } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.brand)
            }
            .padding(.horizontal, Esp.tarjeta).padding(.vertical, 12)
            .background(Color(.label), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, Esp.pantalla).padding(.bottom, 16)
            .frame(maxWidth: 520)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: t.id) {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                if vm.toast?.id == t.id { vm.toast = nil }
            }
        }
    }

    // MARK: - Lista

    // MARK: - Lista iPhone (tarjetas)

    private var listaPhone: some View {
        ScrollView {
            // Misma separación que las demás listas: la de `Esp`.
            LazyVStack(spacing: Esp.hueco) {
                ForEach(vm.visibles) { filaTargeta($0) }
            }
            .padding(.horizontal, Esp.pantalla)
            .padding(.vertical, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .colchonInferior()
    }

    private func filaTargeta(_ a: Revision) -> some View {
        VStack(spacing: 0) {
            Button {
                vm.seleccionId = a.id
                abierto = a
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.concepto)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let imp = a.editImporte {
                            Text((a.esGasto ? "−$" : "+$") + imp)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(a.esGasto ? Paleta.negativo : Paleta.brand)
                                .monospacedDigit()
                        }
                    }
                    Text(a.detalleLista)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(a.tipo.etiquetaCorta)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(a.tipo.color)
                        .padding(.horizontal, Esp.hueco).padding(.vertical, 3)
                        .background(a.tipo.color.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, Esp.tarjeta).padding(.top, 14).padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            HStack(spacing: 8) {
                botonesTargeta(a)
            }
            .padding(.horizontal, Esp.tarjeta).padding(.vertical, 4)
        }
        // Mismo radio que `filaDeLista`: esta pantalla llevaba tarjetas de 16
        // mientras las otras ocho iban a 10, y puestas una al lado de otra se
        // leían como dos componentes distintos.
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Esp.radioFila, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    @ViewBuilder
    private func botonesTargeta(_ a: Revision) -> some View {
        if !a.acciones.isEmpty {
            let prim = a.acciones[0]
            Button { activar(prim, a) } label: {
                Text(prim.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(prim.prominente ? .white : Paleta.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(prim.prominente ? Paleta.brand : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            if a.acciones.count > 1 {
                let sec = a.acciones[1]
                Button { activar(sec, a) } label: {
                    Text(sec.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Lista iPad

    private var listaColumna: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.visibles) { filaCompacta($0) }
                HStack {
                    Text(L.t("\(vm.totalCount) por revisar", "\(vm.totalCount) to review"))
                    Spacer()
                    Text(L.t("\(vm.archivadosCount) archivados", "\(vm.archivadosCount) archived"))
                }
                .font(.caption2).foregroundStyle(.tertiary).padding(Esp.tarjeta)
            }
        }
        .background(Color(.systemGroupedBackground))
        // El desvanecido de borde: la fila deja de aparecer y desaparecer de
        // golpe al cruzar por detrás de la barra.
        .scrollEdgeEffectStyle(.soft, for: .all)
        .colchonInferior()
    }

    private func filaCompacta(_ a: Revision) -> some View {
        let esSel = a.id == vm.seleccionId
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                vm.seleccionId = a.id
                abierto = a
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.concepto)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let imp = a.editImporte {
                            Text((a.esGasto ? "−" : "+") + "$" + imp)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(a.esGasto ? Paleta.negativo : Paleta.brand)
                                .monospacedDigit()
                                .layoutPriority(1)
                        }
                    }
                    Text(a.detalleLista)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(a.tipo.etiquetaCorta)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Esp.hueco).padding(.vertical, 3)
                        .background(Paleta.brand, in: Capsule())
                }
                .padding(.horizontal, Esp.tarjeta).padding(.top, 14).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                ForEach(a.acciones.prefix(2)) { ac in
                    Button { activar(ac, a) } label: {
                        Text(ac.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ac.prominente ? .white : Paleta.brand)
                            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                            .background(ac.prominente ? Paleta.brand : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(ac.prominente ? Color.clear : Paleta.brand, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Esp.tarjeta).padding(.bottom, 14)

            Divider().padding(.leading, 16)
        }
        .background(esSel ? Paleta.brandFill : Color(.systemBackground))
        .overlay(alignment: .leading) {
            if esSel { Rectangle().fill(Paleta.brand).frame(width: 3) }
        }
    }

    // MARK: - Detalle

    private func detalle(_ a: Revision) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Un solo chip, y con la categoría concreta del pendiente
                // ("Espera visto bueno", "Duplicado probable"), que es la que
                // era el título hasta ahora. Naranja y en formato normal, como
                // los chips de las listas: el rojo queda para lo que resta
                // dinero o borra.
                Pill(texto: a.tipo.etiqueta, color: a.archivado ? .secondary : Paleta.aviso)

                Text(a.concepto).font(.title.weight(.bold))
                Text(a.descripcion).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                acciones(a)

                tarjetaCampos(a.seccionTitulo, a.campos)
                if let sec = a.seccionSecundaria {
                    tarjetaCampos(sec, a.camposSecundarios)
                }
                if let nota = a.notaPie {
                    Text(nota).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Esp.panel)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
    }

    private func acciones(_ a: Revision) -> some View {
        HStack(spacing: 10) {
            ForEach(a.acciones) { ac in
                if ac.navegacion {
                    // Solo lleva a otro lado: chevron y tint neutro. El verde
                    // prominente queda para lo que resuelve el pendiente.
                    Button { activar(ac, a) } label: {
                        HStack(spacing: 4) {
                            Text(ac.label)
                            Image(systemName: "chevron.right").font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.secondary)
                } else if ac.prominente {
                    Button { activar(ac, a) } label: { Text(ac.label).fontWeight(.semibold) }
                        .buttonStyle(.borderedProminent).tint(Paleta.brand)
                } else {
                    Button { activar(ac, a) } label: { Text(ac.label) }
                        .buttonStyle(.bordered)
                        .tint(Color.secondary)
                }
            }
            Spacer()
        }
    }

    private func activar(_ ac: AccionRevision, _ a: Revision) {
        switch ac.kind {
        case .editar: editando = a
        case .irAlCorte: irAlCorte(a)
        case .aprobar, .devolver, .restaurar:
            Task { await vm.resolver(a, kind: ac.kind) }
        }
    }

    /// **Lleva al corte concreto**, no a la lista. El id del asunto es
    /// "co-<id del corte>-firma": de ahí sale a cuál abrir.
    private func irAlCorte(_ a: Revision) {
        let partes = a.id.split(separator: "-").map(String.init)
        guard partes.count >= 2, partes[0] == "co" else { return }
        nav?.corteDestacado = partes[1]
        nav?.seccion = "depositos"
        nav?.pestana = .tesoreria
    }

    private func tarjetaCampos(_ titulo: String, _ campos: [CampoRevision]) -> some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                TituloSeccion(texto: titulo).padding(.bottom, 8)
                ForEach(Array(campos.enumerated()), id: \.element.id) { i, c in
                    filaCampo(c)
                    if i < campos.count - 1 { Divider() }
                }
            }
        }
    }

    private func filaCampo(_ c: CampoRevision) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(c.label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(c.valor).font(.subheadline.weight(c.resalte == .ninguno ? .regular : .semibold))
                .foregroundStyle(colorResalte(c.resalte)).monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func colorResalte(_ r: ResalteCampo) -> Color {
        switch r {
        case .ninguno: return .primary
        case .verde: return Paleta.brand
        case .rojo: return Paleta.negativo
        }
    }

    // MARK: - Estado vacío

    private var vacio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("Elige un asunto", "Pick an item")).font(.title2.weight(.bold))
                    Text(L.t("Toca un asunto de la lista para ver aquí su explicación y resolverlo o devolverlo.",
                             "Tap an item in the list to see its explanation here and resolve or return it."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    tarjetaConteo(L.t("Asuntos", "Items"), vm.totalCount, Paleta.brand, .primary)
                    tarjetaConteo(L.t("Esperan visto bueno", "Awaiting approval"), vm.esperanVistoBueno, Paleta.aviso, Paleta.aviso)
                    tarjetaConteo(L.t("Piden un arreglo", "Need a fix"), vm.pidenArreglo, Paleta.brand, .primary)
                    tarjetaConteo(L.t("Solo enterarse", "Just be aware"), vm.soloEnterarse, .secondary, .secondary)
                }
                Text(L.t("Un movimiento puede salir dos veces: son dos cosas distintas que revisar.",
                         "One entry can show up twice: they're two different things to review."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func tarjetaConteo(_ label: String, _ n: Int, _ acento: Color, _ colorNum: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text("\(n)").font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(colorNum).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Esp.tarjeta)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(acento).frame(height: 3).padding(.horizontal, Esp.chip) }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.separator.opacity(0.6), lineWidth: 0.5))
    }
}
