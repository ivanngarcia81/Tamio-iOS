import SwiftUI

/// Hoja "Editar ingreso/gasto" desde la bandeja Por revisar. Los cambios se
/// guardan en el movimiento; el asunto sigue en la bandeja hasta aprobarlo o
/// devolverlo. Chips para categoría, método y aportante, como el handoff.
struct EditarAsuntoView: View {
    @Environment(\.dismiss) private var dismiss

    let r: Revision
    let onGuardar: (_ concepto: String, _ importe: String, _ categoria: String, _ metodo: String, _ aportante: String?) -> Void

    @State private var concepto: String
    @State private var importe: String
    @State private var categoria: String
    @State private var metodo: String
    @State private var aportante: String?

    private let categoriasIngreso = [
        L.t("Diezmo", "Tithe"), L.t("Ofrenda general", "General offering"),
        L.t("Ofrenda misionera", "Mission offering"), L.t("Donativo", "Donation"), L.t("Otros", "Other"),
    ]
    private let categoriasGasto = [
        L.t("Servicios", "Utilities"), L.t("Mantenimiento", "Maintenance"), L.t("Misiones", "Missions"),
        L.t("Materiales", "Supplies"), L.t("Mobiliario", "Furniture"), L.t("Renta", "Rent"), L.t("Otros", "Other"),
    ]
    private let metodos = [L.t("Efectivo", "Cash"), L.t("Transferencia", "Transfer"), L.t("Cheque", "Check")]
    private let aportantes = ["Pedro Salas Aguirre", "Karla Villalobos Ruiz", "María Hernández Ríos", "Ana Lucía Torres Beltrán"]

    init(r: Revision, onGuardar: @escaping (String, String, String, String, String?) -> Void) {
        self.r = r
        self.onGuardar = onGuardar
        _concepto = State(initialValue: r.concepto)
        _importe = State(initialValue: r.editImporte ?? "")
        _categoria = State(initialValue: r.editCategoria ?? "")
        _metodo = State(initialValue: r.editMetodo ?? L.t("Efectivo", "Cash"))
        _aportante = State(initialValue: r.editAportante)
    }

    private var categorias: [String] { r.esGasto ? categoriasGasto : categoriasIngreso }
    private var folioFecha: String {
        let folio = r.campos.first { $0.label == L.t("Folio", "Folio") }?.valor ?? ""
        let fecha = r.campos.first { $0.label == L.t("Fecha", "Date") }?.valor ?? ""
        return [folio.isEmpty ? nil : L.t("Folio ", "Folio ") + folio, fecha.isEmpty ? nil : fecha]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L.t("Los cambios se guardan en el movimiento; el asunto sigue aquí hasta que lo apruebes o lo devuelvas.",
                             "Changes are saved to the entry; the item stays here until you approve or return it."))
                        .font(.caption).foregroundStyle(.secondary)

                    campo(L.t("Concepto", "Concept")) { TextField("", text: $concepto).textFieldStyle(.roundedBorder) }
                    campo(L.t("Importe", "Amount")) {
                        HStack(spacing: 4) {
                            Text("$").foregroundStyle(.secondary)
                            TextField("0.00", text: $importe).keyboardType(.decimalPad)
                        }
                        .padding(8).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    campo(L.t("Categoría", "Category")) { chips(categorias, sel: $categoria) }
                    campo(L.t("Método de pago", "Payment method")) { chips(metodos, sel: $metodo) }
                    if !r.esGasto {
                        campo(L.t("Aportante", "Giver")) { chipsOpcional(aportantes, sel: $aportante) }
                    }

                    Text(folioFecha).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(20)
            }
            .navigationTitle(r.esGasto ? L.t("Editar gasto", "Edit expense") : L.t("Editar ingreso", "Edit income"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("Cancelar", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar cambios", "Save changes")) {
                        onGuardar(concepto, importe, categoria, metodo, r.esGasto ? nil : aportante)
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(concepto.isEmpty || importe.isEmpty)
                }
            }
        }
        .hojaGrande()
    }

    private func campo<C: View>(_ label: String, @ViewBuilder _ contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            contenido()
        }
    }

    private func chips(_ opciones: [String], sel: Binding<String>) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(opciones, id: \.self) { o in pastilla(o, activa: sel.wrappedValue == o) { sel.wrappedValue = o } }
        }
    }
    private func chipsOpcional(_ opciones: [String], sel: Binding<String?>) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(opciones, id: \.self) { o in pastilla(o, activa: sel.wrappedValue == o) { sel.wrappedValue = o } }
        }
    }
    private func pastilla(_ t: String, activa: Bool, _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(t).font(.subheadline.weight(activa ? .semibold : .regular))
                .foregroundStyle(activa ? .white : .primary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(activa ? AnyShapeStyle(Paleta.brand) : AnyShapeStyle(Color(.tertiarySystemFill)), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
