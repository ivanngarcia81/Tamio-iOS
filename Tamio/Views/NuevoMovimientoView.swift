import SwiftUI
import UniformTypeIdentifiers

struct NuevoMovimientoView: View {
    @Environment(\.dismiss) private var dismiss

    private let existente: Movimiento?
    private let onGuardar: (Movimiento) -> Void
    private let onNuevoFolio: (() async -> String)?

    @State private var folioActual: String
    @State private var tipo: TipoMovimiento
    @State private var importe: String
    @State private var categoria: String
    @State private var fecha: Date
    @State private var metodo: String
    @State private var concepto: String
    // Sección APORTANTE (ingreso)
    @State private var miembro: String
    @State private var darConstanciaAnual: Bool
    // Sección BENEFICIARIO (gasto)
    @State private var pagadoA: String
    @State private var rfc: String
    // Sección MÁS
    @State private var repiteMensual: Bool
    @State private var notas: String
    @State private var marcadoPendiente: Bool
    @State private var incluidoEnCorte: Bool
    @State private var comprobante: String?
    @State private var mostrarImportador = false
    /// El importe es el primer campo: se enfoca al presentar la hoja para que
    /// salga el teclado y se lea como editable y no como texto gris estático.
    @FocusState private var importeEnfocado: Bool

    init(tipo: TipoMovimiento, folio: String, existente: Movimiento?,
         onGuardar: @escaping (Movimiento) -> Void,
         onNuevoFolio: (() async -> String)? = nil) {
        self.existente = existente
        self.onGuardar = onGuardar
        self.onNuevoFolio = onNuevoFolio
        let t = existente?.tipo ?? tipo
        let cats = Catalogos.categorias(t)
        _folioActual = State(initialValue: existente?.folio ?? folio)
        _tipo = State(initialValue: t)
        _importe = State(initialValue: existente.map { Self.aTexto($0.monto) } ?? "")
        _categoria = State(initialValue: existente?.categoria ?? (cats.first ?? ""))
        _fecha = State(initialValue: existente?.fecha ?? Date())
        _metodo = State(initialValue: existente?.metodo ?? (Catalogos.metodos.first ?? ""))
        _concepto = State(initialValue: existente?.nota ?? "")
        _miembro = State(initialValue: existente?.miembro ?? Self.sinAsignar)
        _darConstanciaAnual = State(initialValue: existente?.darConstanciaAnual ?? false)
        _pagadoA = State(initialValue: existente?.pagadoA ?? "")
        _rfc = State(initialValue: existente?.rfc ?? "")
        _repiteMensual = State(initialValue: existente?.repiteMensual ?? false)
        _notas = State(initialValue: existente?.notasAuditoria ?? "")
        _marcadoPendiente = State(initialValue: existente?.marcadoPendiente ?? false)
        _incluidoEnCorte = State(initialValue: existente?.incluidoEnCorte ?? true)
        _comprobante = State(initialValue: existente?.comprobante)
    }

    private var editando: Bool { existente != nil }

    /// Centinela de "sin aportante". Estaba escrito como literal español en
    /// tres sitios, y salía sin traducir en el Picker.
    private static let sinAsignar = L.t("Sin asignar", "Unassigned")

    /// Catálogo compartido con la hoja de edición, más el valor vigente si no
    /// está en él: un `Picker` no puede marcar una selección que no exista
    /// entre sus opciones.
    private var categorias: [String] {
        Catalogos.conValorVigente(Catalogos.categorias(tipo), categoria)
    }
    private var metodos: [String] { Catalogos.conValorVigente(Catalogos.metodos, metodo) }
    private var miembros: [String] { [Self.sinAsignar, "María Hernández Ríos",
                                      "Pedro Salas Aguirre", "Ana Lucía Torres",
                                      "Familia Ruvalcaba"] }

    private var guardadoHabilitado: Bool {
        !importe.isEmpty && (tipo == .ingreso || !pagadoA.isEmpty)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L.t("Tipo", "Type"), selection: $tipo) {
                    Text(L.t("Ingreso", "Income")).tag(TipoMovimiento.ingreso)
                    Text(L.t("Gasto", "Expense")).tag(TipoMovimiento.gasto)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.top, 8)
                .disabled(editando)
                .onChange(of: tipo) { _, _ in
                    categoria = categorias.first ?? categoria
                }
                .onChange(of: miembro) { _, _ in
                    if sinAportante { darConstanciaAnual = false }
                }

