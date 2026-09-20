import SwiftUI
import Charts

/// **Membresía, según el handoff definitivo.**
///
/// No es una tabla, y eso fue una corrección: la primera versión de esta
/// pantalla se hizo contra el handoff anterior, donde Membership sí era una
/// tabla de cinco columnas. El diseño la rehizo entera.
///
/// Tres subpestañas —Miembros, Asistencia y Seguimiento— y encima una tira de
/// ocho indicadores que sale de `MembresiaResumen`. La lista son TARJETAS y no
/// filas: cada persona trae iniciales, estado, roster, asistencia y la marca
/// de expediente incompleto, y eso no cabe legible en una fila de tabla.
struct PantallaMembresia: View {
    let vm: MembresiaViewModel
    @Binding var seleccion: String?
    @Binding var sub: SubMembresia

    enum SubMembresia: String, CaseIterable, Identifiable {
        case miembros, asistencia, seguimiento
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .miembros:    return L.t("Miembros", "Members")
            case .asistencia:  return L.t("Asistencia", "Attendance")
            case .seguimiento: return L.t("Seguimiento", "Follow-up")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cabecera
                tira
                switch sub {
                case .miembros:    listaDeMiembros
                case .asistencia:  panelAsistencia
                case .seguimiento: panelSeguimiento
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Color.fondoAgrupado)
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        HStack(spacing: 12) {
            Picker("", selection: $sub) {
                ForEach(SubMembresia.allCases) { Text($0.titulo).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer(minLength: 0)
            Text(L.t("\(vm.itemsFiltrados.count) de \(vm.items.count) personas",
                     "\(vm.itemsFiltrados.count) of \(vm.items.count) people"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Los ocho indicadores

    /// **Salen de `MembresiaResumen`, que se calcula del padrón.** El propio
    /// modelo lo documenta: "se calcula del padrón, nunca se escribe a mano".
    /// Los tres primeros son estados y se excluyen entre sí; los cinco
    /// restantes son movimientos y señales, y por eso NO suman al total.
    private var tira: some View {
        let r = vm.resumen
        let datos: [(String, Int, Color)] = [
            (L.t("Activos", "Active"), r?.activos ?? 0, Paleta.brand),
            (L.t("Inactivos", "Inactive"), r?.inactivos ?? 0, Paleta.aviso),
            (L.t("Bajas", "Removed"), r?.bajas ?? 0, .secondary),
            (L.t("Nuevos del año", "New this year"), r?.nuevos ?? 0, Paleta.cian),
            (L.t("Recibidos", "Received"), r?.recibidos ?? 0, Paleta.cian),
            (L.t("Trasladados", "Transferred out"), r?.trasladados ?? 0, .secondary),
            (L.t("Con ausencias", "With absences"), r?.ausencias ?? 0, Paleta.aviso),
            (L.t("Expediente incompleto", "Incomplete file"), r?.incompletos ?? 0, Paleta.aviso),
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 8),
                         spacing: 9) {
            ForEach(Array(datos.enumerated()), id: \.offset) { _, d in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(d.1)")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(d.2)
                    Text(d.0)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.tarjeta,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Miembros

    private var listaDeMiembros: some View {
        VStack(alignment: .leading, spacing: 0) {
            chips.padding(.top, 18)
            LazyVStack(spacing: 7) {
                ForEach(vm.itemsFiltrados) { tarjeta($0) }
            }
            .padding(.top, 14)
        }
    }

    /// Los ocho recortes: Todos, los cuatro del registro, Baja, y los dos que
    /// piden acción. **Son los mismos que ya tenía el ViewModel**, no una lista
    /// nueva: `filtroEstado` toma una clave de `EstadoMiembro.claves` y
    /// `filtroAccion` las dos señales.
    private var chips: some View {
        FlowChips {
            chip(L.t("Todos", "All"), activo: vm.filtroEstado == nil && vm.filtroAccion == nil) {
                vm.filtroEstado = nil; vm.filtroAccion = nil
            }
            ForEach(EstadoMiembro.claves, id: \.self) { clave in
                chip(EstadoMiembro.etiqueta(clave: clave),
                     activo: vm.filtroEstado == clave && vm.filtroAccion == nil) {
                    vm.filtroEstado = clave; vm.filtroAccion = nil
                }
            }
            chip(L.t("Con ausencias", "With absences"), activo: vm.filtroAccion == .ausencias) {
                vm.filtroAccion = .ausencias; vm.filtroEstado = nil
            }
            chip(L.t("Expediente incompleto", "Incomplete file"),
                 activo: vm.filtroAccion == .incompletos) {
                vm.filtroAccion = .incompletos; vm.filtroEstado = nil
            }
        }
    }

    private func chip(_ rotulo: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(rotulo)
                .font(.system(size: 12, weight: activo ? .semibold : .regular))
                .foregroundStyle(activo ? Paleta.brand : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(activo ? Paleta.brandFill : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tarjeta(_ m: Miembro) -> some View {
        let elegido = seleccion == m.id
        return Button { seleccion = m.id } label: {
            HStack(spacing: 13) {
                Text(m.iniciales)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Paleta.brand)
                    .frame(width: 36, height: 36)
                    .background(Paleta.brandFill, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(m.nombre)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Text(subtituloDe(m))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)

                // **La marca de expediente incompleto, antes que la píldora.**
                // Es lo que hay que ir a arreglar; el estado solo dice dónde
                // está esa persona.
                if !m.expedienteCompleto {
                    Text(L.t("Expediente incompleto", "Incomplete file"))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Text(m.estado.etiqueta)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(m.estado.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(m.estado.color.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(m.cargoLegible)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 92, alignment: .trailing)

                // Sin listas tomadas no es 0 %: es que nadie apuntó.
                Text(m.asistenciaResumen == nil ? "—" : "\(m.asistenciaPct)%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(m.asistenciaResumen == nil ? Color.secondary : m.tintaDeAsistencia)
                    .frame(width: 48, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(elegido ? Paleta.brandFill : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.quaternary, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtituloDe(_ m: Miembro) -> String {
        let desde = m.fechaIngreso.isEmpty ? "" : Fechas.diaLegible(m.fechaIngreso)
        let ministerio = m.ministerios.isEmpty ? "" : Padron.etiquetas(m.ministerios)
        if desde.isEmpty { return ministerio.isEmpty ? "—" : ministerio }
        let entro = L.t("Ingresó \(desde)", "Joined \(desde)")
        return ministerio.isEmpty ? entro : "\(entro) · \(ministerio.lowercased())"
    }

    // MARK: - Asistencia

    @ViewBuilder
    private var panelAsistencia: some View {
        if let a = vm.asistencia {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    kpi(L.t("Asistencia media", "Average attendance"), "\(a.promedioPct)%", Paleta.brand)
                    kpi(L.t("Servicios del periodo", "Services this period"), "\(a.serviciosPeriodo)", .primary)
                    kpi(L.t("Presentes de media", "Average present"), "\(a.presentesPromedio)", .primary)
                    kpi(L.t("Mejor servicio", "Best service"),
                        a.mejorServicio.isEmpty ? "—" : a.mejorServicio, Paleta.placaMorado)
                }
                HStack(alignment: .top, spacing: 12) {
                    panel(L.t("PRESENTES CONTRA PADRÓN", "PRESENT VS ROSTER")) {
                        if a.meses.isEmpty {
                            sinDatos
                        } else {
                            Chart(a.meses) { m in
                                BarMark(x: .value("Mes", m.mes),
                                        y: .value("Presentes", m.presentes))
                                    .foregroundStyle(Paleta.brand)
                                    .cornerRadius(4)
                            }
                            .frame(height: 150)
                            .padding(.top, 14)
                        }
                    }
                    panel(L.t("MEDIA POR TIPO DE CULTO", "AVERAGE BY SERVICE TYPE")) {
                        if a.porTipo.isEmpty {
                            sinDatos
                        } else {
                            let tope = max(1, a.porTipo.map(\.promedio).max() ?? 1)
                            VStack(spacing: 12) {
                                ForEach(a.porTipo) { t in
                                    VStack(spacing: 5) {
                                        HStack {
                                            Text(t.tipo).font(.system(size: 12))
                                            Spacer(minLength: 6)
                                            Text("\(t.promedio)")
                                                .font(.system(size: 12))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                        }
                                        GeometryReader { g in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(.quaternary)
                                                Capsule().fill(Paleta.brand)
                                                    .frame(width: g.size.width
                                                           * CGFloat(t.promedio) / CGFloat(tope))
                                            }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                            }
                            .padding(.top, 14)
                        }
                    }
                    .frame(width: 300)
                }
            }
            .padding(.top, 18)
        } else {
            sinDatos.padding(.top, 30)
        }
    }

    // MARK: - Seguimiento

    @ViewBuilder
    private var panelSeguimiento: some View {
        let gente = vm.itemsSeguimiento
        if gente.isEmpty {
            Text(L.t("Nadie necesita seguimiento ahora mismo.",
                     "Nobody needs follow-up right now."))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.top, 30)
        } else {
            VStack(spacing: 10) {
                ForEach(gente) { m in
                    let porAusencias = m.tieneAusencias
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Text(porAusencias ? L.t("AUSENCIAS", "ABSENCES")
                                              : L.t("EXPEDIENTE", "FILE"))
                                .font(.system(size: 11, weight: .bold))
                                .kerning(0.5)
                                .foregroundStyle(porAusencias ? Paleta.aviso : Paleta.cian)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background((porAusencias ? Paleta.aviso : Paleta.cian).opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(m.nombre).font(.system(size: 13.5, weight: .semibold))
                            Spacer(minLength: 0)
                            Text(m.cargoLegible)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                        }
                        Text(porAusencias
                             ? L.t("Lleva servicios seguidos sin asistir.",
                                   "Several services in a row without attending.")
                             : L.t("Faltan datos en su expediente.",
                                   "Their file is missing data."))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.tarjeta,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.top, 18)
        }
    }

    // MARK: - Piezas

    private func kpi(_ k: String, _ v: String, _ tinta: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(k).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Text(v)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tinta)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.tarjeta,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func panel<C: View>(_ titulo: String, @ViewBuilder c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.tarjeta,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sinDatos: some View {
        Text(L.t("Todavía no se ha tomado lista en ningún servicio.",
                 "Attendance hasn't been taken at any service yet."))
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 26)
    }
}

/// Chips que saltan de renglón cuando no caben. `LazyVGrid` no vale: aquí cada
/// chip mide lo que mide su texto, y en dos idiomas distintos.
struct FlowChips<C: View>: View {
    @ViewBuilder let contenido: C
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { contenido }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { contenido }
            }
        }
    }
}

// MARK: - Lo que la ficha y la tarjeta necesitan del modelo

extension Miembro {
    /// Los cargos en palabras: lo que el handoff llama "Role".
    ///
    /// **Cargo NO es ministerio.** El cargo es qué eres —diácono, ujier—; el
    /// ministerio es dónde sirves —música, niños—. La primera versión de esta
    /// pantalla leía `ministerios` en la columna que el diseño rotula "Role",
    /// y el propio modelo ya los tenía separados y rotulados "Cargos / Roles".
    var cargoLegible: String {
        cargos.isEmpty ? "—" : Padron.etiquetas(cargos)
    }

    var ministerioLegible: String {
        ministerios.isEmpty ? "—" : Padron.etiquetas(ministerios)
    }

    /// Los tres tramos del handoff: verde desde 85, ámbar desde 65, rojo debajo.
    var tintaDeAsistencia: Color {
        if asistenciaPct >= 85 { return Paleta.brand }
        if asistenciaPct >= 65 { return Paleta.aviso }
        return Paleta.negativo
    }
}
