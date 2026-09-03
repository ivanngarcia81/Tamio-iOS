import SwiftUI

/// Hoja "Editar ingreso/gasto" desde la bandeja Por revisar.
///
/// Antes se construía con un helper `campo(_:)` propio: `TextField` con
/// `.roundedBorder`, chips a mano, y dos estilos de caja distintos dentro de la
/// misma hoja (Concepto con borde blanco, Importe con relleno gris). Al lado de
/// la hoja de alta —que sí usa `Form` con `Section`, `Picker` y `DatePicker`—
/// una parecía app de iOS y la otra un formulario web. Ahora las dos son el
/// mismo `Form`, con las mismas secciones y los mismos controles.
struct EditarAsuntoView: View {
    @Environment(\.dismiss) private var dismiss

    let r: Revision
    let onGuardar: (_ concepto: String, _ importe: String, _ categoria: String,
                    _ metodo: String, _ aportante: String?, _ fecha: Date) -> Void

    @State private var concepto: String
    @State private var importe: String
    @State private var categoria: String
    @State private var metodo: String
    @State private var aportante: String?
    @State private var fecha: Date
    @FocusState private var importeEnfocado: Bool

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

    /// Centinela de "sin aportante" en el Picker, como en la hoja de alta.
    private static let sinAsignar = L.t("Sin asignar", "Unassigned")

    init(r: Revision,
         onGuardar: @escaping (String, String, String, String, String?, Date) -> Void) {
        self.r = r
        self.onGuardar = onGuardar
        _concepto = State(initialValue: r.concepto)
        _importe = State(initialValue: r.editImporte ?? "")
        let cats = r.esGasto
            ? [L.t("Servicios", "Utilities"), L.t("Mantenimiento", "Maintenance"), L.t("Misiones", "Missions"),
               L.t("Materiales", "Supplies"), L.t("Mobiliario", "Furniture"), L.t("Renta", "Rent"), L.t("Otros", "Other")]
            : [L.t("Diezmo", "Tithe"), L.t("Ofrenda general", "General offering"),
               L.t("Ofrenda misionera", "Mission offering"), L.t("Donativo", "Donation"), L.t("Otros", "Other")]
        // Un Picker necesita que la selección exista entre sus opciones; el
        // asunto puede llegar sin categoría ("Sin categoría", en rojo).
        let catInicial = r.editCategoria.flatMap { cats.contains($0) ? $0 : nil } ?? (cats.first ?? "")
        _categoria = State(initialValue: catInicial)
        _metodo = State(initialValue: r.editMetodo ?? L.t("Efectivo", "Cash"))
        _aportante = State(initialValue: r.editAportante)
        // La fecha sale del campo "Fecha" del asunto. Esta hoja se abre desde
        // el ítem marcado como duplicado, donde corregirla es lo más probable.
        let textoFecha = r.campos.first { $0.label == L.t("Fecha", "Date") }?.valor ?? ""
        _fecha = State(initialValue: Fechas.desdeSemilla(textoFecha) ?? Date())
    }

    private var categorias: [String] { r.esGasto ? categoriasGasto : categoriasIngreso }
    private var folio: String {
        r.campos.first { $0.label == L.t("Folio", "Folio") }?.valor ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $importe)
                            .keyboardType(.decimalPad)
                            .focused($importeEnfocado)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                } header: {
                    Text(L.t("IMPORTE", "AMOUNT"))
                } footer: {
                    Text(L.t("Los cambios se guardan en el movimiento; el asunto sigue en la bandeja hasta que lo resuelvas.",
                             "Changes are saved to the entry; the item stays in the tray until you resolve it."))
                }

                Section(header: Text(L.t("DETALLE", "DETAILS"))) {
                    TextField(L.t("Concepto", "Concept"), text: $concepto)
                        .autocorrectionDisabled()
                    Picker(r.esGasto ? L.t("Categoría", "Category")
                                     : L.t("Tipo de ingreso", "Income type"),
                           selection: $categoria) {
                        ForEach(categorias, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    DatePicker(L.t("Fecha", "Date"), selection: $fecha, displayedComponents: .date)
                    Picker(L.t("Método de pago", "Payment method"), selection: $metodo) {
                        ForEach(metodos, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                if !r.esGasto {
                    Section(header: Text(L.t("APORTANTE", "CONTRIBUTOR"))) {
                        Picker(L.t("Aportante", "Giver"), selection: aportanteBinding) {
                            Text(Self.sinAsignar).tag(Self.sinAsignar)
                            ForEach(aportantes, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if !folio.isEmpty {
                    Section { } footer: {
                        Text(L.t("Folio \(folio)", "Folio \(folio)"))
                    }
                }
            }
            .navigationTitle(r.esGasto ? L.t("Editar gasto", "Edit expense") : L.t("Editar ingreso", "Edit income"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("Cancelar", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar cambios", "Save changes")) {
                        onGuardar(concepto, importe, categoria, metodo,
                                  r.esGasto ? nil : aportante, fecha)
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(concepto.isEmpty || importe.isEmpty)
                }
            }
        }
        // Formulario corto: media pantalla basta, y se puede expandir. Antes
        // ocupaba la pantalla completa y dejaba medio lienzo vacío.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// El Picker trabaja con String; el modelo guarda `nil` cuando no hay
    /// aportante asignado.
    private var aportanteBinding: Binding<String> {
        Binding(get: { aportante ?? Self.sinAsignar },
                set: { aportante = $0 == Self.sinAsignar ? nil : $0 })
    }
}
