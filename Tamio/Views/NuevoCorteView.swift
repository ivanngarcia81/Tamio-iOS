import SwiftUI

/// Formulario de nuevo corte de caja. Devuelve título, cuenta y monto por
/// `onGuardar`; la vista padre crea el corte vía el repositorio.
struct NuevoCorteView: View {
    @Environment(\.dismiss) private var dismiss

    let cuentas: [String]
    let onGuardar: (_ titulo: String, _ cuenta: String, _ monto: Centavos) -> Void

    @State private var titulo = ""
    @State private var cuenta: String
    @State private var importe = ""

    init(cuentas: [String],
         onGuardar: @escaping (_ titulo: String, _ cuenta: String, _ monto: Centavos) -> Void) {
        self.cuentas = cuentas
        self.onGuardar = onGuardar
        _cuenta = State(initialValue: cuentas.first ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                importeView.padding(.vertical, 16)
                Form {
                    Section {
                        TextField(L.t("Título del corte", "Cut title"), text: $titulo)
                        Picker(L.t("Cuenta", "Account"), selection: $cuenta) {
                            ForEach(cuentas, id: \.self) { Text($0).tag($0) }
                        }
                    } footer: {
                        Text(L.t("Después podrás agregar los movimientos en caja y adjuntar la ficha del banco.",
                                 "You can add the cash entries and attach the bank slip afterward."))
                    }
                }
            }
            .navigationTitle(L.t("Nuevo corte", "New cut"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Crear", "Create")) {
                        onGuardar(titulo, cuenta, Self.aCentavos(importe))
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(importe.isEmpty)
                }
            }
        }
        .hojaGrande()
    }

    private var importeView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("$").font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            TextField("0.00", text: $importe)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
    }

    private static func aCentavos(_ s: String) -> Centavos {
        let limpio = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Int(((Double(limpio) ?? 0) * 100).rounded())
    }
}
