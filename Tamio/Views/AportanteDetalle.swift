import SwiftUI
import Charts

/// Ficha del aportante: cabecera, sub-pestañas Datos/Aportes/Familia/Constancia,
/// tarjeta de datos y tarjeta de aportes con gráfica, selector de año e
/// historial. Layout seguro (sin el combo que colgaba la app).
struct AportanteDetalle: View {
    let a: Aportante
    var onEditar: (() -> Void)? = nil
    /// Ya no se puede borrar a nadie desde aquí: dar de baja a una persona
    /// es del padrón, y el padrón lo lleva Secretaría. Un botón que borra
    /// fichas en una pantalla de Tesorería es la peor versión de tener el dato
    /// en el sitio equivocado.
    @State private var subtab = 0   // 0 Datos · 1 Aportes · 2 Familia · 3 Constancia
    /// El año que se está mirando. Era el `String` "2026" fijo y el total que
    /// tenía al lado no dependía de él: cambiar de año en el segmentado no
    /// movía ni la cifra ni la gráfica.
    @State private var anio = Calendar.current.component(.year, from: Date())

    /// Texto de la constancia anual, para compartir/exportar.
    @State private var documento: DocumentoAportanteView.Tipo?
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// En iPad la ficha es la COLUMNA de detalle, no la pantalla: subir sus
    /// controles a la barra los alejaría de la ficha y los pondría junto a los
    /// de la lista. Misma frontera que en el resto de la app.
    private var compacto: Bool { sizeClass == .compact }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cabecera
                // En el teléfono el segmentado y los botones se van a la barra:
                // la tira entre el nombre y las tarjetas desaparece.
                if !compacto { segmentado }

