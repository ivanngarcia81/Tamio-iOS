import SwiftUI
import AppKit

/// **Depósitos.** Las seis columnas de la maqueta: Fecha, Cuenta, Folios,
/// Movimientos, Estado e Importe.
///
/// Lo que la maqueta llama "deposits" son los CORTES: el acto de juntar los
/// movimientos de un periodo, sacarlos de la caja y llevarlos al banco.
struct TablaDepositos: View {
    let vm: DepositosViewModel
    @Environment(EstadoVentana.self) private var estado
    @Binding var seleccion: Set<Corte.ID>
    @State private var orden = [KeyPathComparator(\Corte.registro.fecha, order: .reverse)]
    /// El corte que se está viendo en papel. `item:` y no un booleano, como en
    /// Actas: la hoja no puede abrirse antes de tener el corte.
    @State private var corteEnPDF: Corte?

    private var filas: [Corte] { vm.items.sorted(using: orden) }

    /// **A media pantalla la tabla suelta una columna y estrecha el resto**
    /// (handoff 9: «a 900 pt cada tabla suelta la columna que ya está en el
    /// inspector»). `Table` nace en el ancho ideal de sus columnas y no las
    /// encoge, así que por debajo de esa suma las últimas quedaban fuera de la
    /// vista. `ViewThatFits` y no medir el ancho, como en `TablaMovimientos`.
    private static let anchoCompleto: CGFloat = 140 + 220 + 140 + 108 + 136 + 140 + 6 * 17 + 20

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabla(estrecha: false)
                .frame(minWidth: 0, idealWidth: Self.anchoCompleto, maxWidth: .infinity, maxHeight: .infinity)
            tabla(estrecha: true)
        }
        .sheet(item: $corteEnPDF) { c in
            VistaPreviaCorteMac(corte: c)
        }
    }

    private func tabla(estrecha: Bool) -> some View {
        Table(filas, selection: $seleccion, sortOrder: $orden) {

            TableColumn(L.t("Fecha", "Date"), value: \.registro.fecha) { c in
                Text(c.registro.fecha.isEmpty ? "—" : Fechas.diaLegible(c.registro.fecha))
                    .foregroundStyle(.secondary)
                    // El alto de fila se fija en la primera columna: `Table` no
                    // tiene ajuste propio y la fila mide lo que su celda más alta.
                    .frame(height: estado.altoDeFila)
            }
            .width(min: 96, ideal: estrecha ? 104 : 140, max: 190)

            TableColumn(L.t("Cuenta", "Bank account"), value: \.registro.cuenta) { c in
                Text(c.registro.cuenta.isEmpty ? "—" : c.registro.cuenta)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: estrecha ? 170 : 220)

            // Los folios ya salen en el inspector: es la que se suelta.
            if !estrecha {
                TableColumn(L.t("Folios", "Folios"), value: \.rangoDeFolios) { c in
                    Text(c.rangoDeFolios)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .width(min: 110, ideal: 140, max: 200)
            }

            TableColumn(L.t("Movimientos", "Items"), value: \.cuantosMovimientos) { c in
                Text("\(c.cuantosMovimientos)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 56, ideal: estrecha ? 64 : 108, max: 150)

            TableColumn(L.t("Estado", "Status"), value: \.ordenDeEstado) { c in
                let (texto, tinta) = c.pastilla
                Text(texto)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tinta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tinta.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .width(min: 104, ideal: estrecha ? 118 : 136, max: 190)

            TableColumn(L.t("Importe", "Amount"), value: \.suma) { c in
                Text(Money.fmt(c.suma))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 100, ideal: estrecha ? 112 : 140, max: 190)
        }
        // **Sin rayas alternas.** `alternatesRowBackgrounds` las pinta en
        // TODO el alto de la tabla, también donde no hay datos: con dos filas
        // en pantalla la ventana se llenaba de renglones rayados vacíos.
        .tableStyle(.inset)
        // **El papel del corte, desde el menú de la fila y con doble clic.**
        // La tabla no tiene un detalle propio donde poner el botón —el
        // inspector es de `VentanaPrincipal`—, y el menú contextual es donde
        // el Mac busca "qué puedo hacer con esto". Solo con UNA fila: un PDF
        // es de un corte, y con seis seleccionados habría que elegir cuál sin
        // decirlo. Solo lee: no hay nada aquí que marque o mueva dinero.
        .contextMenu(forSelectionType: Corte.ID.self) { ids in
            if ids.count == 1, let c = filas.first(where: { ids.contains($0.id) }) {
                Button(L.t("Vista previa PDF", "PDF preview")) { corteEnPDF = c }
            }
        } primaryAction: { ids in
            if ids.count == 1, let c = filas.first(where: { ids.contains($0.id) }) {
                corteEnPDF = c
            }
        }
    }
}

// MARK: - Vista previa del PDF

/// **La hoja del corte a tamaño de papel, con su botón de compartir.**
///
/// La contraparte de `DocumentoPDFSheet` del iPhone, que el Mac no compila.
/// Sigue a `VistaPreviaActaMac` (`PantallaActas.swift`): a escala 1 porque la
/// ventana da los 612 puntos, y el PDF sale de la MISMA `CorteHojaPDF` que se
/// ve — lo que se mira es lo que se comparte.
private struct VistaPreviaCorteMac: View {
    let corte: Corte

    @Environment(\.dismiss) private var dismiss
    @State private var ancla = AnclaCompartir()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(L.t("Vista previa PDF · \(corte.titulo)", "PDF preview · \(corte.titulo)"))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    compartir()
                } label: {
                    Label(L.t("Compartir", "Share"), systemImage: "square.and.arrow.up")
                }
                .background(VistaAncla(ancla: ancla))
                Button(L.t("Cerrar", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                CorteHojaPDF(corte: corte)
                    .compositingGroup()  // una sombra para el papel, no una por texto
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(28)
                    .frame(maxWidth: .infinity)
            }
            .background(Color.suelo)
        }
        // El ancho de la carta más sus márgenes: la hoja nunca se recorta.
        .frame(minWidth: PDFExport.anchoCarta + 56 + 40, idealWidth: 760,
               minHeight: 560, idealHeight: 820)
    }

    /// Se genera al pulsar y no al abrir: si el corte cambia con la hoja
    /// abierta, lo que se comparte es la hoja que se está viendo.
    private func compartir() {
        guard let url = PDFExport.render(CorteHojaPDF(corte: corte),
                                         nombre: CorteHojaPDF.nombreArchivo(corte)),
              let vista = ancla.vista else { return }
        NSSharingServicePicker(items: [url])
            .show(relativeTo: vista.bounds, of: vista, preferredEdge: .minY)
    }
}

extension Corte {
    var cuantosMovimientos: Int { movimientos.count }
    var suma: Centavos { movimientos.reduce(0) { $0 + $1.monto } }

    /// "1042–1051". **Del primero al último de verdad**, no del orden en que
    /// vengan: un corte se cuadra contra el talonario, y para eso hacen falta
    /// los dos extremos.
    var rangoDeFolios: String {
        let folios = movimientos.map(\.folio).filter { !$0.isEmpty }.sorted()
        guard let primero = folios.first, let ultimo = folios.last else { return "—" }
        return primero == ultimo ? primero : "\(primero)–\(ultimo)"
    }

    /// Primero lo que sigue en la caja: es lo que hay que llevar al banco.
    var ordenDeEstado: Int { estado == .pendiente ? 0 : 1 }

    var pastilla: (String, Color) {
        // **"Por revisar" gana a "Depositado".** Un corte con movimientos
        // señalados no está cerrado aunque el dinero ya esté en el banco, y
        // enseñarlo en verde diría que no queda nada que hacer.
        if porRevisar > 0 {
            return (L.t("\(porRevisar) por revisar", "\(porRevisar) to review"), Paleta.aviso)
        }
        return estado == .pendiente
            ? (L.t("En caja", "In the cash box"), Paleta.aviso)
            : (L.t("Depositado", "Deposited"), Paleta.brand)
    }
}
