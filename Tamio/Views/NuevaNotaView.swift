import SwiftUI

/// Hoja para escribir una nota a mano en el Registro. Devuelve texto + área;
/// la vista padre la agrega vía el ViewModel/repositorio.
struct NuevaNotaView: View {
    @Environment(\.dismiss) private var dismiss

    let onGuardar: (_ texto: String, _ area: ApunteArea) -> Void

    @State private var texto = ""
    @State private var area: ApunteArea = .tesoreria

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L.t("Área", "Area"), selection: $area) {
                        Text(L.t("Tesorería", "Treasury")).tag(ApunteArea.tesoreria)
                        Text(L.t("Secretaría", "Secretary")).tag(ApunteArea.secretaria)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    // "Manual note" y no "Hand note": lo segundo es la traducción palabra
                    // por palabra de "nota a mano" y en inglés no se dice. Lo que
                    // distingue a estas del resto del registro es que las escribe
                    // una persona en vez de anotarlas la app sola, y a eso en inglés
                    // se le llama "manual".
                    Text(L.t("Nota a mano", "Manual note"))
                }

                Section {
                    TextField(L.t("Escribe lo que pasó…", "Write what happened…"),
                              text: $texto, axis: .vertical)
                        .lineLimit(4...10)
                } footer: {
                    Text(L.t("Las notas quedan guardadas en el registro y no se editan ni se borran.",
                             "Notes are kept in the log and are not edited or deleted."))
                }
            }
            .navigationTitle(L.t("Escribir una nota", "Write a note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) {
                        onGuardar(texto.trimmingCharacters(in: .whitespacesAndNewlines), area)
                        dismiss()
                    }
                    .fontWeight(.semibold).tint(Paleta.brand)
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .hojaFormulario()
    }
}
