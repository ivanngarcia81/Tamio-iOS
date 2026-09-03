import SwiftUI

/// Alta de un parentesco. Vive en Secretaría porque el padrón es suyo: en la
/// ficha del aportante (Tesorería) los parentescos solo se consultan.
struct NuevoParienteView: View {
    @Environment(\.dismiss) private var dismiss

    private let onGuardar: (Pariente) -> Void

    @State private var relacion: String
    @State private var nombre = ""
    @State private var catalogo: [AportanteBreve] = []
    /// La persona elegida del padrón, si la hay. Un pariente puede no estar en
    /// la congregación —un hijo pequeño, un cónyuge que no congrega— así que
    /// también se acepta un nombre escrito a mano.
    @State private var miembroId: String?

    /// Relaciones habituales. La lista se queda corta a propósito: es un
    /// catálogo cerrado para que "Cónyuge", "cónyuge" y "Esposa" no acaben
    /// siendo tres relaciones distintas en la base.
    private static var relaciones: [String] {
        [L.t("Cónyuge", "Spouse"), L.t("Hijo", "Son"), L.t("Hija", "Daughter"),
         L.t("Padre", "Father"), L.t("Madre", "Mother"),
         L.t("Hermano", "Brother"), L.t("Hermana", "Sister"),
         L.t("Otro", "Other")]
    }

    init(onGuardar: @escaping (Pariente) -> Void) {
        self.onGuardar = onGuardar
        _relacion = State(initialValue: Self.relaciones.first ?? "")
    }

    private var nombreElegido: String {
        if let miembroId, let m = catalogo.first(where: { $0.id == miembroId }) { return m.nombre }
        return nombre.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L.t("Relación", "Relationship"), selection: $relacion) {
                        ForEach(Self.relaciones, id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text(L.t("PARENTESCO", "RELATIONSHIP"))
                } footer: {
                    Text(L.t("La relación es respecto a esta persona: \"Hijo\" significa que el pariente es su hijo.",
                             "The relationship is from this person's point of view: \"Son\" means the relative is their son."))
                }

                Section {
                    Picker(L.t("Del padrón", "From the roster"), selection: $miembroId) {
                        Text(L.t("Ninguno", "None")).tag(String?.none)
                        ForEach(catalogo) { m in
                            Text(m.nombre).tag(String?.some(m.id))
                        }
                    }
                    if miembroId == nil {
                        TextField(L.t("Nombre", "Name"), text: $nombre)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text(L.t("QUIÉN", "WHO"))
                } footer: {
                    Text(L.t("Si el pariente no congrega, escribe su nombre: se guarda sin ficha en el padrón.",
                             "If the relative doesn't attend, type their name: saved without a roster profile."))
                }
            }
            .navigationTitle(L.t("Añadir pariente", "Add relative"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) {
                        onGuardar(Pariente(id: miembroId ?? UUID().uuidString,
                                           relacion: relacion,
                                           nombre: nombreElegido))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Paleta.brand)
                    .disabled(nombreElegido.isEmpty)
                }
            }
            .task { catalogo = (try? await catalogoAportantes().activos()) ?? [] }
        }
        .hojaGrande()
    }
}
