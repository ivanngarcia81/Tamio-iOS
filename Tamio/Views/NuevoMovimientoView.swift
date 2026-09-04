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
    /// Desglose libre dentro de la categoría ("Otro → Reembolso"). La columna
    /// existía en Supabase y se conservaba al editar, pero la hoja nunca la
    /// pedía: no había forma de capturarla.
    @State private var subcategoria: String
    @State private var fecha: Date
    @State private var metodo: String
    @State private var concepto: String
    // Sección APORTANTE (ingreso)
    /// Quién aporta. Antes era un `String` elegido de una lista de cinco
    /// nombres escritos en el código, que no existían en el padrón: no se podía
    /// capturar a nadie real, y el pie que prometía escribir el nombre de un
    /// visitante no tenía dónde escribirlo.
    @State private var aportante: SeleccionAportante
    @State private var nombreVisitante: String
    @State private var catalogo: [AportanteBreve] = []
    @State private var darConstanciaAnual: Bool
    // Sección BENEFICIARIO (gasto)
    @State private var pagadoA: String
    @State private var rfc: String
    // Sección MÁS
    @State private var repiteMensual: Bool
    @State private var notas: String
    @State private var marcadoPendiente: Bool
    @State private var incluidoEnCorte: Bool
    /// Ruta del comprobante dentro del bucket: es lo que se guarda. Antes aquí
    /// vivía el nombre del archivo elegido y nada más, así que el documento no
    /// salía del teléfono.
    @State private var comprobante: String?
    /// Nombre original, solo para enseñarlo mientras dura esta edición: la ruta
    /// guardada es un UUID y no dice nada a quien la lee.
    @State private var nombreComprobante: String?
    @State private var subiendoComprobante = false
    @State private var errorComprobante: String?
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
        _folioActual = State(initialValue: existente?.folio ?? folio)
        _tipo = State(initialValue: t)
        _importe = State(initialValue: existente.map { Self.aTexto($0.monto) } ?? "")
        // Un gasto nuevo arranca SIN categoría. Antes tomaba la primera del
        // catálogo, así que se guardaba como "Compensación" a quien no llegó a
        // tocar el campo, y un gasto mal clasificado no se nota hasta el
        // reporte anual. En un ingreso sí se preselecciona: es el diezmo del
        // domingo, cientos de capturas seguidas, y ahí obligar a un toque de
        // más por registro cuesta más de lo que evita.
        _categoria = State(initialValue: existente?.categoria
                           ?? (t == .ingreso ? (Catalogos.categorias(t).first ?? "") : ""))
        _subcategoria = State(initialValue: existente?.subcategoria ?? "")
        _fecha = State(initialValue: existente?.fecha ?? Date())
        _metodo = State(initialValue: existente?.metodo ?? (Catalogos.metodos.first ?? ""))
        _concepto = State(initialValue: existente?.nota ?? "")
        _aportante = State(initialValue: Self.seleccionInicial(existente))
        _nombreVisitante = State(initialValue: existente?.aportanteNombre ?? "")
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

    /// Las tres formas de responder "¿quién aporta?".
    private enum SeleccionAportante: Hashable {
        case sinAsignar
        /// Una ficha del padrón, por su `members.uid`.
        case miembro(String)
        /// Alguien sin ficha: un visitante, una aseguradora.
        case visitante
    }

    private static let sinAsignar = L.t("Sin asignar", "Unassigned")
    private static let etiquetaVisitante = L.t("Otra persona o entidad…",
                                               "Someone else…")

    /// Con qué opción se abre la hoja al editar un movimiento existente.
    private static func seleccionInicial(_ m: Movimiento?) -> SeleccionAportante {
        guard let m else { return .sinAsignar }
        if let uid = m.memberUid { return .miembro(uid) }
        if let nombre = m.aportanteNombre, !nombre.isEmpty { return .visitante }
        return .sinAsignar
    }

    /// El catálogo, más la ficha del movimiento que se edita si ya no está en
    /// él: un `Picker` no puede marcar una opción que no existe entre las suyas.
    private var opcionesAportante: [AportanteBreve] {
        guard case .miembro(let uid) = aportante,
              !catalogo.contains(where: { $0.id == uid }) else { return catalogo }
        return [AportanteBreve(id: uid, nombre: existente?.miembro ?? uid)] + catalogo
    }

    /// El nombre a mostrar y guardar, ya resuelto.
    private var nombreAportante: String? {
        switch aportante {
        case .sinAsignar: return nil
        case .miembro(let uid): return opcionesAportante.first { $0.id == uid }?.nombre
        case .visitante:
            let limpio = nombreVisitante.trimmingCharacters(in: .whitespaces)
            return limpio.isEmpty ? nil : limpio
        }
    }

    /// Catálogo compartido con la hoja de edición, más el valor vigente si no
    /// está en él: un `Picker` no puede marcar una selección que no exista
    /// entre sus opciones.
    private var categorias: [String] {
        Catalogos.conValorVigente(Catalogos.categorias(tipo), categoria)
    }
    private var metodos: [String] { Catalogos.conValorVigente(Catalogos.metodos, metodo) }

    private var guardadoHabilitado: Bool {
        !importe.isEmpty && !categoria.isEmpty && (tipo == .ingreso || !pagadoA.isEmpty)
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
                .onChange(of: tipo) { _, nuevo in
                    categoria = nuevo == .ingreso ? (Catalogos.categorias(nuevo).first ?? "") : ""
                }
                .onChange(of: aportante) { _, _ in
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
                switch resultado {
                case .success(let urls):
                    if let url = urls.first { Task { await adjuntar(url) } }
                case .failure(let error):
                    errorComprobante = error.localizedDescription
                }
            }
        }
        .hojaGrande()
        .presentationDragIndicator(.visible)
        .onAppear { if !editando { importeEnfocado = true } }
        .task {
            // Si falla, el selector se queda con "Sin asignar" y la opción de
            // escribir el nombre a mano, que sigue sirviendo sin red.
            catalogo = (try? await catalogoAportantes().activos()) ?? []
        }
    }

    // MARK: - Secciones

    @ViewBuilder
    private var seccionDetalle: some View {
        Section(header: Text(L.t("DETALLE", "DETAILS"))) {
            pickerCategoria
            TextField(L.t("Subcategoría · opcional", "Subcategory · optional"),
                      text: $subcategoria)
                .autocorrectionDisabled()
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
            Picker(L.t("Aportante", "Contributor"), selection: $aportante) {
                Text(Self.sinAsignar).tag(SeleccionAportante.sinAsignar)
                ForEach(opcionesAportante) { a in
                    Text(a.nombre).tag(SeleccionAportante.miembro(a.id))
                }
                Text(Self.etiquetaVisitante).tag(SeleccionAportante.visitante)
            }
            .pickerStyle(.menu)
            if case .visitante = aportante {
                TextField(L.t("Nombre", "Name"), text: $nombreVisitante)
                    .autocorrectionDisabled()
            }
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

    /// No hay aportante al que emitir constancia. Un visitante con nombre sí
    /// cuenta: la constancia se emite a quien dio el dinero, tenga ficha o no.
    private var sinAportante: Bool { nombreAportante == nil }

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
            // La opción vacía solo existe mientras no se ha elegido: una vez
            // hay categoría, dejar "Elegir categoría" en la lista invitaría a
            // volver a un estado que no se puede guardar.
            if categoria.isEmpty {
                Text(L.t("Elegir categoría", "Choose category"))
                    .foregroundStyle(.secondary)
                    .tag("")
            }
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
                Label(etiquetaComprobante,
                      systemImage: comprobante == nil ? "paperclip" : "doc.fill")
            }
            .disabled(subiendoComprobante)
            if let errorComprobante {
                Text(errorComprobante)
                    .font(.caption)
                    .foregroundStyle(Paleta.negativo)
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

    /// Los dos campos del aportante son excluyentes: o ficha del padrón, o
    /// nombre suelto. Para un gasto no aplica ninguno.
    private var memberUidElegido: String? {
        guard tipo == .ingreso, case .miembro(let uid) = aportante else { return nil }
        return uid
    }

    private var aportanteNombreElegido: String? {
        guard tipo == .ingreso, case .visitante = aportante else { return nil }
        return nombreAportante
    }

    private var subcategoriaLimpia: String? {
        let limpio = subcategoria.trimmingCharacters(in: .whitespaces)
        return limpio.isEmpty ? nil : limpio
    }

    private func armarMovimiento() -> Movimiento {
        // POSIX: `hora` se guarda y se ordena, no se elige por preferencia.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        let persona: String?
        if tipo == .ingreso {
            persona = nombreAportante
        } else {
            persona = pagadoA.isEmpty ? nil : pagadoA
        }
        return Movimiento(
            id: existente?.id ?? "",
            tipo: tipo,
            categoria: categoria,
            persona: persona,
            folio: folioActual,
            metodo: metodo,
            monto: Self.aCentavos(importe),
            hora: f.string(from: fecha),
            fecha: fecha,
            registradoPor: "Iván García",
            miembro: tipo == .ingreso ? nombreAportante : nil,
            categoriaCompleta: subcategoriaLimpia.map { "\(categoria) · \($0)" } ?? categoria,
            nota: concepto.isEmpty ? nil : concepto,
            sinDepositar: existente?.sinDepositar ?? (tipo == .ingreso),
            comprobante: comprobante,
            auditoria: existente?.auditoria ?? [
                AuditEntry(id: "1", titulo: L.t("Creado · Iván García", "Created · Iván García"),
                           // El aparato iba escrito como "iPad" pasara lo que
                           // pasara: en un iPhone el rastro de auditoría decía
                           // que el movimiento se capturó en otro dispositivo.
                           detalle: L.t("Ahora · \(Dispositivo.nombre)",
                                        "Just now · \(Dispositivo.nombre)"))
            ],
            pagadoA: tipo == .gasto ? (pagadoA.isEmpty ? nil : pagadoA) : nil,
            rfc: rfc.isEmpty ? nil : rfc,
            notasAuditoria: notas.isEmpty ? nil : notas,
            marcadoPendiente: tipo == .gasto && marcadoPendiente,
            incluidoEnCorte: incluidoEnCorte,
            darConstanciaAnual: tipo == .ingreso && darConstanciaAnual,
            repiteMensual: repiteMensual,
            // Se conservan los del movimiento original: la pantalla no los
            // edita, y perderlos aquí los borraría también en el servidor.
            // El `member_uid` solo se mantiene si el aportante sigue siendo el
            // mismo — todavía no se resuelve nombre → uid, y dejar el vínculo
            // viejo apuntando a otra persona sería peor que no tenerlo.
            memberUid: memberUidElegido,
            subcategoria: subcategoriaLimpia,
            aportanteNombre: aportanteNombreElegido
        )
    }

    private var etiquetaComprobante: String {
        if subiendoComprobante { return L.t("Subiendo…", "Uploading…") }
        if let nombreComprobante { return nombreComprobante }
        if comprobante != nil { return L.t("Comprobante adjunto", "Receipt attached") }
        return L.t("Adjuntar comprobante", "Attach receipt")
    }

    /// Sube el archivo antes de guardar el movimiento. Si la subida falla se
    /// dice y no se deja ninguna ruta: es preferible un movimiento sin
    /// comprobante que uno que dice tenerlo y apunta a un archivo inexistente
    /// —que es justo lo que pasaba antes con el nombre suelto.
    @MainActor
    private func adjuntar(_ url: URL) async {
        subiendoComprobante = true
        errorComprobante = nil
        do {
            comprobante = try await almacenComprobantes().subir(url)
            nombreComprobante = url.lastPathComponent
        } catch {
            comprobante = nil
            nombreComprobante = nil
            errorComprobante = L.t("No se pudo subir el comprobante: \(error.localizedDescription)",
                                   "Couldn't upload the receipt: \(error.localizedDescription)")
        }
        subiendoComprobante = false
    }

    private func guardar() {
        onGuardar(armarMovimiento())
        dismiss()
    }

    private func guardarYAgregar() {
        onGuardar(armarMovimiento())
        // Reinicia el formulario sin cerrar la hoja
        importe = ""
        categoria = tipo == .ingreso ? (Catalogos.categorias(tipo).first ?? "") : ""
        subcategoria = ""
        fecha = Date()
        metodo = "Efectivo"
        concepto = ""
        aportante = .sinAsignar
        nombreVisitante = ""
        darConstanciaAnual = false
        pagadoA = ""
        rfc = ""
        repiteMensual = false
        notas = ""
        marcadoPendiente = false
        incluidoEnCorte = true
        comprobante = nil
        nombreComprobante = nil
        errorComprobante = nil
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
