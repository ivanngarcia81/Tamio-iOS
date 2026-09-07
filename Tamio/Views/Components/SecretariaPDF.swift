import SwiftUI

/// **Las hojas imprimibles de Secretaría: la carta y el acta.**
///
/// Hasta el 7 de septiembre de 2026 no existían, y era el agujero más grande
/// que quedaba en el área: el botón de compartir de la vista previa de una
/// carta era literalmente `// Compartir — placeholder`, y el pie del formulario
/// del acta prometía que "el PDF incluye espacio de firma" cuando en toda la
/// app solo se generaban cuatro PDF y ninguno era de Secretaría. Se llenaba una
/// carta, se firmaba, se emitía con su folio del servidor — y no salía del
/// teléfono.
///
/// Siguen el patrón de `ReporteHojaPDF`: ancho fijo de carta (lo envuelve
/// `PDFExport`), blanco y negro con el verde de marca solo donde ya lo llevaba
/// la pantalla, y el membrete y el pie salen de Ajustes.

// MARK: - Una línea de firma

/// La raya con su nombre debajo y, si la hay, la firma dibujada encima.
///
/// La mecánica es la de `FirmasPDF` y por el mismo motivo: **la firma va ENCIMA
/// de la raya, no en lugar de ella**, así el documento se lee igual firmado en
/// la app o a mano sobre el papel, y quien no tenga firma guardada sigue
/// teniendo dónde firmar. Se saca aparte porque ahora la usan tres documentos
/// con tres repartos distintos —el reporte firma con los cargos de la iglesia,
/// la carta con uno solo, el acta con los tres roles del acta— y la única forma
/// de que las tres se vean iguales es que sean la misma.
struct FirmaEnLinea: View {
    let nombre: String
    let cargo: String
    var imagen: UIImage? = nil
    /// El acta marca quién ya firmó; la carta y el reporte no llevan esa
    /// casilla y no enseñan nada aquí.
    var fechaFirma: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let imagen {
                Image(uiImage: imagen)
                    .resizable().scaledToFit()
                    .frame(height: 34)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Color.clear.frame(height: 34)
            }
            Rectangle().fill(.secondary.opacity(0.5)).frame(height: 0.75)
            Text(nombre.isEmpty ? " " : nombre).font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            Text(cargo).font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            if let fechaFirma, !fechaFirma.isEmpty {
                Text(L.t("Firmó el \(Fechas.diaLegible(fechaFirma))",
                         "Signed \(Fechas.diaLegible(fechaFirma))"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Carta

/// La hoja de una carta o constancia de Secretaría.
struct CartaHojaPDF: View {
    let carta: CartaEnEdicion
    let tipo: TipoPlantilla
    let cuerpo: String
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config
    var firmas: FirmasLocales = .compartidas

    /// **La fecha de EMISIÓN, no la de hoy.** La vista previa llevaba
    /// `"20 de agosto de 2026"` escrita a mano, y la hoja larga usaba la fecha
    /// del día. Ninguna de las dos es la que la carta dice llevar: el
    /// formulario recoge `fechaEmision` y es la que se firma.
    private var fecha: String {
        let dia = Fechas.diaLegibleLargo(carta.fechaEmision)
        let lugar = carta.lugarEmision.trimmingCharacters(in: .whitespaces)
        return lugar.isEmpty ? dia : "\(lugar), \(dia)"
    }

    /// La imagen del pastor solo si es él quien firma. Una carta la firma UNA
    /// persona —la que eligió el formulario—, así que `FirmasPDF`, que imprime
    /// los tres cargos de la iglesia, aquí sacaría al tesorero en una carta de
    /// recomendación.
    private var imagenFirma: UIImage? {
        if carta.firma == iglesia.pastorNombre { return firmas.imagen(.pastor) }
        if carta.firma == iglesia.tesoreroNombre { return firmas.imagen(.tesorero) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Membrete centrado, como en la pantalla: una carta encabeza
            // centrada, al contrario que los reportes.
            VStack(alignment: .center, spacing: 4) {
                LogoMembrete(alto: 60)
                if !iglesia.nombre.isEmpty {
                    Text(iglesia.nombre).font(.system(.title3, design: .serif).weight(.bold))
                }
                if !iglesia.ubicacionLegible.isEmpty {
                    Text(iglesia.ubicacionLegible).font(.caption).foregroundStyle(.secondary)
                }
                Text(fecha).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            Divider().padding(.bottom, 20)

            Text(tipo.titulo.uppercased())
                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                .padding(.bottom, 12)

            if !carta.direccionDestinatario.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(carta.direccionDestinatario)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
            }

            // **`fixedSize` vertical en todo lo que puede ser largo.** Sin
            // él, un `Text` dentro de una hoja de ancho fijo se mide a su
            // ancho IDEAL —una sola línea— y lo que sobra se corta en "…".
            // Se vio en el acta: el cuerpo, los acuerdos y la lista de
            // presentes salían todos truncados.
            Text(cuerpo)
                .font(.subheadline)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 40)

            // La firma a la izquierda y con el ancho de una rúbrica, no del
            // folio: una raya de 612 puntos de ancho no parece un renglón de
            // firma, parece un separador.
            FirmaEnLinea(nombre: carta.firma,
                         cargo: iglesia.pastorCargo,
                         imagen: imagenFirma)
                .frame(width: 220)

            Spacer(minLength: 28)
            PieInstitucionalPDF(iglesia: iglesia)
        }
        .padding(48)
        // **El ancho de la página, explícito.** Es el contrato que documenta
        // `HojaCartaEscalada` y que cumplen las otras cuatro hojas. Sin él,
        // nadie propone un ancho: cada `Text` se mide a UNA línea, y el acta
        // salía con todo cortado en "…" y la hoja dibujada estrecha.
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
    }
}

// MARK: - Acta

/// La hoja de un acta. Lleva lo que el formulario recoge y la pantalla enseña,
/// más el bloque de firmas que el pie de Ajustes lleva prometiendo.
struct ActaHojaPDF: View {
    let acta: Acta
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config
    var firmas: FirmasLocales = .compartidas

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .center, spacing: 4) {
                LogoMembrete(alto: 52)
                Text(L.t("ACTA · \(acta.tipo.etiqueta.uppercased())",
                         "MINUTES · \(acta.tipo.etiqueta.uppercased())"))
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .multilineTextAlignment(.center)
                Text(L.t("\(iglesia.nombre) · Acta \(acta.folio)",
                         "\(iglesia.nombre) · Minutes \(acta.folio)"))
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !acta.fecha.isEmpty {
                    Text(Fechas.diaLegible(acta.fecha))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // **El quórum, que es lo único que el cuerpo no dice.** Aquí
            // hubo primero una tabla con lugar, hora, quién preside, presentes
            // y ausentes: al verla impresa resultó que `Acta.cuerpo` ya narra
            // todo eso, así que el acta salía diciendo dos veces la lista de
            // asistentes. El cuerpo manda; esta línea completa lo que le falta.
            if acta.quorum {
                Text(L.t("Se declara quórum.", "Quorum declared."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !acta.cuerpo.isEmpty {
                Text(acta.cuerpo).font(.subheadline).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !acta.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("ACUERDOS", "AGREEMENTS"))
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(Array(acta.items.enumerated()), id: \.element.id) { idx, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1).")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Paleta.brand)
                                .frame(width: 20, alignment: .trailing)
                            Text(item.texto).font(.subheadline).lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 24)
            Divider()

            HStack(alignment: .top, spacing: 32) {
                ForEach(RolFirmaActa.allCases) { rol in
                    FirmaEnLinea(nombre: nombre(rol), cargo: rol.etiqueta,
                                 imagen: imagen(rol), fechaFirma: fechaFirma(rol))
                        .frame(maxWidth: .infinity)
                }
            }

            PieInstitucionalPDF(iglesia: iglesia)
        }
        .padding(48)
        // **El ancho de la página, explícito.** Es el contrato que documenta
        // `HojaCartaEscalada` y que cumplen las otras cuatro hojas. Sin él,
        // nadie propone un ancho: cada `Text` se mide a UNA línea, y el acta
        // salía con todo cortado en "…" y la hoja dibujada estrecha.
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
    }

    /// Quién ocupa cada rol. Del acta, no de Ajustes: quien presidió esa
    /// reunión puede no ser el pastor, y el acta ya lo guarda.
    private func nombre(_ rol: RolFirmaActa) -> String {
        switch rol {
        case .preside:    return acta.preside.isEmpty ? iglesia.pastorNombre : acta.preside
        case .secretario: return acta.secretario.isEmpty ? iglesia.secretarioNombre : acta.secretario
        case .testigo:    return ""
        }
    }

    /// La rúbrica guardada solo si quien ocupa el rol es la persona de Ajustes
    /// que la dibujó, y solo si el acta consta como firmada por ese rol: una
    /// firma estampada en un acta que nadie ha firmado es exactamente lo que un
    /// acta no puede hacer.
    private func imagen(_ rol: RolFirmaActa) -> UIImage? {
        guard firmo(rol) else { return nil }
        let quien = nombre(rol)
        if quien == iglesia.pastorNombre { return firmas.imagen(.pastor) }
        if quien == iglesia.tesoreroNombre { return firmas.imagen(.tesorero) }
        return nil
    }

    private func firmo(_ rol: RolFirmaActa) -> Bool {
        acta.firmas.first { $0.rol == rol }?.firmado ?? false
    }

    private func fechaFirma(_ rol: RolFirmaActa) -> String? {
        acta.firmas.first { $0.rol == rol && $0.firmado }?.fecha
    }
}

// MARK: - La hoja modal

/// Vista previa a tamaño de página con el botón de compartir, para cualquier
/// documento. `ReportePDFSheet` y `ReporteAnualPDFSheet` son dos copias de esto
/// mismo escritas aparte; los nuevos no van a ser la tercera y la cuarta.
struct DocumentoPDFSheet<Hoja: View>: View {
    let titulo: String
    /// Sin extensión y sin espacios: es el nombre con el que el archivo llega
    /// a Mail o a Archivos.
    let nombreArchivo: String
    /// Atravesada sobre la hoja cuando el documento todavía no vale: "BORRADOR"
    /// en una carta a medias. Va sobre la PREVIA y no dentro de la hoja, que es
    /// lo que se exporta — pero es que un documento con marca de agua no se
    /// exporta: para eso está `puedeCompartir`.
    var marcaDeAgua: String? = nil
    /// Con `false`, la previa se ve y el botón de compartir no aparece. Una
    /// carta con campos sin llenar se puede mirar; entregarla, no.
    var puedeCompartir: Bool = true
    @ViewBuilder let hoja: Hoja

    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                // La marca de agua en un `overlay` y no en un `ZStack`: no
                // tiene que empujar el layout de la hoja que va debajo.
                HojaCartaEscalada { hoja }
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .overlay {
                        if let marcaDeAgua {
                            Text(marcaDeAgua)
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .rotationEffect(.degrees(-30))
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(Esp.panel)
            }
            .background(Color(.systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cerrar", "Close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let pdfURL, puedeCompartir {
                        ShareLink(item: pdfURL) {
                            Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.glass)
                        .tint(Paleta.brand)
                    }
                }
            }
        }
        // Solo se arma el archivo si se puede entregar: renderizar un PDF de
        // una carta a medias es trabajo para nada, y un archivo temporal que
        // nadie pidió.
        .onAppear {
            if puedeCompartir { pdfURL = PDFExport.render(hoja, nombre: nombreArchivo) }
        }
        .hojaDocumento()
    }
}


// MARK: - El membrete, a solas

/// **Cómo queda el membrete con lo que hay escrito en Ajustes.**
///
/// La fila "Vista previa del PDF" de Ajustes · Institución llevaba desde
/// siempre en "Próximamente". No hacía falta inventar nada para cumplirla: los
/// documentos ya se arman con estas mismas piezas —`LogoMembrete`, `FirmasPDF`,
/// `PieInstitucionalPDF`—, así que la previa es literalmente lo que va a salir
/// impreso, sin datos de ejemplo de por medio.
///
/// El cuerpo es una franja gris y no un texto falso: **lo que esta pantalla
/// configura es el marco**, no lo que va dentro. Poner una carta inventada
/// ahí invitaría a revisar la prosa en vez del membrete, que es lo que se está
/// mirando.
struct MembreteHojaPDF: View {
    var iglesia: ConfiguracionIglesia = ConfiguracionIglesiaViewModel.compartido.config

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .center, spacing: 4) {
                LogoMembrete(alto: 60)
                if !iglesia.nombre.isEmpty {
                    Text(iglesia.nombre).font(.system(.title3, design: .serif).weight(.bold))
                }
                if !iglesia.ubicacionLegible.isEmpty {
                    Text(iglesia.ubicacionLegible).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            Divider().padding(.bottom, 24)

            // El hueco del documento. Cuatro rayas y no un párrafo de mentira:
            // aquí se mira el marco.
            // El ancho útil de la hoja: la página menos sus dos márgenes. Se
            // calcula y no se escribe a mano para que las rayas sigan al papel
            // si algún día cambia el margen.
            let util = PDFExport.anchoCarta - 96
            VStack(alignment: .leading, spacing: 10) {
                ForEach([1.0, 0.94, 0.97, 0.62], id: \.self) { proporcion in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.secondary.opacity(0.16))
                        .frame(width: util * proporcion, height: 11)
                }
            }
            .padding(.bottom, 36)

            FirmasPDF(iglesia: iglesia)
            Spacer(minLength: 24)
            PieInstitucionalPDF(iglesia: iglesia)
        }
        .padding(48)
        .frame(width: PDFExport.anchoCarta, alignment: .leading)
    }
}
