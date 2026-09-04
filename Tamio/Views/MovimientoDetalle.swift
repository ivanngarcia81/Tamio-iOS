import SwiftUI
import UniformTypeIdentifiers

/// El panel de detalle de un movimiento: etiquetas, título y monto, acciones,
/// los campos, el rastro de auditoría y el comprobante. Fiel al handoff.
/// Recoge la altura MÁXIMA entre las tarjetas para igualarlas sin bucles.
private struct AlturaTarjetaKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MovimientoDetalle: View {
    let m: Movimiento
    var onEditar: (() -> Void)? = nil
    /// Altura común de las dos tarjetas del pie (audit / comprobante).
    @State private var alturaTarjetas: CGFloat = 0
    /// Devuelve el nombre del archivo elegido para el comprobante (adjuntar o
    /// reemplazar). La vista padre lo guarda vía el repositorio.
    var onComprobante: ((String) -> Void)? = nil
    @State private var mostrarImportador = false
    /// Abrir el comprobante pide una URL firmada al almacén: puede tardar y
    /// puede fallar (sin red, ruta borrada del bucket). Las dos cosas se dicen.
    @State private var abriendoComprobante = false
    @State private var errorComprobante: String?
    @Environment(\.openURL) private var openURL
    private var color: Color { Paleta.categoria(m.claveCategoria) }

