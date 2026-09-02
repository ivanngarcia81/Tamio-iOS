import SwiftUI

struct ActasView: View {
    @State private var vm = ActasViewModel()
    @State private var abierto: Acta?
    @State private var mostrarNueva = false
    @State private var mostrarFirmas = false
    @State private var mostrarCerrarAlert = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 640 {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: 320)
                        .background(.regularMaterial)
                    Divider()
                    if let acta = vm.seleccion {
                        detalle(acta)
                    } else {
                        ContentUnavailableView(L.t("Selecciona un acta", "Select minutes"),
                                               systemImage: "doc.text")
                    }
                }
            } else {
                listaColumna
                    .background(.regularMaterial)
                    .navigationDestination(item: $abierto) { acta in
                        detalle(acta)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Actas", "Minutes"), L.t("Acta 2026-08 en borrador", "Minutes 2026-08 in draft"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNueva = true } label: {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text(L.t("Nuevo", "New")) }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Paleta.brand, in: Capsule())
                }
            }
        }
        .task { await vm.cargar() }
        .sheet(isPresented: $mostrarNueva) {
            NuevaActaSheet(proximoId: vm.proximoId) { vm.agregarActa($0) }
        }
        .sheet(isPresented: $mostrarFirmas) {
            if let acta = vm.seleccion {
                FirmasSheet(acta: acta) { vm.firmarActa(id: acta.id) }
            }
        }
        .alert(L.t("Cerrar acta", "Close minutes"), isPresented: $mostrarCerrarAlert) {
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
            Button(L.t("Cerrar", "Close"), role: .destructive) {
                if let id = vm.seleccionId { vm.cerrarActa(id: id) }
            }
        } message: {
            Text(L.t("El acta quedará cerrada y no se podrá editar.",
                      "The minutes will be closed and cannot be edited."))
        }
    }

    // MARK: - Lista

    private var listaColumna: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                chipFiltro("2026", desplegable: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Divider()

            listaActas
        }
    }

    @ViewBuilder
    private var listaActas: some View {
        if sizeClass == .regular {
            listaActasCuerpo.listStyle(.plain)
        } else {
            listaActasCuerpo.listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var listaActasCuerpo: some View {
        let rowBG: Color = sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)
        List {
            ForEach(vm.lista) { acta in
                filaActa(acta)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(rowBG)
                    .contentShape(Rectangle())
                    .onTapGesture { abrir(acta) }
            }
        }
    }

    private func filaActa(_ acta: Acta) -> some View {
        let sel = acta.id == vm.seleccionId
        return HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 18))
                .foregroundStyle(sel ? Paleta.brand : Color(.secondaryLabel))
                .frame(width: 36, height: 36)
                .background(
                    (sel ? Paleta.brand.opacity(0.12) : Color(.tertiarySystemFill)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(acta.titulo).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(acta.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            Pill(texto: acta.estado.etiqueta, color: acta.estado.color)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(sel ? Paleta.brand.opacity(0.10) : (sizeClass == .regular ? Color.clear : Color(.secondarySystemGroupedBackground)))
        .overlay(alignment: .leading) { if sel { Rectangle().fill(Paleta.brand).frame(width: 3) } }
    }

    // MARK: - Detalle

    private func detalle(_ acta: Acta) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Barra de estado del acta
                HStack(spacing: 10) {
                    Pill(texto: acta.estado.etiqueta, color: acta.estado.color)
                    if acta.estado == .borrador {
                        Text(L.t("Guardado hace 2 minutos", "Saved 2 minutes ago"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if acta.estado == .borrador || acta.estado == .pendienteAprobacion {
                        Button { mostrarFirmas = true } label: {
                            Text(L.t("Recopilar firmas", "Collect signatures"))
                                .font(.subheadline.weight(.medium)).lineLimit(1)
                                .foregroundStyle(Paleta.brand)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Paleta.brand.opacity(0.1), in: Capsule())
                        }
                        .fixedSize()
                        Button { mostrarCerrarAlert = true } label: {
                            Text(L.t("Cerrar acta", "Close minutes"))
                                .font(.subheadline.weight(.semibold)).lineLimit(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Paleta.brand, in: Capsule())
                        }
                        .fixedSize()
                    }
                }

                // Documento
                Tarjeta {
                    VStack(alignment: .leading, spacing: 20) {
                        // Encabezado
                        VStack(alignment: .center, spacing: 4) {
                            Text(L.t("ACTA DE REUNIÓN DEL CONSEJO", "COUNCIL MEETING MINUTES"))
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text(L.t("Iglesia Getsemaní · Acta \(acta.folio)", "Iglesia Getsemaní · Minutes \(acta.folio)"))
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        // Cuerpo
                        Text(acta.cuerpo)
                            .font(.subheadline)
                            .lineSpacing(5)

                        // Acuerdos
                        if !acta.items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L.t("ACUERDOS", "AGREEMENTS"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(acta.items.enumerated()), id: \.element.id) { idx, item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(idx + 1).")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Paleta.brand)
                                            .frame(width: 20, alignment: .trailing)
                                        Text(item.texto)
                                            .font(.subheadline)
                                            .lineSpacing(4)
                                    }
                                }
                            }
                        }

                        Divider()

                        // Firmas
                        HStack(spacing: 0) {
                            firmaSlot(L.t("Pastor", "Pastor"))
                            firmaSlot(L.t("Secretaria", "Secretary"))
                            firmaSlot(L.t("Testigo", "Witness"))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func firmaSlot(_ titulo: String) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.horizontal, 12)
            Text(titulo)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func chipFiltro(_ texto: String, desplegable: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(texto)
            if desplegable { Image(systemName: "chevron.down").font(.caption2) }
        }
        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }

    private func abrir(_ acta: Acta) {
        vm.seleccionId = acta.id
        abierto = acta
    }
}

// MARK: - Sheet: Nueva acta

private struct NuevaActaSheet: View {
    let proximoId: Int
    let onGuardar: (Acta) -> Void
    @Environment(\.dismiss) private var dismiss

    // BASIC INFORMATION
    @State private var tipo = L.t("Consejo", "Council")
    @State private var tituloCustom = ""
    @State private var fecha = Date()
    @State private var lugar = ""
    @State private var tieneHoraInicio = false
    @State private var horaInicio = Date()
    @State private var tieneHoraCierre = false
    @State private var horaCierre = Date()
    @State private var presidido = ""
    @State private var secretariaActas = ""
    @State private var quorumCumplido = false
    @State private var esConfidencial = false

    // ATTENDANCE — (id, nombre) tuples to support duplicates safely
    @State private var presentes: [(id: UUID, nombre: String)] = []
    @State private var nuevoPresenteNombre = ""
    @State private var ausentes: [(id: UUID, nombre: String)] = []
    @State private var nuevoAusenteNombre = ""
    @State private var invitados: [(id: UUID, nombre: String)] = []
    @State private var nuevoInvitadoNombre = ""

    // MINUTES CONTENT
    @State private var puntosAgenda = ""
    @State private var resumenAsuntos = ""

    // MOTIONS AND PROPOSALS
    @State private var mociones: [(id: UUID, texto: String)] = []
    @State private var nuevaMocion = ""

    // AGREEMENTS AND DECISIONS
    @State private var acuerdoItems: [(id: UUID, texto: String)] = []
    @State private var nuevoAcuerdo = ""

    // APPROVAL
    @State private var estadoForm = EstadoActa.borrador

    private let tipos = [
        L.t("Consejo", "Council"),
        L.t("Directiva", "Board"),
        L.t("Disciplina", "Discipline"),
        L.t("Misiones", "Missions"),
        L.t("Especial", "Special"),
    ]

    private var guardadoHabilitado: Bool { !tituloCustom.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                seccionInfoBasica
                seccionAsistencia
                seccionContenido
                seccionMociones
                seccionAcuerdos
                seccionAprobacion
            }
            .navigationTitle(L.t("Nueva acta", "New minutes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar acta", "Save minutes")) {
                        onGuardar(construir())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(guardadoHabilitado ? Paleta.brand : Color.secondary)
                    .disabled(!guardadoHabilitado)
                }
            }
        }
        .hojaGrande()
    }

    // MARK: - Sections

    @ViewBuilder
    private var seccionInfoBasica: some View {
        Section(L.t("INFORMACIÓN BÁSICA", "BASIC INFORMATION")) {
            Picker(L.t("Tipo de reunión", "Meeting type"), selection: $tipo) {
                ForEach(tipos, id: \.self) { Text($0).tag($0) }
            }
            TextField(L.t("Título", "Title"), text: $tituloCustom)
                .autocorrectionDisabled()
            DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
            TextField(L.t("Ubicación · opcional", "Location · optional"), text: $lugar)
                .autocorrectionDisabled()
            Toggle(L.t("Hora de inicio", "Start time"), isOn: $tieneHoraInicio)
            if tieneHoraInicio {
                DatePicker(L.t("Inicio", "Start"), selection: $horaInicio,
                           displayedComponents: .hourAndMinute)
            }
            Toggle(L.t("Hora de cierre", "Closing time"), isOn: $tieneHoraCierre)
            if tieneHoraCierre {
                DatePicker(L.t("Cierre", "Close"), selection: $horaCierre,
                           displayedComponents: .hourAndMinute)
            }
            TextField(L.t("Presidido por", "Presided by"), text: $presidido)
                .autocorrectionDisabled()
            TextField(L.t("Secretaria de actas", "Recording secretary"), text: $secretariaActas)
                .autocorrectionDisabled()
            Toggle(L.t("Quórum cumplido", "Required quorum was met"), isOn: $quorumCumplido)
            Toggle(L.t("Acta confidencial", "Confidential · restricted access"), isOn: $esConfidencial)
        }
    }

    @ViewBuilder
    private var seccionAsistencia: some View {
        Section(L.t("ASISTENCIA", "ATTENDANCE")) {
            grupoAsistentes(
                etiqueta: L.t("Miembros presentes", "Members present"),
                lista: $presentes, campo: $nuevoPresenteNombre
            )
            grupoAsistentes(
                etiqueta: L.t("Ausentes", "Absent"),
                lista: $ausentes, campo: $nuevoAusenteNombre
            )
            grupoAsistentes(
                etiqueta: L.t("Invitados", "Guests"),
                lista: $invitados, campo: $nuevoInvitadoNombre
            )
        }
    }

    @ViewBuilder
    private var seccionContenido: some View {
        Section(L.t("CONTENIDO DEL ACTA", "MINUTES CONTENT")) {
            TextField(L.t("Puntos de agenda · uno por línea", "Agenda items · one item per line"),
                      text: $puntosAgenda, axis: .vertical)
                .lineLimit(3...6)
                .autocorrectionDisabled()
            TextField(L.t("Resumen de asuntos tratados",
                          "Summary of matters discussed"),
                      text: $resumenAsuntos, axis: .vertical)
                .lineLimit(3...6)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var seccionMociones: some View {
        Section(L.t("MOCIONES Y PROPUESTAS", "MOTIONS AND PROPOSALS")) {
            ForEach(mociones, id: \.id) { mocion in
                HStack(spacing: 10) {
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    Text(mocion.texto).font(.subheadline)
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        mociones.removeAll { $0.id == mocion.id }
                    } label: { Label(L.t("Borrar", "Delete"), systemImage: "trash") }
                }
            }
            HStack {
                TextField(L.t("+ Agregar moción", "+ Add motion"), text: $nuevaMocion)
                    .autocorrectionDisabled()
                if !nuevaMocion.isEmpty {
                    Button(L.t("Agregar", "Add")) {
                        mociones.append((UUID(), nuevaMocion))
                        nuevaMocion = ""
                    }
                    .foregroundStyle(Paleta.brand)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var seccionAcuerdos: some View {
        Section(L.t("ACUERDOS Y DECISIONES", "AGREEMENTS AND DECISIONS")) {
            ForEach(Array(acuerdoItems.enumerated()), id: \.element.id) { idx, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1).")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Paleta.brand)
                        .frame(width: 20, alignment: .trailing)
                    Text(item.texto).font(.subheadline)
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        acuerdoItems.removeAll { $0.id == item.id }
                    } label: { Label(L.t("Borrar", "Delete"), systemImage: "trash") }
                }
            }
            HStack {
                TextField(L.t("+ Agregar acuerdo", "+ Add agreement"), text: $nuevoAcuerdo)
                    .autocorrectionDisabled()
                if !nuevoAcuerdo.isEmpty {
                    Button(L.t("Agregar", "Add")) {
                        acuerdoItems.append((UUID(), nuevoAcuerdo))
                        nuevoAcuerdo = ""
                    }
                    .foregroundStyle(Paleta.brand)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var seccionAprobacion: some View {
        Section {
            Picker(L.t("Estado", "Status"), selection: $estadoForm) {
                Text(L.t("Borrador", "Draft")).tag(EstadoActa.borrador)
                Text(L.t("Pendiente de aprobación", "Pending approval")).tag(EstadoActa.pendienteAprobacion)
                Text(L.t("Aprobada", "Approved")).tag(EstadoActa.aprobada)
                Text(L.t("Enmendada", "Amended")).tag(EstadoActa.enmendada)
                Text(L.t("Archivada", "Archived")).tag(EstadoActa.archivada)
            }
        } header: {
            Text(L.t("APROBACIÓN", "APPROVAL"))
        } footer: {
            Text(L.t(
                "El PDF incluye espacio de firma para la secretaria y el directivo (pastor, presidente o moderador).",
                "The PDF includes signature space for the secretary and the director (pastor, president, or moderator)."
            ))
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func grupoAsistentes(
        etiqueta: String,
        lista: Binding<[(id: UUID, nombre: String)]>,
        campo: Binding<String>
    ) -> some View {
        ForEach(lista.wrappedValue, id: \.id) { persona in
            HStack {
                Text(persona.nombre).font(.subheadline)
                Spacer()
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    lista.wrappedValue.removeAll { $0.id == persona.id }
                } label: { Label(L.t("Borrar", "Delete"), systemImage: "trash") }
            }
        }
        HStack {
            TextField(etiqueta + L.t(" · agregar", " · add a name"), text: campo)
                .autocorrectionDisabled()
            if !campo.wrappedValue.isEmpty {
                Button(L.t("Agregar", "Add")) {
                    lista.wrappedValue.append((UUID(), campo.wrappedValue))
                    campo.wrappedValue = ""
                }
                .foregroundStyle(Paleta.brand)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Build Acta

    private func fmtHora(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func construir() -> Acta {
        let cal = Calendar.current
        let año = cal.component(.year, from: fecha)
        let mes = cal.component(.month, from: fecha)
        let folio = String(format: "%04d-%02d", año, mes)

        let fmtLargo = DateFormatter()
        fmtLargo.dateFormat = "d 'de' MMMM 'de' yyyy"
        fmtLargo.locale = Locale(identifier: "es_MX")
        let fechaLarga = fmtLargo.string(from: fecha)

        let fmtCorto = DateFormatter()
        fmtCorto.dateFormat = "d 'de' MMMM"
        fmtCorto.locale = Locale(identifier: "es_MX")
        let fechaCorta = fmtCorto.string(from: fecha)

        let horaTxt = tieneHoraInicio
            ? L.t(", a las \(fmtHora(horaInicio)) horas", ", at \(fmtHora(horaInicio))")
            : ""
        let cierreTxt = tieneHoraCierre
            ? L.t(" Cierre: \(fmtHora(horaCierre)) h.", " Close: \(fmtHora(horaCierre)).")
            : ""
        let pres = presentes.isEmpty
            ? L.t("los miembros convocados", "the members convened")
            : presentes.map(\.nombre).joined(separator: ", ")

        var partes: [String] = []
        partes.append(L.t(
            """
            En \(fechaLarga)\(horaTxt), se reunió el \(tipo.lowercased()) de la Iglesia Getsemaní.\(cierreTxt)
            Presidió: \(presidido.isEmpty ? "—" : presidido). Secretaria de actas: \(secretariaActas.isEmpty ? "—" : secretariaActas).
            Miembros presentes: \(pres).
            """,
            """
            On \(fechaLarga)\(horaTxt), the \(tipo.lowercased()) of Iglesia Getsemaní convened.\(cierreTxt)
            Presided by: \(presidido.isEmpty ? "—" : presidido). Recording secretary: \(secretariaActas.isEmpty ? "—" : secretariaActas).
            Members present: \(pres).
            """
        ))
        if !ausentes.isEmpty {
            partes.append(L.t(
                "Ausentes: \(ausentes.map(\.nombre).joined(separator: ", ")).",
                "Absent: \(ausentes.map(\.nombre).joined(separator: ", "))."
            ))
        }
        if !invitados.isEmpty {
            partes.append(L.t(
                "Invitados: \(invitados.map(\.nombre).joined(separator: ", ")).",
                "Guests: \(invitados.map(\.nombre).joined(separator: ", "))."
            ))
        }
        if !puntosAgenda.isEmpty {
            partes.append(L.t("Orden del día:\n\(puntosAgenda)", "Agenda:\n\(puntosAgenda)"))
        }
        if !resumenAsuntos.isEmpty {
            partes.append(resumenAsuntos)
        }
        if !mociones.isEmpty {
            let lista = mociones.map(\.texto).enumerated()
                .map { "· \($0.element)" }.joined(separator: "\n")
            partes.append(L.t("Mociones y propuestas:\n\(lista)", "Motions and proposals:\n\(lista)"))
        }

        let items = acuerdoItems.enumerated()
            .map { AcuerdoActa(id: $0.offset + 1, texto: $0.element.texto) }

        return Acta(
            id: proximoId,
            folio: folio,
            tipo: tipo,
            fecha: fechaCorta,
            acuerdos: items.count,
            estado: estadoForm,
            cuerpo: partes.joined(separator: "\n\n"),
            items: items,
            tituloPersonalizado: tituloCustom.isEmpty ? nil : tituloCustom
        )
    }
}

// MARK: - Sheet: Recopilar firmas

private struct FirmasSheet: View {
    let acta: Acta
    let onFirmado: () -> Void

    @State private var firmados: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    private let firmantes = [
        L.t("Pastor", "Pastor"),
        L.t("Secretaria", "Secretary"),
        L.t("Testigo", "Witness"),
    ]

    private var todasFirmadas: Bool { firmantes.allSatisfy { firmados.contains($0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Encabezado del acta
                    Tarjeta {
                        VStack(alignment: .center, spacing: 4) {
                            Text(acta.titulo)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                            Text(acta.fecha)
                                .font(.caption).foregroundStyle(.secondary)
                            Pill(texto: "\(firmados.count) \(L.t("de", "of")) \(firmantes.count) \(L.t("firmas", "signatures"))",
                                 color: todasFirmadas ? Paleta.brand : Paleta.aviso)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Slots de firma
                    Tarjeta {
                        VStack(alignment: .leading, spacing: 0) {
                            TituloSeccion(texto: L.t("FIRMAS REQUERIDAS", "REQUIRED SIGNATURES"))
                                .padding(.bottom, 10)
                            ForEach(firmantes, id: \.self) { firmante in
                                firmaFila(firmante)
                                if firmante != firmantes.last { Divider() }
                            }
                        }
                    }

                    // Botón de confirmar
                    if todasFirmadas {
                        Button {
                            onFirmado()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text(L.t("Confirmar firmas · cambiar a Firmada",
                                          "Confirm signatures · mark as Signed"))
                            }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Paleta.brand, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(L.t("Toca cada nombre al recibir la firma física. Al confirmar, el acta cambiará a 'Firmada'.",
                              "Tap each name as you receive the physical signature. On confirm, the minutes will change to 'Signed'."))
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("Recopilar firmas", "Collect signatures"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cerrar", "Close")) { dismiss() }
                }
            }
        }
    }

    private func firmaFila(_ nombre: String) -> some View {
        let firmado = firmados.contains(nombre)
        return Button {
            if firmado { firmados.remove(nombre) } else { firmados.insert(nombre) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: firmado ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(firmado ? Paleta.brand : Color(.tertiaryLabel))
                VStack(alignment: .leading, spacing: 2) {
                    Text(nombre).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Text(firmado
                         ? L.t("Firmado · hoy", "Signed · today")
                         : L.t("Pendiente de firma", "Pending signature"))
                        .font(.caption)
                        .foregroundStyle(firmado ? Paleta.brand : .secondary)
                }
                Spacer()
                if firmado {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Paleta.brand)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
