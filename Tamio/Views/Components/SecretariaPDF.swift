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

// MARK: - Las piezas comunes

// `FirmaEnLinea` —y con ella `FirmasPDF`, `PieInstitucionalPDF`,
// `LogoMembrete` y `MembreteHojaPDF`— viven en `Support/PiezasPDF.swift`:
// son el papel que comparten todos los documentos, y el Mac también los
// imprime.

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
    private var imagenFirma: ImagenPlataforma? {
        if carta.firma == iglesia.pastorNombre { return firmas.imagen(.pastor) }
        if carta.firma == iglesia.tesoreroNombre { return firmas.imagen(.tesorero) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Membrete centrado, como en la pantalla: una carta encabeza
            // centrada, al contrario que los reportes.
            // **`.multilineTextAlignment(.center)` va en el CONTENEDOR, y falta
            // en dos de los tres membretes centrados.** Un `VStack(alignment:
            // .center)` centra las VISTAS, no las LÍNEAS de dentro: un `Text`
            // que envuelve ocupa todo el ancho y pinta su texto alineado a la
            // izquierda. Con un nombre de iglesia corto no se nota —cabe en una
            // línea y parece centrado—, y con uno que envuelve el nombre sale
            // en bandera a la izquierda mientras la ciudad, debajo y de una
            // línea, sigue centrada: dos alineaciones en el mismo membrete.
            //
            // Medido el 12-sep en el PDF impreso con un nombre de 500
            // caracteres (`pruebas/TextoBrutoEnElMembreteTests.swift`). En
            // pantalla no se ve: el nombre de prueba cabe.
            //
            // Va en el contenedor y no `Text` a `Text` —como estaba en el
            // acta— para que el siguiente renglón que se añada aquí no vuelva
            // a quedarse fuera.
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
            .multilineTextAlignment(.center)
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
                         cargo: Catalogos.Cargos.cargo(iglesia.pastorCargo, o: .pastor),
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

// `ActaHojaPDF` se mudó a `Support/PiezasPDF.swift` para que la compile
// también el Mac, que no compila esta carpeta y no tenía cómo sacar un acta
// en papel. Sigue llamándose igual y recibe lo mismo.

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
                                // El gris del tema claro, como la hoja: el del
                                // oscuro es casi blanco y sobre el papel no se
                                // veía.
                                .environment(\.colorScheme, .light)
                                // Un renglón: en la hoja de una carta, que es
                                // baja, se partía en «BORRADO» y «R».
                                .fixedSize()
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
                        // **Sin `buttonStyle`: el sistema elige, y elige bien.**
                        // Llevaba `.buttonStyle(.glass)` puesto a propósito para
                        // BAJAR del prominente que el sistema pone en una acción
                        // de confirmación, y el motivo escrito era el contraste:
                        // "un símbolo blanco sobre Paleta.brand da ~2.4:1 en
                        // oscuro".
                        //
                        // **Ese motivo era falso.** Medido el 16-sep en el botón
                        // "Listo" de la hoja de filtros, que sí es prominente:
                        // en claro sale blanco sobre el verde oscuro (6.28:1) y
                        // en OSCURO sale NEGRO sobre el verde claro (9.01:1). El
                        // sistema ya escoge el color legible de encima; nadie lo
                        // comprobó y se le puso un parche que además dejaba la
                        // acción principal sin su énfasis.
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
