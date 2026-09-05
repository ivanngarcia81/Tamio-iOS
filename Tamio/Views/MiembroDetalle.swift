import SwiftUI
import Charts

/// Ficha de un miembro: cabecera con avatar y acciones, asistencia del
/// periodo (gráfica), datos, expediente e historial.
///
/// **Aquí no van los indicadores del padrón.** La ficha encabezaba con el
/// resumen entero —248 en el padrón, altas del periodo, Ausencias e
/// Incompletos—, así que las mismas ocho cifras se repetían en la ficha de
/// cada una de las 248 personas, y en el teléfono ocupaban la pantalla antes
/// de decir nada de quien se había abierto. Ese resumen es del padrón, no de
/// la persona: su sitio es el hub de Secretaría, donde ya estaba.
struct MiembroDetalle: View {
    let miembro: Miembro
    let onEditar: () -> Void
    let onSeguimiento: () -> Void
    /// Alta y baja de parentescos. El padrón es su dueño, así que se editan
    /// aquí y en la ficha del aportante solo se leen.
    var onAgregarPariente: ((Pariente) -> Void)? = nil
    var onQuitarPariente: ((String) -> Void)? = nil

    @State private var mostrarNuevoPariente = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecera
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { columnaIzquierda; columnaDerecha.frame(width: 320) }
                    VStack(spacing: 16) { columnaIzquierda; columnaDerecha }
                }
            }
            .padding(Esp.panel)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Cabecera de la ficha

    private var cabecera: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarMiembro
            VStack(alignment: .leading, spacing: 8) {
                Text(miembro.nombre)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    // **La pastilla decía "Miembro activo" siempre**, escrito
                    // a mano: quien estaba de baja aparecía como activo, y
                    // encima con el color de baja, así que el color y la
                    // palabra se contradecían en la misma cápsula.
                    Pill(texto: miembro.estado.etiqueta, color: miembro.estado.color)
                    Text(miembro.miembroDesde).font(.caption).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text(miembro.area).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                botonesMiembro
            }
        }
    }

    private var avatarMiembro: some View {
        Avatar(iniciales: miembro.iniciales, color: miembro.estado.color, lado: 60)
    }

    private var botonesMiembro: some View {
        HStack(spacing: 10) {
            // Mismo par que en la ficha del aportante: glass en los dos, el
            // verde para el que cambia el dato. `.borderedProminent` daba
            // relleno verde con el texto en blanco.
            Button { onSeguimiento() } label: { Text(L.t("Seguimiento", "Follow-up")) }
                .buttonStyle(.glass).tint(Color.secondary)
            Button { onEditar() } label: { Label(L.t("Editar", "Edit"), systemImage: "pencil").fontWeight(.semibold) }
                .buttonStyle(.glass).tint(Paleta.brand)
        }
    }

    // MARK: - Columna izquierda (asistencia + datos)

    private var columnaIzquierda: some View {
        VStack(alignment: .leading, spacing: 16) {
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TituloSeccion(texto: L.t("ASISTENCIA DEL PERIODO", "ATTENDANCE"))
                        Spacer()
                        Text("\(miembro.asistenciaPct)%").font(.title3.weight(.bold)).monospacedDigit()
                    }
                    Chart(miembro.asistencia) { m in
                        BarMark(x: .value("Mes", m.mes), y: .value("Asistencia", m.valor))
                            .foregroundStyle(m.mes == miembro.asistencia.last?.mes ? Paleta.brand : Paleta.brandMuted)
                            .cornerRadius(3)
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 90)
                    HStack(spacing: 20) {
                        stat(L.t("En roster", "In roster"), miembro.enRoster)
                        stat(L.t("Racha sin asistir", "Missed streak"), miembro.rachaSinAsistir)
                        stat(L.t("Última visita", "Last visit"), miembro.ultimaVisita)
                    }
                }
            }
            Tarjeta {
                VStack(spacing: 0) {
                    ForEach(Array(miembro.datos.enumerated()), id: \.element.id) { i, d in
                        HStack {
                            Text(d.etiqueta).font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(d.valor).font(.subheadline.weight(.medium))
                        }
                        .padding(.vertical, 10)
                        if i < miembro.datos.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    /// Los parentescos del miembro. El botón de añadir estaba en la ficha del
    /// aportante (Tesorería) y encima deshabilitado: ni se podía usar, ni era
    /// el sitio. Aquí sí, porque el padrón es de Secretaría.
    private var tarjetaFamilia: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                TituloSeccion(texto: L.t("FAMILIA", "FAMILY"))
                if miembro.familia.isEmpty {
                    Text(L.t("Sin parentescos registrados.", "No family links yet."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(miembro.familia) { p in
                    HStack(spacing: 10) {
                        Text(p.etiqueta).font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(p.nombre).font(.subheadline)
                        Spacer()
                        if let onQuitarPariente {
                            Button(role: .destructive) { onQuitarPariente(p.id) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Paleta.negativo)
                        }
                    }
                }
                if onAgregarPariente != nil {
                    Divider()
                    // `.buttonStyle(.plain)` y el verde escrito: sin él el
                    // tint del TabView pintaba la fila, y con el tint el
                    // sistema le añadía además su propio fondo dentro de una
                    // tarjeta que ya es una superficie.
                    Button { mostrarNuevoPariente = true } label: {
                        Label(L.t("Añadir pariente", "Add relative"), systemImage: "plus")
                            .font(.subheadline)
                            .foregroundStyle(Paleta.brand)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $mostrarNuevoPariente) {
            NuevoParienteView { p in onAgregarPariente?(p) }
        }
    }

    /// Cuántos campos del expediente están puestos. Es el mismo criterio con
    /// el que el padrón cuenta sus "Incompletos" (`MembresiaViewModel`), así
    /// que la ficha y la lista no pueden discrepar.
    private var expedienteCompleto: Bool {
        !miembro.expediente.contains { !$0.completo }
    }

    private var etiquetaExpediente: String {
        if expedienteCompleto { return L.t("Completo", "Complete") }
        let hechos = miembro.expediente.filter(\.completo).count
        return L.t("\(hechos) de \(miembro.expediente.count)",
                   "\(hechos) of \(miembro.expediente.count)")
    }

    private func stat(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption2).foregroundStyle(.secondary)
            Text(valor).font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Columna derecha (expediente + historial)

    private var columnaDerecha: some View {
        VStack(alignment: .leading, spacing: 16) {
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TituloSeccion(texto: L.t("EXPEDIENTE", "RECORD"))
                        Spacer()
                        // **Decía "Completo" en verde con campos sin marcar.**
                        // Era una etiqueta fija encima de una lista de
                        // palomitas que contaba otra cosa, y el padrón usa
                        // justamente ese dato para el indicador de
                        // "Incompletos": no podían decir cosas distintas.
                        Text(etiquetaExpediente)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(expedienteCompleto ? Paleta.brand : Paleta.aviso)
                    }
                    ForEach(miembro.expediente) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.completo ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.completo ? Paleta.brand : .secondary)
                            Text(item.campo).font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }
            tarjetaFamilia
            Tarjeta {
                VStack(alignment: .leading, spacing: 12) {
                    TituloSeccion(texto: L.t("MOVIMIENTOS DE MEMBRESÍA", "MEMBERSHIP HISTORY"))
                    ForEach(Array(miembro.movimientos.enumerated()), id: \.element.id) { i, m in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(i == 0 ? Paleta.brand : Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.titulo).font(.subheadline.weight(.medium))
                                Text(m.fecha).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
