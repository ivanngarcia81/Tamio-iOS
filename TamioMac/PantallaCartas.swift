import SwiftUI

/// **Cartas y traslados, rediseñada para el Mac.**
///
/// Esta NO va a tabla, y es la diferencia con el Registro y con Servicios.
/// Una carta no es una fila: es un documento que sale por la puerta con el
/// membrete de la iglesia, y lo que alguien necesita antes de emitirla es
/// VERLA. La maqueta ya tiene ese patrón montado para Reportes —lista a la
/// izquierda, la hoja a la derecha— y es exactamente el que pide esto.
///
/// En el iPad esa hoja no cabe al lado, así que hay que entrar a otra pantalla
/// para verla. Aquí la lista y el papel conviven: se baja por las cartas con
/// las flechas y el documento se redibuja al lado.
struct PantallaCartas: View {
    let vm: CartasViewModel
    @Binding var seleccion: String?

    /// El testigo del alta lo dispara el ⌥⌘N del menú Archivo, que no alcanza
    /// el estado privado de una vista — ver `EstadoVentana.pidiendoAlta`.
    @Environment(EstadoVentana.self) private var estado

    /// **Las tres del handoff.** Emitidas es la que se abre: es lo que se
    /// consulta a diario; las plantillas se miran cuando se va a redactar y los
    /// traslados cuando alguien pregunta por un expediente.
    enum SubCartas: String, CaseIterable, Identifiable {
        case emitidas, plantillas, traslados
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .emitidas:   return L.t("Emitidas", "Issued")
            case .plantillas: return L.t("Plantillas", "Templates")
            case .traslados:  return L.t("Traslados", "Transfers")
            }
        }
    }
    @State private var sub: SubCartas = .emitidas
    @State private var plantillaElegida: String?

    /// Los traslados que enseña la tercera pestaña. Los pone quien tiene el
    /// padrón —`VentanaPrincipal`—, porque un traslado es un expediente de la
    /// ficha de alguien y no una carta.
    let traslados: [TrasladoEnLista]

    /// Una fila de la tabla de traslados, ya en palabras. El modelo guarda el
    /// estado en clave (`enviado`, `completado`, `cancelado`) y aquí se lee.
    struct TrasladoEnLista: Identifiable {
        let id: String
        let folio: String
        let persona: String
        let destino: String
        let estado: String
        var enCurso: Bool { estado != "completado" && estado != "cancelado" }
        var estadoLegible: String {
            switch estado {
            case "completado": return L.t("Completado", "Completed")
            case "cancelado":  return L.t("Cancelado", "Cancelled")
            case "enviado":    return L.t("Enviado", "Sent")
            default:           return estado
            }
        }
    }

    private var elegida: CartaEmitida? {
        vm.emitidas.first { $0.id == seleccion }
    }

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            Divider()
            switch sub {
            case .emitidas:
                HStack(spacing: 0) {
                    lista
                        .frame(width: 268)
                    Divider()
                    hoja
                        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                }
            case .plantillas:
                HStack(spacing: 0) {
                    listaDePlantillas
                        .frame(width: 268)
                    Divider()
                    panelDePlantilla
                        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                }
            case .traslados:
                tablaDeTraslados
            }
        }
        .sheet(isPresented: Binding(
            get: { estado.pidiendoAlta },
            set: { estado.pidiendoAlta = $0 }
        )) {
            NuevaCarta(vm: vm) { datos in
                Task {
                    // Guardar y LUEGO sincronizar, esperando: lanzarlos a la
                    // vez deja la vuelta saliendo antes de que la operación
                    // esté en la cola. Medido en Membresía.
                    await vm.guardarBorrador(datos)
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
    }

    // MARK: - La cabecera

    private var cabecera: some View {
        HStack(spacing: 12) {
            Picker("", selection: $sub) {
                ForEach(SubCartas.allCases) { Text($0.titulo).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer(minLength: 0)
            Text(cuenta)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button { estado.pidiendoAlta = true } label: {
                Label(L.t("Nueva carta", "New letter"), systemImage: "plus")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var cuenta: String {
        switch sub {
        case .emitidas:
            let borradores = vm.emitidas.filter { $0.estado == "borrador" }.count
            return borradores == 0
                ? L.t("\(vm.emitidas.count) cartas", "\(vm.emitidas.count) letters")
                : L.t("\(vm.emitidas.count) cartas · \(borradores) en borrador",
                      "\(vm.emitidas.count) letters · \(borradores) in draft")
        case .plantillas:
            return L.t("\(vm.plantillas.count) plantillas", "\(vm.plantillas.count) templates")
        case .traslados:
            return L.t("\(traslados.count) traslados", "\(traslados.count) transfers")
        }
    }

    // MARK: - Plantillas

    private var elegidaPlantilla: Plantilla? {
        vm.plantillas.first { $0.id == plantillaElegida } ?? vm.plantillas.first
    }

    private var listaDePlantillas: some View {
        List(vm.plantillas, selection: $plantillaElegida) { p in
            VStack(alignment: .leading, spacing: 3) {
                Text(p.nombre).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                Text(p.asunto.isEmpty ? L.t("Sin asunto", "No subject") : p.asunto)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 3)
            .tag(p.id)
        }
    }

    /// **El texto de la plantilla y, al lado, qué se sustituye.**
    ///
    /// Las dos columnas del handoff: a la izquierda lo escrito con sus
    /// `{{llaves}}` y a la derecha las variables que existen y cómo queda ya
    /// resuelto. Sin el "RESUELTO" no hay forma de saber si una plantilla dice
    /// lo que uno cree antes de mandarla a alguien.
    @ViewBuilder
    private var panelDePlantilla: some View {
        if let p = elegidaPlantilla {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(p.nombre).font(.system(size: 16, weight: .semibold))
                        Text(L.t("Asunto · \(p.asunto)", "Subject · \(p.asunto)"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    bloqueDeTexto(L.t("TEXTO", "TEXT")) {
                        Text(p.saludo).font(.system(size: 12.5))
                        Text(p.cuerpoLlano).font(.system(size: 12.5))
                        Text(p.despedida).font(.system(size: 12.5))
                    }

                    bloqueDeTexto(L.t("VARIABLES", "VARIABLES")) {
                        FlowLayout(spacing: 6) {
                            ForEach(VariablesCarta.claves, id: \.self) { v in
                                Text("{{\(v)}}")
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(.quaternary.opacity(0.5), in: Capsule())
                            }
                        }
                    }

                    bloqueDeTexto(L.t("RESUELTO", "RESOLVED")) {
                        Text(resuelto(p.cuerpoLlano))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                        Text(L.t("Las variables se sustituyen al emitir la carta, y la carta se guarda ya resuelta — nunca con las llaves dentro.",
                                 "Variables are replaced when the letter is issued, and the letter is stored resolved — never with the braces still inside."))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(L.t("Escribir una carta con esta plantilla",
                               "Write a letter from this template")) {
                        estado.pidiendoAlta = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.brand)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.suelo)
        } else {
            ContentUnavailableView {
                Label(L.t("Sin plantillas", "No templates"), systemImage: "doc.text")
            } description: {
                Text(L.t("Las plantillas se escriben en el web y bajan solas.",
                         "Templates are written in the web app and sync down."))
            }
            .background(Color.suelo)
        }
    }

    private func resuelto(_ t: String) -> String {
        VariablesCarta.aplicar(t, CartaEnEdicion()
            .contextoVariables(ConfiguracionIglesiaViewModel.compartido.config))
    }

    private func bloqueDeTexto<C: View>(_ titulo: String,
                                        @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titulo)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { contenido() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .tarjetaMac(12)
        }
    }

    // MARK: - Traslados

    /// **Salen del padrón, no de las cartas.** Un traslado es un expediente con
    /// folio que vive en `traslados_salida`; la carta es uno de sus papeles. Por
    /// eso la lista la trae Membresía y no este ViewModel.
    private var tablaDeTraslados: some View {
        Table(traslados) {
            TableColumn(L.t("FOLIO", "FOLIO")) { t in
                Text(t.folio).monospacedDigit().frame(height: estado.altoDeFila)
            }
            .width(min: 110, ideal: 130)
            TableColumn(L.t("PERSONA", "PERSON")) { t in Text(t.persona) }
            TableColumn(L.t("IGLESIA", "CHURCH")) { t in
                Text(t.destino).foregroundStyle(.secondary)
            }
            TableColumn(L.t("ESTADO", "STATUS")) { t in
                Text(t.estadoLegible)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(t.enCurso ? Paleta.aviso : .secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background((t.enCurso ? Paleta.aviso : Color.secondary).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 120, ideal: 150)
        }
        .tableStyle(.inset)
        .overlay {
            if traslados.isEmpty {
                ContentUnavailableView {
                    Label(L.t("Ningún traslado", "No transfers"),
                          systemImage: "arrow.left.arrow.right")
                } description: {
                    Text(L.t("Los traslados salen de la ficha de cada miembro.",
                             "Transfers come from each member's profile."))
                }
                .background(Color.suelo)
            }
        }
    }

    // MARK: - La lista

    private var lista: some View {
        List(vm.emitidas, selection: $seleccion) { c in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(c.tipo.titulo)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    pastilla(c.estado)
                }
                Text(c.destinatarioNombre.isEmpty
                     ? L.t("Sin destinatario", "No recipient")
                     : c.destinatarioNombre)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(c.folio) · \(Fechas.diaLegible(c.fechaEmision))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.vertical, 3)
            .tag(c.id)
        }
    }

    private func pastilla(_ estado: String) -> some View {
        let tinta = tintaDe(estado)
        return Text(rotuloDe(estado))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tinta)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(tinta.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    /// **Los estados se leen de un texto libre, así que hay un caso por
    /// omisión de verdad.** La app web escribe aquí, y en la base de la
    /// iglesia ya hay un `aprobada` que el comentario del modelo no menciona
    /// —dice `borrador | emitida | entregada`—. Un `switch` sin salida
    /// dejaría esa carta sin pastilla; así al menos enseña lo que diga.
    private func rotuloDe(_ e: String) -> String {
        switch e {
        case "borrador":  return L.t("Borrador", "Draft")
        case "emitida":   return L.t("Emitida", "Issued")
        case "aprobada":  return L.t("Aprobada", "Approved")
        case "entregada": return L.t("Entregada", "Delivered")
        default:          return e.capitalized
        }
    }

    private func tintaDe(_ e: String) -> Color {
        switch e {
        case "borrador":             return Paleta.aviso
        case "emitida", "aprobada":  return Paleta.brand
        case "entregada":            return Paleta.placaPizarra
        default:                     return .secondary
        }
    }

    // MARK: - La hoja

    @ViewBuilder
    private var hoja: some View {
        if let c = elegida {
            ScrollView {
                HojaCarta(carta: c)
                    .padding(28)
            }
            .background(Color.suelo)
        } else {
            ContentUnavailableView {
                Label(L.t("Ninguna carta elegida", "No letter selected"),
                      systemImage: "envelope")
            } description: {
                Text(L.t("Elige una de la lista para verla como saldrá impresa.",
                         "Pick one from the list to see it as it will be printed."))
            }
            .background(Color.suelo)
        }
    }
    /// **Un borrador se ve y se dice.** Lleva folio provisional, así que no se
    /// puede imprimir todavía: el definitivo lo pone el servidor al subir. La
    /// banda lo explica y ofrece el único paso que falta.
    private func bandaDeBorrador(_ c: CartaEmitida) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.clock")
                .foregroundStyle(Paleta.aviso)
            Text(L.t("Borrador con folio \(c.folio) — el definitivo lo asigna el servidor al sincronizar.",
                     "Draft with folio \(c.folio) — the definitive one is assigned by the server when this Mac syncs."))
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L.t("Emitir la carta", "Issue the letter")) {
                Task {
                    await vm.emitirCarta()
                    await MotorSincronizacion.compartido.sincronizar()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Paleta.aviso.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    /// Las notas internas van FUERA del papel y lo dicen: son de quien redacta,
    /// no de quien recibe.
    private func notasInternas(_ c: CartaEmitida) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("NOTAS INTERNAS", "INTERNAL NOTES"))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            Text(c.observaciones)
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
            Text(L.t("No se imprimen en la carta.", "Not printed on the letter."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tarjetaMac(12)
    }
}

// MARK: - El papel

/// La carta como sale impresa.
///
/// **Siempre en blanco con tinta oscura, también en modo oscuro.** No es un
/// descuido: esto no es una vista de la app, es una previsualización del papel,
/// y el papel es blanco. Pintarla de gris en modo oscuro enseñaría algo que no
/// se corresponde con lo que va a salir de la impresora.
struct HojaCarta: View {
    let carta: CartaEmitida
    @State private var iglesia = ConfiguracionIglesiaViewModel.compartido

    /// Carta en puntos: 8,5" × 72. La misma que usa `PDFExport`.
    private let ancho: CGFloat = 612

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            membrete
            Text(carta.asunto.isEmpty
                 ? carta.tipo.titulo.uppercased()
                 : carta.asunto.uppercased())
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 30)

            if !carta.destinatarioNombre.isEmpty {
                Text(carta.destinatarioNombre)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 16)
            }
            if !carta.destinatarioDireccion.isEmpty {
                Text(carta.destinatarioDireccion)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                    .padding(.top, 2)
            }

            if !carta.saludo.isEmpty {
                Text(carta.saludo)
                    .font(.system(size: 12))
                    .padding(.top, 20)
            }

            // **El cuerpo puede venir vacío en un borrador**, y una hoja con un
            // hueco en medio parece rota. Se dice que está por escribir.
            Text(carta.cuerpo.isEmpty
                 ? L.t("[El cuerpo de la carta todavía está en blanco]",
                       "[The body of this letter is still empty]")
                 : carta.cuerpo)
                .font(.system(size: 12))
                .foregroundStyle(carta.cuerpo.isEmpty
                                 ? Color(red: 0.6, green: 0.6, blue: 0.63)
                                 : Color(red: 0.11, green: 0.11, blue: 0.12))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            if !carta.despedida.isEmpty {
                Text(carta.despedida)
                    .font(.system(size: 12))
                    .padding(.top, 20)
            }

            firmas
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 48)
        .frame(width: ancho, alignment: .leading)
        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.12))
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    private var membrete: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(iglesia.config.iniciales)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Paleta.brand,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(iglesia.config.nombre.isEmpty
                     ? L.t("Tu iglesia", "Your church") : iglesia.config.nombre)
                    .font(.system(size: 16, weight: .bold))
                if !lineaDeDireccion.isEmpty {
                    Text(lineaDeDireccion)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(L.t("Folio \(carta.folio)", "Folio \(carta.folio)"))
                Text(Fechas.diaLegible(carta.fechaEmision))
            }
            .font(.system(size: 11))
            .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paleta.brand).frame(height: 2)
        }
    }

    /// **Las piezas vacías no se imprimen**, que es la misma regla que ya
    /// documenta Configuración para el membrete: el encabezado se cierra sin
    /// renglones en blanco.
    private var lineaDeDireccion: String {
        [iglesia.config.direccion, iglesia.config.ciudad,
         iglesia.config.estado, iglesia.config.idFiscal]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var firmas: some View {
        if !carta.firmas.isEmpty {
            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(carta.firmas.enumerated()), id: \.offset) { _, f in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .frame(height: 1)
                        Text(f)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 56)
        }
    }
}
