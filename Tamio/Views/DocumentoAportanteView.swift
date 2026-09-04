import SwiftUI

/// Genera los dos documentos de un aportante: el reporte de aportes de un
/// periodo y la constancia anual.
///
/// Son dos y no uno a propósito. El reporte es informativo; la constancia es un
/// comprobante fiscal que necesita la identificación de la iglesia y las
/// firmas. Meterlos en el mismo papel obligaría a que un recibo de "gracias por
/// tu ofrenda de esta semana" llevara firmas que no le corresponden.
struct DocumentoAportanteView: View {
    enum Tipo: String, Identifiable {
        case reporte, constancia
        var id: String { rawValue }
    }

    let aportante: Aportante
    let tipo: Tipo

    @Environment(\.dismiss) private var dismiss
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    @State private var periodo: PeriodoReporte = .mes
    @State private var desde = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var hasta = Date()
    @State private var anio = Calendar.current.component(.year, from: Date())
    @State private var pdfURL: URL?
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compacto: Bool { sizeClass == .compact }

    private var iglesia: ConfiguracionIglesia { cfg.config }

    private var aportesDelPeriodo: [Aporte] {
        let rango = periodo.intervalo(desde: desde, hasta: hasta)
        return aportante.aportes
            .filter { rango.contains($0.fecha) }
            .sorted { $0.fecha > $1.fecha }
    }

    private var aportesDelAnio: [Aporte] {
        aportante.aportes
            .filter { Calendar.current.component(.year, from: $0.fecha) == anio }
            .sorted { $0.fecha > $1.fecha }
    }

    /// Años en los que hay algo que certificar. Ofrecer años vacíos solo lleva
    /// a generar constancias en blanco.
    private var aniosConAportes: [Int] {
        let cal = Calendar.current
        let años = Set(aportante.aportes.map { cal.component(.year, from: $0.fecha) })
        return años.sorted(by: >)
    }

