import SwiftUI

struct CartasView: View {
    @State private var vm = CartasViewModel()
    @State private var mostrarNueva = false
    @State private var mostrarPrevia = false
    @State private var mostrarFirmaAlert = false
    @State private var panelAbierto = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: Esp.columnaMaestra)
                        .background(Color(.systemBackground))
                    Divider()
                    detalleColumna
                }
            } else {
                listaColumna
                    .background(Color(.systemBackground))
                    .navigationDestination(isPresented: $panelAbierto) {
                        detalleColumna
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Cartas y traslados", "Letters & transfers"),
                       L.t("Plantillas, cartas emitidas y traslados", "Templates, issued letters & transfers"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNueva = true } label: {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text(L.t("Nuevo", "New")) }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
        }
        .task { await vm.cargar() }
        .sheet(isPresented: $mostrarNueva) {
            NuevaCartaSheet { datos in
                vm.nuevaCarta(datos)
            }
        }
        .sheet(isPresented: $mostrarPrevia) {
            VistaPreviaSheet(carta: vm.carta,
                             tipo: vm.plantillaSeleccionada,
                             cuerpo: cuerpoPlantilla)
        }
        .alert(firmaAlertTitulo, isPresented: $mostrarFirmaAlert) {
            if vm.carta.camposCompletos < vm.carta.camposTotales {
                Button(L.t("Aceptar", "OK"), role: .cancel) { }
            } else {
                Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
                Button(L.t("Firmar y emitir", "Sign & issue")) { vm.emitirCarta() }
            }
        } message: {
            Text(firmaAlertMensaje)
        }
    }

    private var firmaAlertTitulo: String {
        vm.carta.camposCompletos < vm.carta.camposTotales
            ? L.t("Campos incompletos", "Incomplete fields")
            : L.t("Firmar y enviar", "Sign & send")
    }
    private var firmaAlertMensaje: String {
        vm.carta.camposCompletos < vm.carta.camposTotales
            ? L.t("Faltan \(vm.carta.camposTotales - vm.carta.camposCompletos) campo(s) por completar antes de firmar.",
                  "\(vm.carta.camposTotales - vm.carta.camposCompletos) field(s) must be completed before signing.")
            : L.t("La carta quedará registrada y se añadirá al historial de emitidas.",
                  "The letter will be recorded and added to the issued history.")
    }

    // MARK: - Lista

    @ViewBuilder
    private var listaColumna: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaColumnaCore
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var listaColumnaCore: some View {
        List {
            Section {
                ForEach(TipoPlantilla.allCases) { tipo in
                    filaTipo(tipo)
                }
            } header: {
                Text(L.t("Plantillas", "Templates"))
                    .textCase(nil)
            }

            Section {
                ForEach(vm.emitidas) { carta in
                    filaEmitida(carta)
                }
            } header: {
                Text(L.t("Emitidas este mes", "Issued this month"))
                    .textCase(nil)
            }
        }
    }

    private func filaTipo(_ tipo: TipoPlantilla) -> some View {
        let sel = tipo == vm.plantillaSeleccionada
        return Button {
            vm.seleccionar(tipo)
            panelAbierto = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tipo.icono)
                    .font(.system(size: 15))
                    .foregroundStyle(sel ? Paleta.brand : Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
                    .background(
                        (sel ? Paleta.brandFill : Color(.tertiarySystemFill)),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(tipo.titulo)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(sel ? Paleta.brand : .primary)
                        .lineLimit(1)
                    Text(tipo.subtitulo)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .filaDeLista(seleccionada: sel, tarjeta: sizeClass != .regular)
    }

    private func filaEmitida(_ carta: CartaEmitida) -> some View {
        HStack(spacing: 12) {
            Avatar(iniciales: carta.iniciales, color: Paleta.brand, lado: 34)
            Text(carta.persona)
                .font(.subheadline).lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 9)
        .filaDeLista(seleccionada: false, tarjeta: sizeClass != .regular)
    }

    // MARK: - Detalle

    private var detalleColumna: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Progreso campos
                HStack(spacing: 10) {
                    Text(L.t("Campos: \(vm.carta.camposCompletos) de \(vm.carta.camposTotales) completos",
                             "Fields: \(vm.carta.camposCompletos) of \(vm.carta.camposTotales) complete"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button { mostrarPrevia = true } label: {
                        Text(L.t("Vista previa", "Preview"))
                            .font(.subheadline.weight(.medium)).lineLimit(1)
                            .foregroundStyle(Paleta.brand)
                            .padding(.horizontal, Esp.chip).padding(.vertical, 6)
                            .background(Paleta.brandFill, in: Capsule())
                    }
                    .fixedSize()
                    Button { mostrarFirmaAlert = true } label: {
                        Text(L.t("Firmar y enviar", "Sign & send"))
                            .font(.subheadline.weight(.semibold)).lineLimit(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Esp.chip).padding(.vertical, 6)
                            .background(Paleta.brand, in: Capsule())
                    }
                    .fixedSize()
                }

                // Preview de la carta
                Tarjeta {
                    VStack(alignment: .leading, spacing: 16) {
                        // Encabezado de la iglesia
                        VStack(alignment: .center, spacing: 3) {
                            Text("Iglesia Getsemaní")
                                .font(.subheadline.weight(.bold))
                            Text("Monterrey, N.L.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("20 de agosto de 2026")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        // Cuerpo
                        Text(cuerpoPlantilla)
                            .font(.subheadline)
                            .lineSpacing(5)

                        Divider()

                        // Firma
                        Text(vm.carta.firma)
                            .font(.subheadline.weight(.medium))
                    }
                }

                // Campos del formulario
                Tarjeta {
                    VStack(alignment: .leading, spacing: 0) {
                        TituloSeccion(texto: L.t("CAMPOS DE LA CARTA", "LETTER FIELDS"))
                            .padding(.bottom, 12)
                        campoFila(labelCampo1, $vm.carta.aportante)
                        Divider()
                        campoFila(labelCampo2, $vm.carta.iglesiaDestino)
                        Divider()
                        campoFila(labelCampo3, $vm.carta.miembroDesde)
                        Divider()
                        campoFila(L.t("Firma (pastor)", "Signature (pastor)"), $vm.carta.firma)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var cuerpoPlantilla: String {
        let destino = vm.carta.iglesiaDestino.isEmpty ? "___" : vm.carta.iglesiaDestino
        let persona = vm.carta.aportante.isEmpty ? "___" : vm.carta.aportante
        let desde   = vm.carta.miembroDesde.isEmpty ? "___" : vm.carta.miembroDesde

        if !vm.carta.cuerpoTexto.isEmpty { return vm.carta.cuerpoTexto }

        switch vm.plantillaSeleccionada {
        case .traslado:
            return L.t(
                "A la congregación hermana \(destino):\n\nPor medio de la presente hacemos constar que \(persona) ha sido miembro en plena comunión de esta congregación desde \(desde), habiendo mostrado conducta ejemplar y participación fiel.\n\nLo encomendamos a su cuidado pastoral.",
                "To the sister congregation \(destino):\n\nWe hereby certify that \(persona) has been a member in full communion of this congregation since \(desde), having shown exemplary conduct and faithful participation.\n\nWe commend them to your pastoral care."
            )
        case .certificadoMiembro:
            return L.t(
                "Certificamos que \(persona) es miembro activo de Iglesia Getsemaní y participa regularmente en nuestros servicios y actividades desde \(desde).",
                "We certify that \(persona) is an active member of Iglesia Getsemaní and regularly participates in our services and activities since \(desde)."
            )
        case .recomendacion, .buenaConducta:
            return L.t(
                "Por medio de la presente recomendamos a \(persona), quien ha sido miembro fiel de esta congregación desde \(desde), demostrando conducta cristiana ejemplar en todo momento.",
                "By means of this letter, we recommend \(persona), who has been a faithful member of this congregation since \(desde), demonstrating exemplary Christian conduct at all times."
            )
        case .presentacion:
            return L.t(
                "Tenemos el agrado de presentar a \(persona), miembro de nuestra congregación desde \(desde), a quien encomendamos fraternalmente ante \(destino).",
                "We have the pleasure of introducing \(persona), a member of our congregation since \(desde), whom we fraternally commend to \(destino)."
            )
        case .nombramiento:
            return L.t(
                "Por medio de la presente nombramos a \(persona) en el cargo de \(destino) a partir de la fecha, con las responsabilidades y atribuciones que el mismo conlleva.",
                "By means of this letter, we appoint \(persona) to the position of \(destino), effective from this date, with all responsibilities and authority that the position entails."
            )
        case .reconocimiento:
            return L.t(
                "En reconocimiento a los años de servicio fiel y dedicado, la Iglesia Getsemaní otorga la presente distinción a \(persona), cuya entrega ha sido una bendición para esta congregación.",
                "In recognition of faithful and dedicated years of service, Iglesia Getsemaní bestows this distinction upon \(persona), whose commitment has been a blessing to this congregation."
            )
        case .certificadoServicio:
            return L.t(
                "Certificamos que \(persona) ha prestado servicio activo en esta congregación desde \(desde), participando fielmente en las actividades y ministerios de la iglesia.",
                "We certify that \(persona) has rendered active service in this congregation since \(desde), faithfully participating in the activities and ministries of the church."
            )
        case .bautismo:
            return L.t(
                "Hacemos constar que \(persona) recibió el bautismo en agua el \(destino), siendo \(desde) el oficiant del sacramento.",
                "We certify that \(persona) received water baptism on \(destino), with \(desde) serving as officiant of the sacrament."
            )
        case .bienvenida:
            return L.t(
                "Con gran alegría damos la bienvenida a \(persona) como nuevo miembro de Iglesia Getsemaní. Procede de \(destino) y fue recibido el \(desde).",
                "With great joy we welcome \(persona) as a new member of Iglesia Getsemaní. They come from \(destino) and were received on \(desde)."
            )
        default:
            return L.t(
                "La presente carta es emitida en favor de \(persona), miembro de Iglesia Getsemaní, para los fines que estime convenientes.",
                "This letter is issued in favor of \(persona), member of Iglesia Getsemaní, for the purposes deemed appropriate."
            )
        }
    }

    private func campoFila(_ label: String, _ binding: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField(label, text: binding)
                .font(.subheadline)
                .textFieldStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Labels por tipo de plantilla

    private var labelCampo1: String {
        switch vm.plantillaSeleccionada {
        case .traslado, .recomendacion, .buenaConducta, .presentacion,
             .invitacion, .agradecimiento, .autorizacion, .solicitud,
             .nombramiento, .reconocimiento, .certificadoServicio,
             .certificadoMiembro, .personalizada:
            return L.t("Nombre del miembro", "Member name")
        case .bautismo: return L.t("Nombre del bautizado", "Baptized name")
        case .bienvenida: return L.t("Nombre del nuevo miembro", "New member name")
        }
    }
    private var labelCampo2: String {
        switch vm.plantillaSeleccionada {
        case .traslado:    return L.t("Iglesia destino", "Destination church")
        case .bautismo:    return L.t("Fecha de bautismo", "Baptism date")
        case .bienvenida:  return L.t("Iglesia de procedencia", "Previous church")
        default:           return L.t("Destinatario", "Recipient")
        }
    }
    private var labelCampo3: String {
        switch vm.plantillaSeleccionada {
        case .bautismo:  return L.t("Oficiante", "Officiant")
        case .bienvenida: return L.t("Fecha de recepción", "Reception date")
        default:          return L.t("Miembro desde", "Member since")
        }
    }
}

// MARK: - Sheet: Nueva carta

private struct NuevaCartaSheet: View {
    let onGuardar: (CartaEnEdicion) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var datos = CartaEnEdicion()
    @State private var templateSeleccionada: TipoPlantilla? = nil

    private let miembrosMock = [
        "María Hernández Ríos", "Pedro Salas Aguirre",
        "Ana Lucía Torres", "Familia Ruvalcaba",
        "Javier Medina Cruz",
    ]
    private let tiposDestinatario = [
        L.t("Miembro registrado", "Registered member"),
        L.t("Iglesia", "Church"),
        L.t("Pastor / ministro", "Pastor / minister"),
        L.t("Institución", "Institution"),
        L.t("Persona externa", "External person"),
        L.t("Personalizado", "Custom"),
    ]
    private let firmantesOpciones = [
        L.t("Pastor", "Pastor"),
        L.t("Secretaria", "Secretary"),
        L.t("Presidente", "President"),
        L.t("Tesorero", "Treasurer"),
        L.t("Otro rol", "Other role"),
    ]
    private let estadosOpciones = [
        L.t("Borrador", "Draft"),
        L.t("Listo para enviar", "Ready to send"),
        L.t("Enviado", "Sent"),
        L.t("Archivado", "Archived"),
    ]

    private var esDestinatarioMiembro: Bool {
        datos.tipoDestinatario == tiposDestinatario.first || datos.tipoDestinatario.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                seccionDocumento
                seccionDestinatario
                seccionContenido
                seccionFirmantes
                seccionEstado
            }
            .navigationTitle(L.t("Nueva carta", "New letter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar borrador", "Save draft")) {
                        onGuardar(datos)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Paleta.brand)
                }
            }
            .onAppear { aplicarAutoFill() }
            .onChange(of: datos.tipo) { _, _ in aplicarAutoFill() }
        }
        .hojaGrande()
    }

    // MARK: - Sections

    @ViewBuilder
    private var seccionDocumento: some View {
        Section(L.t("DOCUMENTO", "DOCUMENT")) {
            Picker(L.t("Tipo de carta", "Letter type"), selection: $datos.tipo) {
                ForEach(TipoPlantilla.allCases) { tipo in
                    Text(tipo.titulo).tag(tipo)
                }
            }
            HStack {
                Text(L.t("Número interno", "Internal number")).foregroundStyle(.secondary)
                Spacer()
                Text(L.t("Asignado al guardar", "Assigned when saved"))
                    .font(.caption).foregroundStyle(.tertiary)
            }
            DatePicker(L.t("Fecha de emisión", "Issue date"),
                       selection: $datos.fechaEmision, displayedComponents: .date)
            TextField(L.t("Lugar de emisión · opcional", "Place of issue · optional"),
                      text: $datos.lugarEmision)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var seccionDestinatario: some View {
        Section(L.t("DESTINATARIO", "RECIPIENT")) {
            Picker(L.t("Tipo de destinatario", "Recipient type"), selection: $datos.tipoDestinatario) {
                ForEach(tiposDestinatario, id: \.self) { Text($0).tag($0) }
            }
            if esDestinatarioMiembro {
                Picker(L.t("Miembro registrado", "Registered member"),
                       selection: $datos.miembroSeleccionado) {
                    Text(L.t("Elegir miembro...", "Choose a member...")).tag("")
                    ForEach(miembrosMock, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: datos.miembroSeleccionado) { _, _ in
                    datos.asunto = asuntoAutoFill()
                    if !datos.miembroSeleccionado.isEmpty {
                        datos.aportante = datos.miembroSeleccionado
                    }
                }
            } else {
                TextField(L.t("Nombre del destinatario", "Recipient name"),
                          text: $datos.miembroSeleccionado)
                    .autocorrectionDisabled()
            }
            TextField(L.t("Dirección del destinatario · opcional", "Recipient address · optional"),
                      text: $datos.direccionDestinatario)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var seccionContenido: some View {
        Section(L.t("CONTENIDO", "CONTENT")) {
            TextField(L.t("Asunto", "Subject"), text: $datos.asunto)
                .autocorrectionDisabled()
            TextField(L.t("Saludo · p. ej. A quien corresponda",
                          "Salutation · e.g. To whom it may concern"),
                      text: $datos.saludo)
                .autocorrectionDisabled()
            Picker(L.t("Usar plantilla", "Use template"),
                   selection: $templateSeleccionada) {
                Text(L.t("Elegir plantilla...", "Choose a template...")).tag(nil as TipoPlantilla?)
                ForEach(TipoPlantilla.allCases) { tipo in
                    Text(tipo.titulo).tag(tipo as TipoPlantilla?)
                }
            }
            .onChange(of: templateSeleccionada) { _, nuevo in
                if let t = nuevo { datos.cuerpoTexto = cuerpoTemplate(t) }
            }
            TextField(L.t("Cuerpo de la carta", "Letter body"),
                      text: $datos.cuerpoTexto, axis: .vertical)
                .lineLimit(6...14)
                .autocorrectionDisabled()
            TextField(L.t("Cierre · p. ej. Atentamente,", "Closing · e.g. Sincerely,"),
                      text: $datos.cierre)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var seccionFirmantes: some View {
        Section(L.t("FIRMANTES", "SIGNATORIES")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(firmantesOpciones, id: \.self) { firmante in
                        let sel = datos.firmantes.contains(firmante)
                        Button {
                            if sel { datos.firmantes.removeAll { $0 == firmante } }
                            else   { datos.firmantes.append(firmante) }
                        } label: {
                            Text(firmante)
                                .font(.subheadline)
                                .padding(.horizontal, Esp.chip).padding(.vertical, 7)
                                .background(sel ? Paleta.brand : Color(.tertiarySystemFill),
                                            in: Capsule())
                                .foregroundStyle(sel ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var seccionEstado: some View {
        Section(L.t("ESTADO Y ENTREGA", "STATUS AND DELIVERY")) {
            Picker(L.t("Estado", "Status"), selection: $datos.estadoCarta) {
                ForEach(estadosOpciones, id: \.self) { Text($0).tag($0) }
            }
            TextField(L.t("Notas internas · opcional", "Internal notes · optional"),
                      text: $datos.notasInternas, axis: .vertical)
                .lineLimit(2...4)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Auto-fill helpers

    private func asuntoAutoFill() -> String {
        let nombre = datos.miembroSeleccionado.isEmpty
            ? L.t("{{nombre_miembro}}", "{{member_name}}")
            : datos.miembroSeleccionado
        return "\(datos.tipo.titulo) — \(nombre)"
    }

    private func aplicarAutoFill() {
        if datos.asunto.isEmpty { datos.asunto = asuntoAutoFill() }
        if datos.saludo.isEmpty { datos.saludo = L.t("A quien corresponda:", "To whom it may concern:") }
        if datos.cierre.isEmpty { datos.cierre = L.t("Atentamente,", "Sincerely,") }
        if datos.estadoCarta.isEmpty { datos.estadoCarta = L.t("Borrador", "Draft") }
        if datos.tipoDestinatario.isEmpty { datos.tipoDestinatario = tiposDestinatario.first ?? "" }
        if datos.cuerpoTexto.isEmpty { datos.cuerpoTexto = cuerpoTemplate(datos.tipo) }
    }

    private func cuerpoTemplate(_ tipo: TipoPlantilla) -> String {
        let nombre = datos.miembroSeleccionado.isEmpty
            ? L.t("{{nombre_miembro}}", "{{member_name}}")
            : datos.miembroSeleccionado
        switch tipo {
        case .certificadoMiembro:
            return L.t(
                "Certificamos que \(nombre) es miembro activo de Iglesia Getsemaní y participa regularmente en nuestros servicios y actividades.",
                "We certify that \(nombre) is an active member of Iglesia Getsemaní and regularly participates in our services and activities."
            )
        case .recomendacion, .buenaConducta:
            return L.t(
                "Por medio de la presente recomendamos a \(nombre), quien ha sido miembro fiel de esta congregación y ha demostrado conducta cristiana ejemplar en todo momento.",
                "By means of this letter, we recommend \(nombre), who has been a faithful member of this congregation and has demonstrated exemplary Christian conduct at all times."
            )
        case .traslado:
            return L.t(
                "Por medio de la presente hacemos constar que \(nombre) ha sido miembro en plena comunión de esta congregación, habiendo mostrado conducta ejemplar y participación fiel en la vida de la iglesia.\n\nLo encomendamos a su cuidado pastoral.",
                "We hereby certify that \(nombre) has been a member in full communion of this congregation, having shown exemplary conduct and faithful participation in the life of the church.\n\nWe commend them to your pastoral care."
            )
        case .presentacion:
            return L.t(
                "Tenemos el agrado de presentar a \(nombre), miembro de nuestra congregación, a quien encomendamos fraternalmente.",
                "We have the pleasure of introducing \(nombre), a member of our congregation, whom we fraternally commend."
            )
        case .nombramiento:
            return L.t(
                "Por medio de la presente nombramos a \(nombre) en el cargo correspondiente a partir de la fecha indicada, con las responsabilidades y atribuciones que el mismo conlleva.",
                "By means of this letter, we appoint \(nombre) to the corresponding position from the indicated date, with all responsibilities and authority that the position entails."
            )
        case .reconocimiento:
            return L.t(
                "En reconocimiento a los años de servicio fiel y dedicado, la Iglesia Getsemaní otorga la presente distinción a \(nombre), cuya entrega ha sido una bendición para esta congregación.",
                "In recognition of faithful and dedicated years of service, Iglesia Getsemaní bestows this distinction upon \(nombre), whose commitment has been a blessing to this congregation."
            )
        case .certificadoServicio:
            return L.t(
                "Certificamos que \(nombre) ha prestado servicio activo en esta congregación, participando fielmente en las actividades y ministerios de la iglesia.",
                "We certify that \(nombre) has rendered active service in this congregation, faithfully participating in the activities and ministries of the church."
            )
        default:
            return ""
        }
    }
}

// MARK: - Sheet: Vista previa

private struct VistaPreviaSheet: View {
    let carta: CartaEnEdicion
    let tipo: TipoPlantilla
    let cuerpo: String

    @Environment(\.dismiss) private var dismiss

    private let hoy: String = {
        let f = DateFormatter()
        f.dateFormat = L.t("d 'de' MMMM 'de' yyyy", "MMMM d, yyyy")
        f.locale = L.locale
        return f.string(from: Date())
    }()

    private var completa: Bool { carta.camposCompletos == carta.camposTotales }

    var body: some View {
        NavigationStack {
            ScrollView {
                ZStack {
                    // Documento de la carta
                    VStack(alignment: .leading, spacing: 0) {

                        // Encabezado de la iglesia
                        VStack(alignment: .center, spacing: 4) {
                            Text("Iglesia Getsemaní")
                                .font(.headline.weight(.bold))
                            Text(L.t("Monterrey, Nuevo León · México", "Monterrey, Nuevo León · Mexico"))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(hoy).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)

                        Divider().padding(.bottom, 20)

                        // Tipo de carta
                        Text(tipo.titulo.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)

                        // Cuerpo
                        Text(cuerpo)
                            .font(.subheadline)
                            .lineSpacing(6)
                            .padding(.bottom, 32)

                        // Firma
                        VStack(alignment: .leading, spacing: 6) {
                            Rectangle().fill(Color(.separator)).frame(height: 0.5).frame(width: 160)
                            Text(carta.firma.isEmpty ? "___________________" : carta.firma)
                                .font(.subheadline.weight(.medium))
                            Text(L.t("Pastor", "Pastor"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(28)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 8, y: 3)

                    // Marca de agua BORRADOR
                    if !completa {
                        Text(L.t("BORRADOR", "DRAFT"))
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .rotationEffect(.degrees(-30))
                            .allowsHitTesting(false)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("Vista previa", "Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cerrar", "Close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Compartir — placeholder (requiere UIActivityViewController)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!completa)
                }
            }
        }
    }
}
