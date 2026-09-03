import SwiftUI
import Charts

/// Ficha del aportante: cabecera, sub-pestañas Datos/Aportes/Familia/Asistencia,
/// tarjeta de datos y tarjeta de aportes con gráfica, selector de año e
/// historial. Layout seguro (sin el combo que colgaba la app).
struct AportanteDetalle: View {
    let a: Aportante
    var onEditar: (() -> Void)? = nil
    var onEliminar: (() -> Void)? = nil
    @State private var subtab = 0   // 0 Datos · 1 Aportes · 2 Familia · 3 Asistencia
    @State private var anio = "2026"
    @State private var confirmarEliminar = false

    /// Texto de la constancia anual, para compartir/exportar.
    private var constanciaTexto: String {
        L.t("Constancia de aportaciones \(anio)\n\(a.nombre)\nID fiscal: \(a.idFiscal)\nTotal aportado: \(Money.fmt(a.aportesTotal)) MXN\nIglesia Getsemaní, Monterrey, N.L.",
            "\(anio) Giving statement\n\(a.nombre)\nTax ID: \(a.idFiscal)\nTotal given: \(Money.fmt(a.aportesTotal)) MXN\nIglesia Getsemaní, Monterrey, N.L.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecera
                Picker("", selection: $subtab) {
                    Text(L.t("Datos", "Details")).tag(0)
                    Text(L.t("Aportes", "Giving")).tag(1)
                    Text(L.t("Familia", "Family")).tag(2)
                    Text(L.t("Asistencia", "Attendance")).tag(3)
                }
                .pickerStyle(.segmented)

                // Izquierda: cambia con la pestaña. Derecha: Aportes (siempre).
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        tarjetaIzquierda.frame(maxWidth: .infinity, alignment: .topLeading)
                        tarjetaAportes.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    VStack(spacing: 16) { tarjetaIzquierda; tarjetaAportes }
                }
            }
            .padding(24)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) { avatar; info; Spacer(minLength: 8); botones }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) { avatar; info }
                botones
            }
        }
    }

    private var avatar: some View {
        Text(a.iniciales)
            .font(.title3.weight(.bold)).foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(a.estado.color, in: Circle())
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(a.nombre).font(.title.weight(.bold)).lineLimit(2).minimumScaleFactor(0.8)
            HStack(spacing: 8) {
                Pill(texto: a.estado.etiqueta, color: a.estado.color)
                Text(a.bautizadoAnio).font(.caption).foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text(a.rol).font(.caption).foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text(a.ministerios).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var eliminarBoton: some View {
        Button(role: .destructive) { confirmarEliminar = true } label: {
            Label(L.t("Eliminar", "Delete"), systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .confirmationDialog(L.t("¿Eliminar a \(a.nombre)?", "Delete \(a.nombre)?"),
                            isPresented: $confirmarEliminar, titleVisibility: .visible) {
            Button(L.t("Eliminar", "Delete"), role: .destructive) { onEliminar?() }
            Button(L.t("Cancelar", "Cancel"), role: .cancel) {}
        }
    }

    private var botones: some View {
        ViewThatFits(in: .horizontal) {
            // Ancho (iPad): tres en línea
            HStack(spacing: 8) {
                Button { onEditar?() } label: { Label(L.t("Editar", "Edit"), systemImage: "pencil") }
                    .buttonStyle(.bordered)
                    .tint(Color.secondary)
                eliminarBoton
                ShareLink(item: constanciaTexto) {
                    Label(L.t("Constancia anual (PDF)", "Annual receipt (PDF)"), systemImage: "doc.text").fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent).tint(Paleta.brand)
            }
            // Estrecho (iPhone): Edit+Delete arriba, PDF abajo
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button { onEditar?() } label: { Label(L.t("Editar", "Edit"), systemImage: "pencil") }
                        .buttonStyle(.bordered)
                        .tint(Color.secondary)
                    eliminarBoton
                }
                ShareLink(item: constanciaTexto) {
                    Label(L.t("Constancia anual (PDF)", "Annual receipt (PDF)"), systemImage: "doc.text").fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent).tint(Paleta.brand)
            }
        }
    }

    // MARK: - Columna izquierda (cambia por pestaña)

    @ViewBuilder
    private var tarjetaIzquierda: some View {
        switch subtab {
        case 1: tarjetaAportesCompleto
        case 2: tarjetaFamilia
        case 3: tarjetaAsistencia
        default: tarjetaDatos
        }
    }

    private var tarjetaFamilia: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(a.familia.enumerated()), id: \.element.id) { i, p in
                    HStack {
                        Text(p.relacion).font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(p.nombre).font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    if i < a.familia.count - 1 { Divider() }
                }
                Divider()
                Button { } label: {
                    Label(L.t("Añadir pariente", "Add relative"), systemImage: "plus")
                        .font(.subheadline)
                }
                .padding(.vertical, 10)
                .disabled(true).opacity(0.4)
            }
        }
    }

    private var tarjetaAsistencia: some View {
        Tarjeta {
            VStack(spacing: 0) {
                filaDato(L.t("Servicios registrados", "Services logged"), "\(a.serviciosRegistrados)")
                Divider(); filaDato(L.t("Presencias", "Attended"), a.presencias)
                Divider(); filaDato(L.t("Última visita", "Last visit"), a.ultimaVisita)
            }
        }
    }

    private var tarjetaAportesCompleto: some View {
        Tarjeta {
            VStack(spacing: 0) {
                ForEach(Array(a.aportes.enumerated()), id: \.element.id) { i, ap in
                    HStack {
                        Text(ap.fecha).font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 120, alignment: .leading)
                        Text(ap.concepto).font(.subheadline)
                        Spacer()
                        Text(Money.fmt(ap.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    .padding(.vertical, 10)
                    if i < a.aportes.count - 1 { Divider() }
                }
            }
        }
    }

    // MARK: - Datos

    private var tarjetaDatos: some View {
        Tarjeta {
            VStack(spacing: 0) {
                filaDato(L.t("Teléfono", "Phone"), a.telefono)
                Divider(); filaDato(L.t("Correo", "Email"), a.correo)
                Divider(); filaDato(L.t("Nacimiento", "Birth"), a.nacimiento)
                Divider(); filaDato(L.t("Dirección", "Address"), a.direccion)
                Divider(); filaDato(L.t("Estado civil", "Marital status"), a.estadoCivil)
                Divider(); filaDato(L.t("ID fiscal", "Tax ID"), a.idFiscal)
                Divider(); filaDato(L.t("Miembro desde", "Member since"), a.miembroDesde)
                Divider(); filaDato(L.t("Congrega desde", "Attends since"), a.congregaDesde)
                Divider(); filaDato(L.t("Bautismo", "Baptism"), a.bautismo)
                Divider(); filaDato(L.t("Ministerios", "Ministries"), a.ministerios)
                Divider(); filaDato(L.t("Cargos", "Roles"), a.cargos)
            }
        }
    }

    private func filaDato(_ label: String, _ valor: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(valor).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Aportes

    private var tarjetaAportes: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L.t("Total \(anio)", "Total \(anio)")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.fmt(a.aportesTotal)).font(.title3.weight(.bold)).monospacedDigit()
                }
                Chart(a.aportesSerie) { m in
                    BarMark(x: .value("Mes", m.mes), y: .value("Monto", m.monto))
                        .foregroundStyle(m.mes == a.aportesSerie.last?.mes ? Paleta.brand : Paleta.brandMuted)
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .frame(height: 80)
                Text(a.aportesPromedio).font(.caption).foregroundStyle(.secondary)

                Picker(L.t("Año", "Year"), selection: $anio) {
                    Text("2026").tag("2026"); Text("2025").tag("2025"); Text("2024").tag("2024")
                }
                .pickerStyle(.segmented)

                ForEach(Array(a.aportesRecientes.enumerated()), id: \.element.id) { i, ap in
                    HStack {
                        Text("\(ap.concepto) · \(ap.fecha)").font(.subheadline)
                        Spacer()
                        Text(Money.fmt(ap.monto)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    if i < a.aportesRecientes.count - 1 { Divider() }
                }
            }
        }
    }
}