    private var periodoLegible: String {
        let rango = periodo.intervalo(desde: desde, hasta: hasta)
        return "\(Fechas.corta(rango.lowerBound)) — \(Fechas.corta(rango.upperBound))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    controles
                    if tipo == .constancia, !iglesia.listaParaConstancia {
                        avisoDatosFaltantes
                    }
                    previa
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                }
                .padding(Esp.panel)
            }
            .background(Color(.systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: .all)
            // En el teléfono el título deja su sitio al selector: la hoja ya
            // dice qué documento es en su propio membrete, y el periodo —que
            // es lo que decide qué sale en el papel— no tenía dónde vivir sin
            // ocupar una tira entera sobre la previa.
            .navigationTitle(compacto ? "" : (tipo == .reporte
                             ? L.t("Reporte de aportes", "Giving report")
                             : L.t("Constancia anual", "Annual statement")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // "Cerrar" se queda sin estilo: el sistema ya le pone su
                    // cápsula de glass, y forzarle `.buttonStyle(.glass)` la
                    // ensancha lo justo para que se salga por el borde — se
                    // leía "os" en vez de "Close".
                    Button(L.t("Cerrar", "Close")) { dismiss() }
                }
                if compacto {
                    ToolbarItem(placement: .title) { menuPeriodoDoc }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let pdfURL {
                        // `.glass` con el verde de marca, no el relleno
                        // prominente que el sistema pone por omisión en una
                        // acción de confirmación: un símbolo blanco sobre
                        // Paleta.brand da ~2.4:1 en oscuro.
                        ShareLink(item: pdfURL) {
                            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.glass)
                        .tint(Paleta.brand)
                    }
                }
            }
        }
        // **Los `onChange` viven aquí y no junto a los controles.** Colgaban
        // del `VStack` del segmentado, y al mudarse el selector a la barra ese
        // VStack deja de dibujarse en el teléfono: cambiar de año habría
        // cambiado la previa y NO el PDF que se comparte, que es la única
        // diferencia que nadie ve hasta que el archivo llega al contador.
        .onChange(of: periodo) { _, _ in regenerar() }
        .onChange(of: anio) { _, _ in regenerar() }
        .onChange(of: desde) { _, _ in regenerar() }
        .onChange(of: hasta) { _, _ in regenerar() }
        .task { await cfg.cargar(); regenerar() }
    }

    // MARK: - Controles

    /// **El selector, en la barra del teléfono.** Era un segmentado a lo ancho
    /// sobre la previa: con una sola opción —una constancia de un año— ocupaba
    /// la fila entera para no ofrecer ninguna alternativa, y con cuatro
    /// ("Semana · Mes · Año · Rango") se cortaba por los dos lados cuando la
    /// hoja estiraba la columna. Como menú dice el periodo elegido y ofrece el
    /// resto sin gastar ancho.
    @ViewBuilder
    private var menuPeriodoDoc: some View {
        if tipo == .reporte {
            Menu {
                ForEach(PeriodoReporte.allCases) { p in
                    Button { periodo = p } label: {
                        if p == periodo { Label(p.etiqueta, systemImage: "checkmark") }
                        else { Text(p.etiqueta) }
                    }
                }
            } label: { capsulaSelector(periodo.etiqueta) }
        } else if !aniosConAportes.isEmpty {
            Menu {
                ForEach(aniosConAportes, id: \.self) { a in
                    Button { anio = a } label: {
                        if a == anio { Label(String(a), systemImage: "checkmark") }
                        else { Text(String(a)) }
                    }
                }
            } label: { capsulaSelector(String(anio)) }
        }
    }

    private func capsulaSelector(_ texto: String) -> some View {
        HStack(spacing: 4) {
            Text(texto).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    @ViewBuilder
    private var controles: some View {
        if compacto {
            // Ya viven en la barra; el rango sigue aquí porque son dos
            // calendarios y no caben en una cápsula.
            if tipo == .reporte, periodo == .rango {
                DatePicker(L.t("Desde", "From"), selection: $desde, displayedComponents: .date)
                DatePicker(L.t("Hasta", "To"), selection: $hasta, displayedComponents: .date)
            }
        } else if tipo == .reporte {
            VStack(spacing: 12) {
                Picker(L.t("Periodo", "Period"), selection: $periodo) {
                    ForEach(PeriodoReporte.allCases) { Text($0.etiqueta).tag($0) }
                }
                .pickerStyle(.segmented)
                if periodo == .rango {
                    DatePicker(L.t("Desde", "From"), selection: $desde, displayedComponents: .date)
                    DatePicker(L.t("Hasta", "To"), selection: $hasta, displayedComponents: .date)
                }
            }
        } else if !aniosConAportes.isEmpty {
            Picker(L.t("Año", "Year"), selection: $anio) {
                ForEach(aniosConAportes, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Se avisa **antes** de generar, no después: descubrir que falta el ID
    /// fiscal en la oficina del contador es tarde.
    private var avisoDatosFaltantes: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Paleta.aviso)
            VStack(alignment: .leading, spacing: 3) {
                Text(L.t("Faltan datos de la iglesia", "Missing church details"))
                    .font(.subheadline.weight(.semibold))
                Text(L.t("Sin \(iglesia.faltaParaConstancia.joined(separator: ", ")) esta constancia no sirve como comprobante. Se completan en Ajustes · Iglesia.",
                         "Without \(iglesia.faltaParaConstancia.joined(separator: ", ")) this statement won't work as a receipt. Fill them in Settings · Church."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(Esp.tarjeta)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.avisoFill, in: RoundedRectangle(cornerRadius: 12))
    }

    private var previa: some View {
        HojaCartaEscalada {
            switch tipo {
            case .reporte:
                ReporteAportesHojaPDF(aportante: aportante, aportes: aportesDelPeriodo,
                                      periodoLegible: periodoLegible, iglesia: iglesia)
            case .constancia:
                ConstanciaHojaPDF(aportante: aportante, aportes: aportesDelAnio,
                                  anio: anio, iglesia: iglesia)
            }
        }
    }

    // MARK: - PDF

    /// El archivo se rehace con cada cambio: si no, se comparte el PDF del
    /// periodo anterior mientras la pantalla enseña otro.
    @MainActor
    private func regenerar() {
        let limpio = aportante.nombre.replacingOccurrences(of: " ", with: "-")
        switch tipo {
        case .reporte:
            pdfURL = PDFExport.render(
                ReporteAportesHojaPDF(aportante: aportante, aportes: aportesDelPeriodo,
                                      periodoLegible: periodoLegible, iglesia: iglesia),
                nombre: "Aportes-\(limpio)")
        case .constancia:
            pdfURL = PDFExport.render(
                ConstanciaHojaPDF(aportante: aportante, aportes: aportesDelAnio,
                                  anio: anio, iglesia: iglesia),
                nombre: "Constancia-\(String(anio))-\(limpio)")
        }
    }
}