                importeView.padding(.vertical, 12)

                Form {
                    seccionDetalle
                    if tipo == .ingreso { seccionAportante }
                    if tipo == .gasto   { seccionBeneficiario }
                    seccionMas
                    if !editando { seccionGuardarOtro }
                }
            }
            .navigationTitle(tituloPantalla)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) { guardar() }
                        .fontWeight(.semibold)
                        .tint(Paleta.brand)
                        .disabled(!guardadoHabilitado)
                }
            }
            .fileImporter(isPresented: $mostrarImportador,
                          allowedContentTypes: [.image, .pdf],
                          allowsMultipleSelection: false) { resultado in
                if case .success(let urls) = resultado, let url = urls.first {
                    comprobante = url.lastPathComponent
                }
            }
        }
        .hojaGrande()
        .presentationDragIndicator(.visible)
        .onAppear { if !editando { importeEnfocado = true } }
    }

    // MARK: - Secciones

    @ViewBuilder
    private var seccionDetalle: some View {
        Section(header: Text(L.t("DETALLE", "DETAILS"))) {
            pickerCategoria
            // Para gastos el concepto es requerido y va justo tras la categoría
            if tipo == .gasto {
                TextField(L.t("Concepto", "Concept"), text: $concepto)
                    .autocorrectionDisabled()
            }
            DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
            Picker(L.t("Método de pago", "Payment method"), selection: $metodo) {
                ForEach(metodos, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            // Para ingresos el concepto es opcional y va al final de la sección
            if tipo == .ingreso {
                TextField(L.t("Concepto · opcional", "Concept · optional"), text: $concepto)
                    .autocorrectionDisabled()
            }
        }
    }

    @ViewBuilder
    private var seccionAportante: some View {
        // El pie sobre visitantes describe la fila Aportante, no el toggle, así
        // que va pegado a ella: por eso son dos secciones y no una.
        Section {
            Picker(L.t("Aportante", "Contributor"), selection: $miembro) {
                ForEach(miembros, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L.t("APORTANTE", "CONTRIBUTOR"))
        } footer: {
            Text(L.t("Si es un visitante, escribe su nombre: se guarda sin ficha en el padrón.",
                     "For a visitor, enter their name: saved without a profile in the directory."))
        }
        Section {
            Toggle(L.t("Dar constancia anual", "Annual receipt"), isOn: $darConstanciaAnual)
                .disabled(sinAportante)
        } footer: {
            if sinAportante {
                Text(L.t("Elige un aportante para poder emitir la constancia.",
                         "Pick a contributor to issue the receipt."))
            }
        }
    }

    /// No hay aportante al que emitir constancia.
    private var sinAportante: Bool { miembro == Self.sinAsignar }

    /// El catálogo de gastos pasa de una decena, así que ahí el Picker empuja
    /// una pantalla con lista y palomitas —el mismo patrón que la hoja de
    /// Filtros— en vez de un menú de diecinueve renglones; los ingresos son
    /// seis y caben en el menú. La regla la decide el catálogo, así que la
    /// hoja de edición hace exactamente lo mismo.
    @ViewBuilder
    private var pickerCategoria: some View {
        // Dos ramas y no un ternario en `.pickerStyle`: los estilos son tipos
        // distintos y un ternario entre ellos no compila.
        if categorias.count > 10 {
            pickerCategoriaBase.pickerStyle(.navigationLink)
        } else {
            pickerCategoriaBase.pickerStyle(.menu)
        }
    }

    private var pickerCategoriaBase: some View {
        Picker(tipo == .ingreso ? L.t("Tipo de ingreso", "Income type")
                                : L.t("Categoría", "Category"),
               selection: $categoria) {
            ForEach(categorias, id: \.self) { Text($0).tag($0) }
        }
    }

    @ViewBuilder
    private var seccionBeneficiario: some View {
        Section(header: Text(L.t("BENEFICIARIO", "PAYEE"))) {
            TextField(L.t("Pagado a", "Paid to"), text: $pagadoA)
                .autocorrectionDisabled()
            TextField(L.t("RFC · opcional", "Tax ID · optional"), text: $rfc)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
        }
    }

    @ViewBuilder
    private var seccionMas: some View {
        Section {
            Toggle(L.t("Se repite cada mes", "Repeats monthly"), isOn: $repiteMensual)
            Button { mostrarImportador = true } label: {
                Label(comprobante ?? L.t("Adjuntar comprobante", "Attach receipt"),
                      systemImage: comprobante == nil ? "paperclip" : "doc.fill")
            }
            DatePicker(L.t("Hora", "Time"), selection: $fecha, displayedComponents: .hourAndMinute)
            TextField(L.t("Notas · opcional", "Notes · optional"), text: $notas, axis: .vertical)
                .lineLimit(2...4)
                .autocorrectionDisabled()
            if tipo == .gasto {
                Toggle(L.t("Marcar como pendiente", "Flag for review"), isOn: $marcadoPendiente)
            }
            Toggle(L.t("Incluir en el corte del domingo", "Include in Sunday deposit"),
                   isOn: $incluidoEnCorte)
        } header: {
            Text(L.t("MÁS", "MORE"))
        } footer: {
            Text(L.t("Todos los campos de esta sección son opcionales.",
                     "All fields in this section are optional."))
        }
    }

    @ViewBuilder
    private var seccionGuardarOtro: some View {
        Section {
            Button(action: guardarYAgregar) {
                Text(L.t("Guardar y agregar otro", "Save and add another"))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(guardadoHabilitado ? Paleta.brand : Color.secondary)
            }
            .disabled(!guardadoHabilitado)
        }
    }

    // MARK: - Campo de monto

    private var importeView: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $importe)
                    .keyboardType(.decimalPad)
                    .focused($importeEnfocado)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .fixedSize()
            }
            Text("MXN")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var tituloPantalla: String {
        if editando { return L.t("Editar movimiento", "Edit entry") }
        return tipo == .ingreso ? L.t("Nuevo ingreso", "New income") : L.t("Nuevo gasto", "New expense")
    }

    private func armarMovimiento() -> Movimiento {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let persona: String?
        if tipo == .ingreso {
            persona = miembro != Self.sinAsignar ? miembro : nil
        } else {
            persona = pagadoA.isEmpty ? nil : pagadoA
        }
        return Movimiento(
            id: existente?.id ?? 0,
            tipo: tipo,
            categoria: categoria,
            persona: persona,
            folio: folioActual,
            metodo: metodo,
            monto: Self.aCentavos(importe),
            hora: f.string(from: fecha),
            fecha: fecha,
            registradoPor: "Iván García",
            miembro: tipo == .ingreso && !sinAportante ? miembro : nil,
            categoriaCompleta: categoria,
            nota: concepto.isEmpty ? nil : concepto,
            sinDepositar: existente?.sinDepositar ?? (tipo == .ingreso),
            comprobante: comprobante,
            auditoria: existente?.auditoria ?? [
                AuditEntry(id: 1, titulo: L.t("Creado · Iván García", "Created · Iván García"),
                           detalle: L.t("Ahora · iPad", "Just now · iPad"))
            ],
            pagadoA: tipo == .gasto ? (pagadoA.isEmpty ? nil : pagadoA) : nil,
            rfc: rfc.isEmpty ? nil : rfc,
            notasAuditoria: notas.isEmpty ? nil : notas,
            marcadoPendiente: tipo == .gasto && marcadoPendiente,
            incluidoEnCorte: incluidoEnCorte,
            darConstanciaAnual: tipo == .ingreso && darConstanciaAnual,
            repiteMensual: repiteMensual
        )
    }

    private func guardar() {
        onGuardar(armarMovimiento())
        dismiss()
    }

    private func guardarYAgregar() {
        onGuardar(armarMovimiento())
        // Reinicia el formulario sin cerrar la hoja
        importe = ""
        categoria = categorias.first ?? ""
        fecha = Date()
        metodo = "Efectivo"
        concepto = ""
        miembro = Self.sinAsignar
        darConstanciaAnual = false
        pagadoA = ""
        rfc = ""
        repiteMensual = false
        notas = ""
        marcadoPendiente = false
        incluidoEnCorte = true
        comprobante = nil
        // Obtiene el siguiente folio del repositorio para evitar duplicados; si no
        // hay callback (modo standalone), incrementa localmente como fallback.
        if let onNuevoFolio {
            Task { folioActual = await onNuevoFolio() }
        } else if let n = Int(folioActual) {
            folioActual = String(n + 1)
        }
    }

    static func aTexto(_ c: Centavos) -> String {
        String(format: "%.2f", Double(c) / 100)
    }

    static func aCentavos(_ s: String) -> Centavos {
        let limpio = s.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Int(((Double(limpio) ?? 0) * 100).rounded())
    }
}