    /// Texto que se comparte con el sistema (ShareLink).
    private var textoCompartir: String {
        "\(m.titular) — \(Money.fmt(m.monto)) (\(m.metodo)) · Folio \(m.folio)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                etiquetas
                cabecera
                acciones
                campos
                auditYComprobante
            }
            .padding(Esp.panel)
        }
        .colchonInferior()
        .background(Color(.systemGroupedBackground))
        .fileImporter(isPresented: $mostrarImportador,
                      allowedContentTypes: [.image, .pdf],
                      allowsMultipleSelection: false) { resultado in
            if case .success(let urls) = resultado, let url = urls.first {
                onComprobante?(url.lastPathComponent)
            }
        }
    }

    private var etiquetas: some View {
        HStack(spacing: 8) {
            Pill(texto: m.categoria, color: color)
            Pill(texto: "Folio \(m.folio)", color: .gray)
            if m.sinDepositar {
                Pill(texto: L.t("Sin depositar", "Not deposited"), color: Paleta.aviso)
            }
            // Un gasto marcado para revisar sale en "Por revisar". Se capturaba
            // y se guardaba, pero la ficha no lo decía por ningún lado: había
            // que volver a abrir la hoja de edición para saberlo.
            if m.marcadoPendiente {
                Pill(texto: L.t("Pendiente de revisar", "Flagged for review"), color: Paleta.aviso)
            }
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(m.titular).font(.title.weight(.bold))
            AmountText(cents: m.monto, size: 30, ingreso: m.esIngreso)
            // Quién lo registró ya lo dice el rastro de auditoría, más abajo.
            Text("\(m.metodo) · \(m.hora)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var acciones: some View {
        HStack(spacing: 10) {
            // Este botón decía "Ver comprobante" cuando ya había uno y lo que
            // abría era el selector de archivos: pulsarlo para verlo llevaba a
            // reemplazarlo. Ahora ver es ver y adjuntar es adjuntar.
            Button {
                if m.comprobante == nil { mostrarImportador = true } else { verComprobante() }
            } label: {
                Label(m.comprobante == nil ? L.t("Adjuntar comprobante", "Attach receipt")
                                           : L.t("Ver comprobante", "View receipt"),
                      systemImage: m.comprobante == nil ? "paperclip" : "eye")
            }
            .buttonStyle(.bordered)
            .tint(Color.secondary)
            .disabled(abriendoComprobante)
            ShareLink(item: textoCompartir) {
                Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .tint(Color.secondary)
            Button { onEditar?() } label: {
                Label(L.t("Editar", "Edit"), systemImage: "pencil").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Paleta.brand)
            Spacer()
        }
        .font(.subheadline)
    }

    private var campos: some View {
        Tarjeta {
            VStack(spacing: 0) {
                FieldRow(label: L.t("Fecha y hora", "Date & time"), value: fechaLarga)
                // El "Ver ficha" que llevaba esta fila era texto verde sin
                // acción. La ficha del padrón es de Secretaría y su acceso
                // depende de un permiso que la app todavía no mira, así que
                // aquí se enseña el nombre y nada más, hasta que Ajustes lo
                // resuelva.
                if let miembro = m.miembro {
                    Divider()
                    FieldRow(label: L.t("Miembro", "Member"), value: miembro)
                }
                // Un gasto se justifica por su beneficiario. Se capturaba
                // —"Pagado a" es obligatorio para guardar— y se guardaba, pero
                // la ficha no lo mostraba: solo aparecía colado en el titular,
                // y el RFC no aparecía en ninguna parte de la app.
                if let pagadoA = m.pagadoA, !pagadoA.isEmpty {
                    Divider()
                    FieldRow(label: L.t("Pagado a", "Paid to"), value: pagadoA)
                }
                if let rfc = m.rfc, !rfc.isEmpty {
                    Divider()
                    FieldRow(label: L.t("ID fiscal", "Tax ID"), value: rfc)
                }
                Divider()
                FieldRow(label: L.t("Método", "Method"), value: m.metodo)
                Divider()
                FieldRow(label: L.t("Categoría", "Category"), value: m.categoriaCompleta)
                if m.repiteMensual {
                    Divider()
                    FieldRow(label: L.t("Periodicidad", "Recurrence"),
                             value: L.t("Se repite cada mes", "Repeats monthly"))
                }
                if let nota = m.nota {
                    Divider()
                    bloqueTexto(L.t("Nota", "Note"), nota)
                }
                // Las notas internas iban al mismo sitio que la nota del
                // movimiento en la hoja de captura y luego no se veían nunca.
                if let notas = m.notasAuditoria, !notas.isEmpty {
                    Divider()
                    bloqueTexto(L.t("Notas internas", "Internal notes"), notas)
                }
            }
        }
    }

    private func bloqueTexto(_ titulo: String, _ cuerpo: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.subheadline).foregroundStyle(.secondary)
            Text(cuerpo).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private var auditYComprobante: some View {
        // Tarjetas del MISMO tamaño, de forma SEGURA (sin el Grid +
        // containerRelativeFrame + maxHeight:.infinity que colgaba la app):
        // ancho igual con maxWidth:.infinity, y alto igual midiendo la más alta
        // con un PreferenceKey y aplicándola como minHeight (converge, no cicla).
        HStack(alignment: .top, spacing: 16) {
            tarjetaIgualada { auditoria }
            tarjetaIgualada { comprobante }
        }
        .onPreferenceChange(AlturaTarjetaKey.self) { nueva in
            if nueva > alturaTarjetas { alturaTarjetas = nueva }
        }
    }

    private func tarjetaIgualada<V: View>(@ViewBuilder _ contenido: () -> V) -> some View {
        contenido()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: alturaTarjetas, alignment: .topLeading)
            .background(GeometryReader { g in
                Color.clear.preference(key: AlturaTarjetaKey.self, value: g.size.height)
            })
    }

    private var auditoria: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                TituloSeccion(texto: L.t("RASTRO DE AUDITORÍA", "AUDIT TRAIL"))
                if m.auditoria.isEmpty {
                    Text(L.t("Sin eventos registrados.", "No events recorded."))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(m.auditoria) { e in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(Paleta.brand).frame(width: 7, height: 7).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.titulo).font(.subheadline.weight(.medium))
                                Text(e.detalle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var comprobante: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                TituloSeccion(texto: L.t("COMPROBANTE", "RECEIPT"))
                if let archivo = m.comprobante {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.richtext")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            // La ruta guardada es "<church_id>/<uuid>.pdf": el
                            // primer segmento no le dice nada a nadie.
                            Text((archivo as NSString).lastPathComponent)
                                .font(.subheadline).lineLimit(1).truncationMode(.middle)
                            // Solo "Reemplazar": ver el comprobante es el
                            // botón de arriba, y tenerlo también aquí era la
                            // misma duplicación por el otro lado.
                            Button(L.t("Reemplazar", "Replace")) { mostrarImportador = true }
                                .buttonStyle(.plain).foregroundStyle(Paleta.enlace)
                                .font(.caption)
                        }
                        Spacer()
                    }
                } else {
                    // Aquí NO va otro "Adjuntar comprobante": esa acción es la
                    // del botón de arriba. Convivían las dos, una gris y otra
                    // verde, para lo mismo. Esta tarjeta enseña el estado.
                    Text(L.t("Sin comprobante.", "No receipt."))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if abriendoComprobante {
                    Text(L.t("Abriendo…", "Opening…"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorComprobante {
                    Text(errorComprobante)
                        .font(.caption).foregroundStyle(Paleta.negativo)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Pide la URL firmada al almacén y la abre. La ruta guardada es interna
    /// del bucket: no se puede abrir directamente.
    private func verComprobante() {
        guard let ruta = m.comprobante else { return }
        abriendoComprobante = true
        errorComprobante = nil
        Task {
            do {
                openURL(try await almacenComprobantes().urlFirmada(ruta))
            } catch {
                errorComprobante = L.t("No se pudo abrir el comprobante: \(error.localizedDescription)",
                                       "Couldn't open the receipt: \(error.localizedDescription)")
            }
            abriendoComprobante = false
        }
    }

    /// Mismo formato que las filas de campo del detalle de aprobación. Antes
    /// esta decía "September 3, 2026, 12:05" y aquella "Aug 30, 2026".
    private var fechaLarga: String {
        Fechas.cortaConHora(m.fecha, hora: m.hora)
    }
}
