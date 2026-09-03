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
    private var color: Color { Paleta.categoria(m.categoria) }

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
            .padding(24)
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
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(m.titular).font(.title.weight(.bold))
            AmountText(cents: m.monto, size: 30)
            // Quién lo registró ya lo dice el rastro de auditoría, más abajo.
            Text("\(m.metodo) · \(m.hora)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var acciones: some View {
        HStack(spacing: 10) {
            Button { mostrarImportador = true } label: {
                Label(m.comprobante == nil ? L.t("Comprobante", "Receipt") : L.t("Ver comprobante", "View receipt"),
                      systemImage: "paperclip")
            }
            .buttonStyle(.bordered)
            .tint(Color.secondary)
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
                Divider()
                if let miembro = m.miembro {
                    FieldRow(label: L.t("Miembro", "Member"), value: miembro, link: L.t("Ver ficha", "View profile"))
                    Divider()
                }
                FieldRow(label: L.t("Método", "Method"), value: m.metodo)
                Divider()
                FieldRow(label: L.t("Categoría", "Category"), value: m.categoriaCompleta)
                if let nota = m.nota {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("Nota", "Note")).font(.subheadline).foregroundStyle(.secondary)
                        Text(nota).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
            }
        }
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
                            Text(archivo).font(.subheadline).lineLimit(1)
                            HStack(spacing: 12) {
                                Text(L.t("Ver", "View")).foregroundStyle(Paleta.enlace)
                                Button(L.t("Reemplazar", "Replace")) { mostrarImportador = true }
                                    .buttonStyle(.plain).foregroundStyle(Paleta.enlace)
                            }
                            .font(.caption)
                        }
                        Spacer()
                    }
                } else {
                    Button { mostrarImportador = true } label: {
                        Label(L.t("Adjuntar comprobante", "Attach receipt"), systemImage: "paperclip")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var fechaLarga: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = L.esEspanol ? "d 'de' MMMM 'de' yyyy" : "MMMM d, yyyy"
        return "\(f.string(from: m.fecha)), \(m.hora)"
    }
}
