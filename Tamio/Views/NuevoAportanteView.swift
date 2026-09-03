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
    @State private var bautismo: String
    @State private var ministerios: String
    @State private var cargos: String

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
        _bautismo = State(initialValue: existente?.bautismo ?? "")
        _ministerios = State(initialValue: existente?.ministerios ?? "")
        _cargos = State(initialValue: existente?.cargos ?? "")
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
                    TextField(L.t("Bautismo", "Baptism"), text: $bautismo)
                    TextField(L.t("Ministerios", "Ministries"), text: $ministerios)
                    TextField(L.t("Cargos", "Roles"), text: $cargos)
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
            bautizadoAnio: L.t("Bautizado \(miembroDesde)", "Baptized \(miembroDesde)"),
            ministerios: ministerios, cargos: cargos,
            telefono: telefono, correo: correo, nacimiento: nacimiento,
            direccion: direccion, estadoCivil: estadoCivil, idFiscal: idFiscal,
            congregaDesde: congregaDesde, bautismo: bautismo,
            aportesTotal: existente?.aportesTotal ?? 0,
            aportesPromedio: existente?.aportesPromedio ?? L.t("Sin aportes aún", "No giving yet"),
            aportesSerie: existente?.aportesSerie ?? [],
            aportes: existente?.aportes ?? [],
            familia: existente?.familia ?? [],
            serviciosRegistrados: existente?.serviciosRegistrados ?? 0,
            presencias: existente?.presencias ?? "0 · 0%",
            ultimaVisita: existente?.ultimaVisita ?? "—"
        )
        onGuardar(a)
        dismiss()
    }
}
