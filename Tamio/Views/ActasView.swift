import SwiftUI

struct ActasView: View {
    @State private var vm = ActasViewModel()
    @State private var abierto: Acta?
    @State private var mostrarNueva = false
    @State private var mostrarFirmas = false
    @State private var mostrarCerrarAlert = false
    /// El acta que se está viendo como documento. Se guarda el acta y no un
    /// `Bool` porque en iPad la hoja se abre sobre la seleccionada y en el
    /// teléfono sobre la que está en pantalla.
    @State private var actaEnPDF: Acta?
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Mismo criterio que Membresía, Ingresos, Aportantes y Depósitos: en el
    /// teléfono el título va en la barra —si no, queda detrás del cristal— y
    /// en iPad se queda grande.
    private var compacto: Bool { sizeClass == .compact }
    /// El membrete sale de Ajustes, no de esta vista. El nombre iba escrito a
    /// mano aquí y en otros nueve sitios, con DOS valores distintos —"Iglesia
    /// Getsemaní" y "Iglesia Nueva Vida"—, así que los documentos y la sidebar
    /// nombraban iglesias diferentes.
    @State private var cfg = ConfiguracionIglesiaViewModel.compartido
    private var iglesia: ConfiguracionIglesia { cfg.config }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= Esp.anchoMaestroDetalle {
                HStack(spacing: 0) {
                    listaColumna
                        .frame(width: Esp.columnaMaestra)
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
                    .navigationDestination(item: $abierto) { acta in
                        detalle(acta)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
        }
        .encabezadoNav(L.t("Actas", "Minutes"), vm.subtitulo)
        // **El título grande no cabe con una barra de cristal.** Con
        // `safeAreaBar` el contenido corre por debajo de la barra, y el título
        // grande vive justo en esa franja: quedaba detrás del desvanecido,
        // gris sobre negro y sin poder leerse. Lo vio Iván en una captura,
        // rodeado con el dedo: *"el título se esconde detrás del frosted
        // glass"*.
        //
        // El arreglo NO es acortar el cristal —mide lo que mide su contenido,
        // y encogerlo apretaría los controles—: es subir el título a la barra
        // de navegación, que es lo que ya hacían Membresía, Ingresos,
        // Aportantes y Depósitos en el teléfono, y por eso a ellas no les
        // pasaba. El subtítulo se conserva: `navigationSubtitle` sigue
        // saliendo bajo el título en modo `.inline`.
        //
        // En iPad se queda `.large`: allí la barra es de la pantalla entera y
        // el título no compite con ninguna cápsula.
        .navigationBarTitleDisplayMode(compacto ? .inline : .large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrarNueva = true } label: {
                    Label(L.t("Nuevo", "New"), systemImage: "plus")
                }
                .buttonStyle(.glass)
                .tint(Paleta.brand)
            }
        }
        .task { await vm.cargar(); await cfg.cargar() }
        .sincronizable { await vm.cargar() }
        .sheet(isPresented: $mostrarNueva) {
            NuevaActaSheet(proximoId: vm.proximoId,
                           proximoNumeroProvisional: vm.lista.count + 1) { acta in
                Task { await vm.agregarActa(acta) }
            }
        }
        .sheet(item: $actaEnPDF) { acta in
            DocumentoPDFSheet(titulo: L.t("Vista previa PDF", "PDF preview"),
                              // El folio, que es como se cita un acta y como se
                              // ordenan en una carpeta.
                              nombreArchivo: "Acta-\(acta.folio)") {
                ActaHojaPDF(acta: acta, iglesia: iglesia)
            }
        }
        .sheet(isPresented: $mostrarFirmas) {
            if let acta = vm.seleccion {
                FirmasSheet(acta: acta) { firmas in
                    Task { await vm.firmarActa(id: acta.id, firmas: firmas) }
                }
            }
        }
        .alert(L.t("Cerrar acta", "Close minutes"), isPresented: $mostrarCerrarAlert) {
            Button(L.t("Cancelar", "Cancel"), role: .cancel) { }
            Button(L.t("Cerrar", "Close"), role: .destructive) {
                if let id = vm.seleccionId { Task { await vm.cerrarActa(id: id) } }
            }
        } message: {
            Text(L.t("El acta quedará cerrada y no se podrá editar.",
                      "The minutes will be closed and cannot be edited."))
        }
    }

    // MARK: - Lista

    /// **Capas, no hermanos.** El chip del año, un `Divider` y la lista iban
    /// apilados en un `VStack`, así que la lista no corría por debajo de nada:
    /// al hacer scroll el contenido chocaba contra el divisor y se CORTABA a
    /// media fila, con la banda del título vacía encima. Lo dijo Iván mirando
    /// Actas: *"cuando se hace scroll se corta"*.
    ///
    /// Con `safeAreaBar` la lista ocupa todo y pasa por debajo del chip, que es
    /// lo que le da al glass algo que refractar y al desvanecido algo que
    /// borrar. El `Divider` sobra: con el degradado, una línea vuelve a leerse
    /// como pared. Y el título grande ya colapsa como debe, porque ahora la
    /// lista ES el scroll de la pantalla y no un scroll dentro de otra cosa.
    private var listaColumna: some View {
        listaActas
            .scrollEdgeEffectStyle(.soft, for: .all)
            .safeAreaBar(edge: .top, spacing: 0) { cabeceraActas }
            .colchonInferior()
    }

    private var cabeceraActas: some View {
        HStack(spacing: 8) {
            chipFiltro("2026", desplegable: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Esp.pantalla)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var listaActas: some View {
        // Las dos ramas en `.plain`: el margen lo pone `filaDeLista`.
        listaActasCuerpo
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Paleta.sueloLista(tarjeta: sizeClass != .regular))
    }

    @ViewBuilder
    private var listaActasCuerpo: some View {
        List {
            ForEach(vm.lista) { acta in
                filaActa(acta)
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
                    (sel ? Paleta.brandFill : Color(.tertiarySystemFill)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(acta.titulo).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(acta.subtitulo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            Pill(texto: acta.estado.etiqueta, color: acta.estado.color)
        }
        .padding(.vertical, 11)
        .filaDeLista(seleccionada: sel, tarjeta: sizeClass != .regular)
    }

    // MARK: - Detalle

    @ViewBuilder
    private func estadoActa(_ acta: Acta) -> some View {
        Pill(texto: acta.estado.etiqueta, color: acta.estado.color)
        // La hora a la que se guardó de verdad, no "hace 2 minutos" para
        // todas. Si el acta no se ha guardado nunca no se dice nada: un hueco
        // es más honesto que una hora inventada.
        if acta.estado == .borrador, let guardado = acta.guardadoLegible {
            Text(guardado)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func accionesActa(_ acta: Acta) -> some View {
        // **Fuera del `if`, a propósito.** El resto de acciones son de un acta
        // que aún se trabaja; el documento es justo al revés — el acta que más
        // falta hace entregar es la aprobada—, y hasta hoy no había forma
        // ninguna de sacar un acta del teléfono.
        Button { actaEnPDF = acta } label: {
            Label(L.t("PDF", "PDF"), systemImage: "doc.text")
                .font(.subheadline.weight(.medium)).lineLimit(1)
        }
        .buttonStyle(.glass).tint(Color.secondary).fixedSize()

        if acta.estado == .borrador || acta.estado == .pendienteAprobacion {
            // Pintados a mano: el primario iba con `Paleta.brand` de fondo y el
            // texto en blanco, los mismos ~2.4:1 en oscuro que se quitaron del
            // resto de la app. Ahora son botones de verdad, con el estilo que
            // ya llevan los demás: glass con el verde de marca el que actúa,
            // glass en gris el otro.
            Button { mostrarFirmas = true } label: {
                Text(L.t("Recopilar firmas", "Collect signatures"))
                    .font(.subheadline.weight(.medium)).lineLimit(1)
            }
            .buttonStyle(.glass).tint(Color.secondary).fixedSize()
            Button { mostrarCerrarAlert = true } label: {
                Text(L.t("Cerrar acta", "Close minutes"))
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .buttonStyle(.glass).tint(Paleta.brand).fixedSize()
        }
    }

    private func detalle(_ acta: Acta) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // **Barra de estado: una fila si cabe, dos si no.**
                // Era un `HStack` con la etiqueta, el "guardado hace…" y dos
                // botones de ancho fijo. En el teléfono los botones no ceden y
                // el texto se quedaba sin ancho: se dibujaba EN VERTICAL, una
                // letra por línea, ocupando media pantalla. Se veía ya antes,
                // y empeoró al pasar los botones a glass, que son más anchos
                // que las cápsulas pintadas a mano.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { estadoActa(acta); Spacer(); accionesActa(acta) }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) { estadoActa(acta); Spacer() }
                        HStack(spacing: 10) { accionesActa(acta); Spacer() }
                    }
                }

                // Documento
                Tarjeta {
                    VStack(alignment: .leading, spacing: 20) {
                        // Encabezado
                        VStack(alignment: .center, spacing: 4) {
                            LogoMembrete(alto: 52)
                            // **El encabezado dice de qué acta es.** Estaba
                            // escrito "ACTA DE REUNIÓN DEL CONSEJO" para
                            // todas, así que un acta administrativa o una
                            // asamblea se encabezaban como consejo.
                            Text(L.t("ACTA · \(acta.tipo.etiqueta.uppercased())",
                                     "MINUTES · \(acta.tipo.etiqueta.uppercased())"))
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text(L.t("\(iglesia.nombre) · Acta \(acta.folio)",
                                     "\(iglesia.nombre) · Minutes \(acta.folio)"))
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
            .padding(Esp.panel)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func firmaSlot(_ titulo: String) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.horizontal, Esp.pantalla)
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
        .padding(.horizontal, Esp.chip).padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }

    private func abrir(_ acta: Acta) {
        vm.seleccionId = acta.id
        abierto = acta
    }
}

// MARK: - Sheet: Nueva acta

private struct NuevaActaSheet: View {
    let proximoId: String
    /// Cuántas actas hay ya, para que dos borradores sin subir no lleven el
    /// mismo provisional. No es el folio: el folio lo da el servidor.
    let proximoNumeroProvisional: Int
    let onGuardar: (Acta) -> Void
    @Environment(\.dismiss) private var dismiss

    // BASIC INFORMATION
    @State private var tipo = TipoActa.lideres
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

    // **El catálogo del web, no cinco opciones propias.** Eran Consejo,
    // Directiva, Disciplina, Misiones y Especial, escritas aquí y guardadas
    // como texto traducido: tres de las cinco no existen en `TIPOS_ACTIVIDAD`
    // del web, y las otras dos cambiaban de valor al cambiar de idioma.
    private let tipos = TipoActa.allCases

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
        .hojaFormulario()
    }

    // MARK: - Sections

    @ViewBuilder
    private var seccionInfoBasica: some View {
        Section(L.t("INFORMACIÓN BÁSICA", "BASIC INFORMATION")) {
            Picker(L.t("Tipo de reunión", "Meeting type"), selection: $tipo) {
                ForEach(tipos, id: \.self) { Text($0.etiqueta).tag($0) }
            }
            FilaCampo(L.t("Título", "Title"), $tituloCustom)
                .autocorrectionDisabled()
            DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
            FilaCampo(L.t("Ubicación · opcional", "Location · optional"), $lugar)
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
            FilaCampo(L.t("Presidido por", "Presided by"), $presidido)
                .autocorrectionDisabled()
            FilaCampo(L.t("Secretaria de actas", "Recording secretary"), $secretariaActas)
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
                // Rótulo para VoiceOver: el marcador se va en cuanto hay texto.
                .accessibilityLabel(L.t("Resumen de asuntos tratados", "Summary of matters discussed"))
                // Rótulo para VoiceOver: el marcador se va en cuanto hay texto.
                .accessibilityLabel(L.t("Puntos de agenda · uno por línea", "Agenda items · one item per line"))
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
                    .tint(.red)   // el tint del TabView tapa el rojo del rol
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
                    .tint(.red)
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
                .tint(.red)
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
        // POSIX: una hora en 24 h no es una preferencia regional, y con un
        // calendario no gregoriano el dispositivo devolvería otros dígitos.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// **Devuelve los campos, ya no la prosa.** Aquí se armaba a mano el texto
    /// del acta —quince campos fundidos en un `cuerpo`— y se devolvía eso,
    /// así que lo recogido en el formulario existía en pantalla y en ninguna
    /// parte más. La redacción vive ahora en `Acta.cuerpo`, que la calcula de
    /// los campos: corregir el lugar cambia el texto, que antes no pasaba.
    private func construir() -> Acta {
        // **El folio es PROVISIONAL.** Era "2026-08" —año y mes—, que no es una
        // serie: dos actas del mismo mes nacían con el mismo folio por diseño,
        // y encima en otra serie que la del web (`ACTA-2026-001`). El bueno lo
        // entrega el contador del servidor al subir; hasta entonces se enseña
        // marcado con "P-", como el de un movimiento sin subir, y por eso no se
        // imprime.
        let folio = FolioCarta.provisional(seq: proximoNumeroProvisional)

        let items = acuerdoItems.enumerated()
            .map { AcuerdoActa(id: $0.offset + 1, texto: $0.element.texto) }

        return Acta(
            id: proximoId,
            folio: folio,
            tipo: tipo,
            fecha: Fechas.claveDia(fecha),
            estado: estadoForm,
            items: items,
            tituloPersonalizado: tituloCustom.isEmpty ? nil : tituloCustom,
            lugar: lugar.trimmingCharacters(in: .whitespaces),
            horaInicio: tieneHoraInicio ? fmtHora(horaInicio) : nil,
            horaCierre: tieneHoraCierre ? fmtHora(horaCierre) : nil,
            preside: presidido.trimmingCharacters(in: .whitespaces),
            secretario: secretariaActas.trimmingCharacters(in: .whitespaces),
            presentes: presentes.map(\.nombre),
            ausentes: ausentes.map(\.nombre),
            invitados: invitados.map(\.nombre),
            quorum: quorumCumplido,
            agenda: puntosAgenda.trimmingCharacters(in: .whitespaces),
            resumen: resumenAsuntos.trimmingCharacters(in: .whitespaces),
            mociones: mociones.map(\.texto),
            confidencial: esConfidencial
        )
    }
}

// MARK: - Sheet: Recopilar firmas

private struct FirmasSheet: View {
    let acta: Acta
    /// **Devuelve QUIÉN firmó, no solo que se firmó.** Antes era `() -> Void`:
    /// la hoja juntaba los nombres en un `Set` que moría con ella y el acta
    /// pasaba a "Firmada" sin que constara nadie.
    let onFirmado: ([FirmaActa]) -> Void

    @State private var firmados: Set<RolFirmaActa> = []
    @Environment(\.dismiss) private var dismiss

    /// Los tres renglones que se imprimen, en su orden. Se llamaban "Pastor",
    /// "Secretaria" y "Testigo"; los dos primeros son en realidad quien
    /// preside y quien levanta el acta, que es como los nombra el acta misma
    /// —y el web— y no siempre es el pastor.
    private let firmantes = RolFirmaActa.allCases

    private var todasFirmadas: Bool { firmantes.allSatisfy { firmados.contains($0) } }

    /// Quién ocupa cada renglón, si el acta lo dice. Un renglón con nombre se
    /// firma con más criterio que uno que dice "Preside".
    private func nombreDe(_ rol: RolFirmaActa) -> String? {
        switch rol {
        case .preside:    return acta.preside.isEmpty ? nil : acta.preside
        case .secretario: return acta.secretario.isEmpty ? nil : acta.secretario
        case .testigo:    return nil
        }
    }

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
                            Text(acta.fechaLegible)
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
                            ForEach(firmantes) { firmante in
                                firmaFila(firmante)
                                if firmante != firmantes.last { Divider() }
                            }
                        }
                    }

                    // Botón de confirmar
                    if todasFirmadas {
                        Button {
                            // El día en que se firma se guarda por firma, como
                            // en el web: un acta puede recoger la tercera firma
                            // semanas después de las dos primeras.
                            let hoy = Fechas.claveDia()
                            onFirmado(firmantes.map { rol in
                                let yaEstaba = acta.firmas.first { $0.rol == rol }
                                return FirmaActa(rol: rol, firmado: true,
                                                 fecha: yaEstaba?.fecha ?? hoy)
                            })
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
                .padding(Esp.panel)
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
        // **Lo ya firmado viene marcado.** Sin esto, recoger la tercera firma
        // obligaba a volver a marcar las dos que ya estaban.
        .task { firmados = Set(acta.firmas.filter(\.firmado).map(\.rol)) }
        .hojaFormulario()
    }

    private func firmaFila(_ rol: RolFirmaActa) -> some View {
        let firmado = firmados.contains(rol)
        let nombre = nombreDe(rol) ?? rol.etiqueta
        return Button {
            if firmado { firmados.remove(rol) } else { firmados.insert(rol) }
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
