import SwiftUI

/// Formulario de nuevo/editar aportante. Devuelve el `Aportante` armado por
/// `onGuardar`; la vista padre decide crear o actualizar (vía repositorio).
struct NuevoAportanteView: View {
    @Environment(\.dismiss) private var dismiss

    private let existente: Aportante?
    private let onGuardar: (Aportante) -> Void

    @State private var nombre: String
    @State private var rol: String
    @State private var miembroDesde: String
    @State private var telefono: String
    @State private var correo: String
    @State private var nacimiento: String
    @State private var direccion: String
    @State private var estadoCivil: String
    @State private var idFiscal: String
    @State private var congregaDesde: String
    /// Bautismo, ministerios y cargos ya no se editan aquí: son del padrón, y
    /// quien lo lleva es Secretaría. Seguían apareciendo en una hoja de
    /// Tesorería, donde nadie va a mantenerlos.
    @State private var frecuencia: FrecuenciaAporte

    init(existente: Aportante?, onGuardar: @escaping (Aportante) -> Void) {
        self.existente = existente
        self.onGuardar = onGuardar
        _nombre = State(initialValue: existente?.nombre ?? "")
        _rol = State(initialValue: existente?.rol ?? L.t("diezmo", "tithe"))
        _miembroDesde = State(initialValue: existente?.miembroDesde ?? "2026")
        _telefono = State(initialValue: existente?.telefono ?? "")
        _correo = State(initialValue: existente?.correo ?? "")
        _nacimiento = State(initialValue: existente?.nacimiento ?? "")
        _direccion = State(initialValue: existente?.direccion ?? "")
        _estadoCivil = State(initialValue: existente?.estadoCivil ?? "")
        _idFiscal = State(initialValue: existente?.idFiscal ?? "")
        _congregaDesde = State(initialValue: existente?.congregaDesde ?? "")
        _frecuencia = State(initialValue: existente?.frecuencia ?? .semanal)
    }

    private var editando: Bool { existente != nil }
    private let roles = [L.t("diezmo", "tithe"), L.t("donador", "donor")]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.t("Nombre completo", "Full name"), text: $nombre)
                    Picker(L.t("Rol", "Role"), selection: $rol) {
                        ForEach(roles, id: \.self) { Text($0).tag($0) }
                    }
                    TextField(L.t("Miembro desde", "Member since"), text: $miembroDesde)
                    Picker(L.t("Aporta", "Gives"), selection: $frecuencia) {
                        ForEach(FrecuenciaAporte.allCases) { Text($0.etiqueta).tag($0) }
                    }
                }
                Section {
                    TextField(L.t("Teléfono", "Phone"), text: $telefono).keyboardType(.phonePad)
                    TextField(L.t("Correo", "Email"), text: $correo).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField(L.t("ID fiscal", "Tax ID"), text: $idFiscal).textInputAutocapitalization(.characters)
                }
                Section {
                    TextField(L.t("Nacimiento", "Birth"), text: $nacimiento)
                    TextField(L.t("Dirección", "Address"), text: $direccion)
                    TextField(L.t("Estado civil", "Marital status"), text: $estadoCivil)
                    TextField(L.t("Congrega desde", "Attends since"), text: $congregaDesde)
                }
            }
            .navigationTitle(editando ? L.t("Editar aportante", "Edit giver") : L.t("Nuevo aportante", "New giver"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("Cancelar", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("Guardar", "Save")) { guardar() }
                        .fontWeight(.semibold).tint(Paleta.brand)
                        .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .hojaGrande()
    }

    private func guardar() {
        let a = Aportante(
            id: existente?.id ?? "",
            nombre: nombre, estado: existente?.estado ?? .activo, rol: rol, miembroDesde: miembroDesde,
            telefono: telefono, correo: correo, nacimiento: nacimiento,
            direccion: direccion, estadoCivil: estadoCivil, idFiscal: idFiscal,
            congregaDesde: congregaDesde,
            frecuencia: frecuencia,
            aportesTotal: existente?.aportesTotal ?? 0,
            aportesPromedio: existente?.aportesPromedio ?? L.t("Sin aportes aún", "No giving yet"),
            aportesSerie: existente?.aportesSerie ?? [],
            aportes: existente?.aportes ?? [],
            familia: existente?.familia ?? []
        )
        onGuardar(a)
        dismiss()
    }
}
