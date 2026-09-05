import SwiftUI

/// Alta de un parentesco. Vive en Secretaría porque el padrón es suyo: en la
/// ficha del aportante (Tesorería) los parentescos solo se consultan.
///
/// **Se elige a la persona del padrón; no se escribe un nombre.** Antes había
/// un campo de texto para "si el pariente no congrega", y ese nombre no tenía
/// dónde guardarse: la tabla une DOS fichas y el nombre se lee de la del otro.
/// Una relación escrita a mano solo existiría en un lado —la ficha del pariente
/// no podría enseñarla— y media relación no es una relación. Para un hijo que
/// no congrega, el camino es darle ficha: una inactiva no estorba, y así la
/// relación es verdad por los dos extremos.
///
/// **Primero quién y después qué es**, en ese orden: el padrón son cientos de
/// nombres y los parentescos son diez, y al revés obligaría a elegir el
/// parentesco antes de saber de quién se habla, que no es como se piensa
/// ("Ana… es mi hermana").
struct NuevoParienteView: View {
    @Environment(\.dismiss) private var dismiss

    private let onGuardar: (Pariente) -> Void

    @State private var tipo: String = Parentescos.tipos.first ?? "conyuge"
    @State private var catalogo: [AportanteBreve] = []
    /// La persona elegida del padrón. Sin ella no hay relación que guardar.
    @State private var miembroId: String?

    init(onGuardar: @escaping (Pariente) -> Void) {
        self.onGuardar = onGuardar
    }

    private var elegido: AportanteBreve? {
        catalogo.first { $0.id == miembroId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L.t("Del padrón", "From the roster"), selection: $miembroId) {
                        Text(L.t("Elegir…", "Choose…")).tag(String?.none)
                        ForEach(catalogo) { m in
                            Text(m.nombre).tag(String?.some(m.id))
                        }
                    }
                } header: {
                    Text(L.t("QUIÉN", "WHO"))
                } footer: {
                    Text(L.t("Si el pariente no congrega, dale ficha primero: una ficha inactiva no estorba, y así la relación se ve también desde la suya.",
                             "If the relative doesn't attend, give them a profile first: an inactive profile is harmless, and the link then shows on their side too."))
                }

                Section {
                    Picker(L.t("Relación", "Relationship"), selection: $tipo) {
                        ForEach(Parentescos.tipos, id: \.self) {
                            Text(Parentescos.etiqueta($0)).tag($0)
                        }
                    }
                } header: {
                    Text(L.t("PARENTESCO", "RELATIONSHIP"))
                } footer: {
                    Text(L.t("La relación es respecto a esta persona: \"Hijo o hija\" significa que el pariente es su hijo.",
                             "The relationship is from this person's point of view: \"Child\" means the relative is their child."))
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
                        guard let elegido else { return }
                        // El id es el de la FILA, no el de la persona: usar el
                        // del pariente convertía en una sola dos relaciones
                        // distintas —y al quitar una se iba la otra.
                        onGuardar(Pariente(id: UUID().uuidString, tipo: tipo,
                                           parienteId: elegido.id, nombre: elegido.nombre))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Paleta.brand)
                    .disabled(elegido == nil)
                }
            }
            .task { catalogo = (try? await catalogoAportantes().activos()) ?? [] }
        }
        .hojaFormulario()
    }
}
