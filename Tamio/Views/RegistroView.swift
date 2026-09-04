import SwiftUI

/// Pantalla Registro: bitácora de "apuntes" — lo que ha pasado en la iglesia.
/// Lista agrupada por día con filtros (Todo/Tesorería/Secretaría/Notas) y un
/// panel de detalle. El registro guarda copias, no referencias. Fiel al handoff.
struct RegistroView: View {
    @State private var vm = RegistroViewModel()
    @State private var abierto: Apunte?
    @State private var escribiendo = false

    private let morado = Paleta.morado   // Secretaría

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: Esp.columnaMaestra)
                        .background(.regularMaterial)
                    Divider()
                    if let a = vm.seleccion { apunteDetalle(a) } else { estadoVacio }
                }
            } else {
                listaColumna
                    .background(.regularMaterial)
                    .navigationDestination(item: $abierto) { a in
                        apunteDetalle(a)
                            .navigationTitle(L.t("Apunte", "Entry"))
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Registro", "Log"),
                       L.t("\(vm.totalCount) apuntes · lo que ha pasado en la iglesia",
                           "\(vm.totalCount) entries · what has happened at church"))
        // `.large` como las once pantallas raíz restantes: con `.inline` el
        // título salía centrado sobre el panel de detalle en vez de alineado a
        // la izquierda como en todas las demás.
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { escribiendo = true } label: {
                    Label(L.t("Escribir una nota", "Write a note"), systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .sheet(isPresented: $escribiendo) {
            NuevaNotaView { texto, area in
                Task { await vm.escribirNota(texto: texto, area: area) }
            }
        }
        .task { await vm.cargar() }
    }

    // MARK: - Lista

    private var listaColumna: some View {
        VStack(spacing: 0) {
            barraFiltros
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(vm.grupos, id: \.titulo) { grupo in
                        Section {
                            ForEach(grupo.apuntes) { fila($0) }
                        } header: {
                            encabezadoDia(grupo.titulo, grupo.apuntes.count)
                        }
                    }
                    Text(L.t("\(vm.visibles.count) apuntes", "\(vm.visibles.count) entries"))
                        .font(.caption).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
    }

    private var barraFiltros: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(FiltroRegistro.allCases) { f in pastilla(f) }
            }
            Text(L.t("Ves todo: administrador", "Seeing all: administrator"))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, 12)
    }

    private func pastilla(_ f: FiltroRegistro) -> some View {
        let sel = vm.filtro == f
        return Button { vm.filtro = f } label: {
            HStack(spacing: 5) {
                Text(f.etiqueta)
                Text("\(vm.count(f))").opacity(0.6).monospacedDigit()
            }
            .font(.footnote.weight(sel ? .semibold : .regular))
            .foregroundStyle(sel ? Color(.systemBackground) : .primary)
            .padding(.horizontal, Esp.chip).padding(.vertical, 6)
            .background(sel ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color(.tertiarySystemFill)),
                        in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func encabezadoDia(_ titulo: String, _ n: Int) -> some View {
        HStack {
            Text(titulo).font(.caption.weight(.bold)).foregroundStyle(.primary)
            Spacer()
            Text(L.t("\(n) apuntes", "\(n) entries")).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Esp.pantalla).padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private func fila(_ a: Apunte) -> some View {
        let sel = a.id == vm.seleccionId
        return Button {
            vm.seleccionId = a.id
            abierto = a
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(color(a)).frame(width: 7, height: 7).padding(.top, 6)
                VStack(alignment: .leading, spacing: 5) {
                    Text(a.texto).font(.subheadline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if a.esNota {
                            Text("NOTA").font(.caption2.weight(.bold)).foregroundStyle(Paleta.aviso)
                                .padding(.horizontal, Esp.hueco).padding(.vertical, 1)
                                .background(Paleta.avisoFill, in: RoundedRectangle(cornerRadius: 4))
                        }
                        Text(meta(a)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
            }
            .padding(.horizontal, Esp.fila).padding(.vertical, 11)
            .background(fondoFila(a, sel: sel))
            .overlay(alignment: .leading) {
                if sel { Rectangle().fill(Paleta.brand).frame(width: 3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func meta(_ a: Apunte) -> String {
        a.esNota ? "\(a.autor) · \(a.area.etiqueta) · \(a.hora)" : "\(a.autor) · \(a.hora)"
    }

    private func color(_ a: Apunte) -> Color {
        if a.esNota { return Paleta.aviso }
        if a.esAlerta { return Paleta.negativo }
        return a.area == .tesoreria ? Paleta.brand : morado
    }

    private func fondoFila(_ a: Apunte, sel: Bool) -> Color {
        if sel { return Paleta.brandFill }
        if a.esNota { return Paleta.avisoFill }
        if a.esAlerta { return Paleta.negativoFill }
        return .clear
    }

    // MARK: - Detalle de un apunte

    private func apunteDetalle(_ a: Apunte) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    if a.esNota { Pill(texto: L.t("Nota", "Note"), color: Paleta.aviso) }
                    else if a.esAlerta { Pill(texto: L.t("No cuadró", "Didn't match"), color: Paleta.negativo) }
                    else { Pill(texto: a.area.etiqueta, color: color(a)) }
                    Spacer()
                    Text("\(a.fecha) · \(a.hora)").font(.caption).foregroundStyle(.secondary)
                }
                Text(a.texto).font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Tarjeta {
                    VStack(alignment: .leading, spacing: 0) {
                        TituloSeccion(texto: L.t("QUÉ QUEDÓ GUARDADO", "WHAT WAS SAVED"))
                            .padding(.bottom, 8)
                        FieldRow(label: L.t("Área", "Area"), value: a.area.etiqueta)
                        Divider()
                        FieldRow(label: L.t("Registrado por", "Logged by"), value: a.autor)
                        Divider()
                        FieldRow(label: L.t("Cuándo", "When"), value: "\(a.fecha) · \(a.hora)")
                        if let folio = a.folio {
                            Divider()
                            FieldRow(label: L.t("Folio (copia)", "Folio (copy)"), value: folio)
                        }
                    }
                }

                tarjetaCopias
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Estado vacío

    private var estadoVacio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("Elige un apunte", "Pick an entry")).font(.title2.weight(.bold))
                    Text(L.t("Toca una línea de la lista para ver aquí lo que quedó guardado de ella: qué pasó, quién lo hizo y con qué datos.",
                             "Tap a line in the list to see what was saved: what happened, who did it, and with what data."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                tarjetaCopias
                tarjetas
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var tarjetaCopias: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("El registro guarda copias, no referencias", "The log keeps copies, not references"))
                    .font(.subheadline.weight(.semibold))
                Text(L.t("Cada apunte se queda con el nombre y el folio tal como eran en ese momento, así que sigue diciendo la verdad aunque la fila de la que habla ya no exista. Nada de lo que hay aquí se edita ni se borra: es lo que hace que sirva de registro.",
                         "Each entry keeps the name and folio exactly as they were at that moment, so it still tells the truth even if the row it refers to no longer exists. Nothing here is edited or deleted: that's what makes it a log."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                (Text(L.t("Lo que falta por hacer no vive aquí, sino en ", "What's left to do doesn't live here, but in "))
                    .font(.caption).foregroundStyle(.secondary)
                 + Text(L.t("Por revisar", "To review")).font(.caption.weight(.semibold)).foregroundColor(Paleta.enlace))
            }
        }
    }

    private var tarjetas: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tarjetaConteo(L.t("Apuntes", "Entries"), vm.totalCount, Paleta.brand, .primary)
            tarjetaConteo(L.t("Tesorería", "Treasury"), vm.tesoreriaCount, Paleta.brand, Paleta.brand)
            tarjetaConteo(L.t("Secretaría", "Secretary"), vm.secretariaCount, morado, .primary)
            tarjetaConteo(L.t("Notas a mano", "Hand notes"), vm.notasCount, Paleta.aviso, Paleta.aviso)
        }
    }

    private func tarjetaConteo(_ label: String, _ n: Int, _ acento: Color, _ colorNum: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(n)").font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(colorNum).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(acento).frame(height: 3).padding(.horizontal, Esp.chip)
        }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.separator.opacity(0.6), lineWidth: 0.5))
    }
}