                // Izquierda: cambia con la pestaña. Derecha: Aportes (siempre).
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        tarjetaIzquierda.frame(maxWidth: .infinity, alignment: .topLeading)
                        tarjetaAportes.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    VStack(spacing: 16) { tarjetaIzquierda; tarjetaAportes }
                }
            }
            .padding(Esp.panel)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: .all)
        // El nombre estaba DOS veces: en la barra y en el H1 de la ficha, uno
        // encima del otro. Se queda el H1, que es el que lleva el avatar y las
        // etiquetas, y la barra se libera para el segmentado.
        .navigationTitle(compacto ? "" : a.nombre)
        .toolbar { barra }
        .sheet(item: $documento) { tipo in
            DocumentoAportanteView(aportante: a, tipo: tipo)
        }
    }

    private var segmentado: some View {
        Picker("", selection: $subtab) {
            ForEach(Array(Self.secciones.enumerated()), id: \.offset) { i, nombre in
                Text(nombre).tag(i)
            }
        }
        .pickerStyle(.segmented)
    }

    /// **La barra del teléfono: la sección en el lugar del título y las dos
    /// acciones fundidas a la derecha.**
    ///
    /// La sección va como MENÚ y no como segmentado: "Datos · Aportes ·
    /// Familia · Constancia" son cuatro palabras largas y en la barra se
    /// truncaban a "Det… Givi… Fam… Con…", que no dice ninguna de las cuatro.
    /// Es la misma salida que en Reportes cuando el ancho no da: la etiqueta
    /// dice dónde estás y el menú enseña las cuatro enteras.
    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        if compacto {
            ToolbarItem(placement: .title) {
                menuSeccion
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                botonEditar
                menuDocumentos
            }
        }
    }

    /// Las cuatro secciones de la ficha, con la que se está viendo por
    /// etiqueta.
    private var menuSeccion: some View {
        Menu {
            ForEach(Array(Self.secciones.enumerated()), id: \.offset) { i, nombre in
                Button { subtab = i } label: {
                    if i == subtab { Label(nombre, systemImage: "checkmark") } else { Text(nombre) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(Self.secciones[min(subtab, Self.secciones.count - 1)]).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, Esp.chip).padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
    }

    /// Un solo sitio con los cuatro nombres: el segmentado del iPad y el menú
    /// del teléfono los leían por separado y podían separarse sin que nadie lo
    /// decidiera.
    private static var secciones: [String] {
        [L.t("Datos", "Details"), L.t("Aportes", "Giving"),
         L.t("Familia", "Family"), L.t("Constancia", "Consistency")]
    }

    private var botonEditar: some View {
        Button { onEditar?() } label: {
            Label(L.t("Editar", "Edit"), systemImage: "pencil")
        }
        .buttonStyle(.glass)
        .tint(Color.secondary)
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
        Avatar(iniciales: a.iniciales, color: a.estado.color, lado: 60)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(a.nombre).font(.title.weight(.bold)).lineLimit(2).minimumScaleFactor(0.8)
            // Antes aquí salían el año de bautismo y los ministerios: son del
            // padrón, que lleva Secretaría, y no le dicen nada al tesorero.
            HStack(spacing: 8) {
                Pill(texto: a.estado.etiqueta, color: a.estado.color)
                Text(a.rol).font(.caption).foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                Text(L.t("Aporta \(a.frecuencia.etiqueta.lowercased())",
                         "Gives \(a.frecuencia.etiqueta.lowercased())"))
                    .font(.caption).foregroundStyle(.secondary)
                if a.atrasadoEnAportes {
                    Pill(texto: L.t("Sin aportar", "Lapsed"), color: Paleta.aviso)
                }
            }
        }
    }

    /// Antes aquí había un `ShareLink` que compartía **cinco líneas de texto**
    /// pese a que el botón decía "(PDF)". Ahora son dos documentos de verdad.
    private var menuDocumentos: some View {
        Menu {
            Button {
                documento = .reporte
            } label: {
                Label(L.t("Reporte de aportes…", "Giving report…"), systemImage: "doc.text")
            }
            Button {
                documento = .constancia
            } label: {
                Label(L.t("Constancia anual…", "Annual statement…"), systemImage: "doc.badge.gearshape")
            }
        } label: {
            Label(L.t("Documentos", "Documents"), systemImage: "doc.text").fontWeight(.semibold)
        }
        // `.glass` con el verde de marca: el relleno verde con el texto en
        // blanco da ~2.4:1 en oscuro, que es por lo que se quitó de la app.
        .labelStyle(.titleAndIcon)
        .buttonStyle(.glass).tint(Paleta.brand)
    }

    @ViewBuilder
    private var botones: some View {
        if compacto {
            // Ya viven en la barra.
            EmptyView()
        } else {
            botonesColumna
        }
    }

    private var botonesColumna: some View {
        ViewThatFits(in: .horizontal) {
            // Ancho (iPad): tres en línea
            HStack(spacing: 8) {
                botonEditar
                menuDocumentos
            }
            // Estrecho (iPhone): Editar arriba, documentos abajo. (El botón
            // de eliminar se fue con 6f7a544: dar de baja a alguien del padrón
            // es de Secretaría, no de Tesorería.)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { botonEditar }
                menuDocumentos
            }
        }
    }

    // MARK: - Columna izquierda (cambia por pestaña)

    @ViewBuilder
    private var tarjetaIzquierda: some View {
        switch subtab {
        case 1: tarjetaAportesCompleto
        case 2: tarjetaFamilia
        case 3: tarjetaConstancia
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
                // El parentesco lo mantiene Secretaría, que es quien lleva el
                // padrón. Aquí se consulta —sirve para la constancia anual
                // conjunta de un matrimonio— pero no se edita: un dato con dos
                // dueños acaba desactualizado en los dos sitios.
                Text(L.t("Los parentescos se editan en Secretaría · Miembros.",
                         "Family links are managed in Secretary · Members."))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
        }
    }

    /// Sustituye a la antigua pestaña "Asistencia", que era dato de Secretaría.
    /// Aquí la pregunta equivalente es la del tesorero: ¿esta persona sigue
    /// aportando con el ritmo que se le conoce?
    private var tarjetaConstancia: some View {
        Tarjeta {
            VStack(spacing: 0) {
                filaDato(L.t("Ritmo esperado", "Expected rhythm"), a.frecuencia.etiqueta)
                Divider()
                filaDato(L.t("Último aporte", "Last gift"), textoUltimoAporte)
                if let reciente = a.constanciaReciente() {
                    Divider()
                    filaDato(L.t("Últimos \(reciente.total) periodos", "Last \(reciente.total) periods"),
                             L.t("\(reciente.conAporte) con aporte", "\(reciente.conAporte) with a gift"))
                }
                if let atraso = a.periodosSinAportar, atraso > 0 {
                    Divider()
                    HStack {
                        Text(L.t("Sin aportar", "Lapsed"))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(a.frecuencia.periodos(atraso))
                            .font(.subheadline.weight(.semibold))
                            // El color solo cuando de verdad hay que mirarlo: si
                            // todo lo que se retrasa se pinta de naranja, deja
                            // de significar nada.
                            .foregroundStyle(a.atrasadoEnAportes ? Paleta.aviso : .primary)
                    }
                    .padding(.vertical, 10)
                }
                if a.frecuencia == .ocasional {
                    Divider()
                    Text(L.t("Aporta de forma ocasional, así que no se vigila su constancia.",
                             "Gives occasionally, so consistency isn't tracked."))
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
            }
        }
    }

    private var textoUltimoAporte: String {
        guard let fecha = a.ultimoAporte else {
            return L.t("Nunca ha aportado", "No gifts yet")
        }
        return Fechas.corta(fecha)
    }

    private var tarjetaAportesCompleto: some View {
        Tarjeta {
            VStack(spacing: 0) {
                ForEach(Array(a.aportes.enumerated()), id: \.element.id) { i, ap in
                    HStack {
                        Text(Fechas.corta(ap.fecha)).font(.subheadline).foregroundStyle(.secondary)
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
                Divider(); filaDato(L.t("Aporta", "Gives"), a.frecuencia.etiqueta)
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

    /// La barra en verde. En el año en curso es el mes en curso; en un año
    /// cerrado, diciembre. Antes era "la última de la serie", que con doce
    /// meses sería siempre diciembre aunque estemos en marzo.
    private var mesDestacado: String {
        let cal = Calendar.current
        let hoy = Date()
        let esAnioEnCurso = cal.component(.year, from: hoy) == anio
        let mes = esAnioEnCurso ? cal.component(.month, from: hoy) : 12
        guard let fecha = cal.date(from: DateComponents(year: anio, month: mes)) else { return "" }
        return L.mesCorto(fecha)
    }

    private var tarjetaAportes: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L.t("Total \(String(anio))", "Total \(String(anio))"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.fmt(a.total(anio: anio)))
                        .font(.title3.weight(.bold)).monospacedDigit()
                }
                Chart(a.serie(anio: anio)) { m in
                    BarMark(x: .value("Mes", m.mes), y: .value("Monto", m.monto))
                        .foregroundStyle(m.mes == mesDestacado ? Paleta.brand : Paleta.brandMuted)
                        .cornerRadius(3)
                }
                .chartYAxis(.hidden)
                .frame(height: 80)
                Text(a.promedio(anio: anio)).font(.caption).foregroundStyle(.secondary)

                // Los años que la persona tiene, no 2026/2025/2024 escritos a
                // mano: con esos, en 2027 el segmentado no ofrecería el año en
                // curso.
                Picker(L.t("Año", "Year"), selection: $anio) {
                    ForEach(a.aniosConAportes, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)

                ForEach(Array(a.aportesRecientes.enumerated()), id: \.element.id) { i, ap in
                    HStack {
                        Text("\(ap.concepto) · \(Fechas.corta(ap.fecha))").font(.subheadline)
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
