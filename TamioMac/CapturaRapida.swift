import SwiftUI

/// **La ventana de captura rápida (⌥⌘N).**
///
/// Es una ventana aparte y no una hoja encima de la principal, como en la
/// maqueta: la idea es poder dejarla abierta mientras se mira la lista de
/// atrás, que es como se captura un domingo entero de ofrendas.
///
/// La frase de la maqueta —"Tab moves through every field. Nothing here needs
/// the mouse"— es un requisito, no un adorno: quien captura ochenta sobres no
/// suelta el teclado. Por eso no hay ningún control aquí que solo se pueda
/// tocar con el ratón.
struct CapturaRapida: View {
    static let idVentana = "captura-rapida"

    @Environment(\.dismiss) private var cerrar
    @State private var tipo: Tipo = .ingreso
    @State private var importe = ""
    @State private var nota = ""
    @State private var fecha = Date()

    enum Tipo: String, CaseIterable, Identifiable {
        case ingreso, gasto
        var id: String { rawValue }
        var titulo: String {
            switch self {
            case .ingreso: return L.t("Ingreso", "Income")
            case .gasto:   return L.t("Gasto", "Expense")
            }
        }
        /// El verde de la marca para lo que entra, el rojo para lo que sale.
        /// Es la misma regla que en toda la app y por eso sale de `Paleta`.
        var tinta: Color { self == .ingreso ? Paleta.brand : Paleta.negativo }
        /// "Aportante" o "Beneficiario": la misma casilla no se llama igual
        /// según el dinero entre o salga.
        var rotuloParte: String {
            switch self {
            case .ingreso: return L.t("Aportante", "Contributor")
            case .gasto:   return L.t("Beneficiario", "Payee")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $tipo) {
                ForEach(Tipo.allCases) { Text($0.titulo).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    campo(L.t("Importe", "Amount")) {
                        TextField("", text: $importe, prompt: Text("0.00"))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(tipo.tinta)
                    }
                    campo(L.t("Folio (automático)", "Folio (auto)")) {
                        Text(L.t("Se asigna al guardar", "Assigned on save"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                GridRow {
                    campo(L.t("Fecha", "Date")) {
                        DatePicker("", selection: $fecha, displayedComponents: .date)
                            .labelsHidden()
                    }
                    campo(tipo.rotuloParte) {
                        Text(L.t("Pendiente de enchufar", "Not wired yet"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            campo(L.t("Nota", "Note")) {
                TextField("", text: $nota,
                          prompt: Text(L.t("Opcional — sale en el recibo",
                                           "Optional — shows on the receipt")),
                          axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            // **El aviso está aquí a propósito.**
            //
            // Esta ventana todavía no escribe en la base: le falta el
            // catálogo de categorías, el selector de aportante y la
            // validación del importe. Un botón "Guardar" que no guarda, en
            // una app donde lo que se guarda es dinero, es peor que un botón
            // desactivado que dice por qué.
            Label(L.t("El guardado todavía no está enchufado al motor.",
                      "Saving is not wired to the engine yet."),
                  systemImage: "exclamationmark.triangle")
                .font(.system(size: 11.5))
                .foregroundStyle(Paleta.aviso)

            HStack(spacing: 9) {
                Text(L.t("El tabulador recorre todas las casillas.",
                         "Tab moves through every field."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button(L.t("Cancelar", "Cancel")) { cerrar() }
                    .keyboardShortcut(.cancelAction)
                Button(L.t("Guardar", "Save")) { }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(tipo.tinta)
                    .disabled(true)
            }
        }
        .padding(18)
        .frame(width: 596)
    }

    private func campo<C: View>(_ rotulo: String,
                                @ViewBuilder contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            contenido()
        }
    }
}
