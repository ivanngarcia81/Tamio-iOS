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

    /// **Rótulo a la izquierda y valor a la derecha, no un `placeholder`.**
    ///
    /// El primer argumento de `TextField` es el marcador de posición, y un
    /// marcador SOLO se ve con el campo vacío. Los nueve campos de esta hoja lo
    /// usaban de rótulo, así que en cuanto tenían valor dejaban de decir qué
    /// eran: al EDITAR un aportante la hoja entera era una columna de valores
    /// sueltos —"2018", "81 1010 2020", "TOBA880101AB1", "Married", "2016"—,
    /// y en el alta pasaba ya con "Miembro desde", que nace con el año puesto.
    ///
    /// Y no era solo de mirar: el volcado de accesibilidad daba los nueve
    /// campos con la etiqueta **vacía**, o sea que VoiceOver leía el valor sin
    /// decir de qué campo era. `LabeledContent` arregla las dos cosas de una
    /// vez, y de paso las filas se parecen a las dos que ya tenían rótulo, los
    /// `Picker` de "Rol" y "Aporta".
    private func campo(_ rotulo: String, _ texto: Binding<String>) -> some View {
        LabeledContent(rotulo) {
            // El marcador de posición va VACÍO: con el rótulo ya a la
            // izquierda, ponerlo también aquí lo escribía dos veces en la misma
            // fila —"Nombre completo … Nombre completo"— mientras el campo
            // estuviera sin llenar, que en el alta es siempre.
            TextField("", text: texto)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
    private let roles = [L.t("diezmo", "tithe"), L.t("donador", "donor")]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    campo(L.t("Nombre completo", "Full name"), $nombre)
                    Picker(L.t("Rol", "Role"), selection: $rol) {
                        ForEach(roles, id: \.self) { Text($0).tag($0) }
                    }
                    campo(L.t("Miembro desde", "Member since"), $miembroDesde)
                    Picker(L.t("Aporta", "Gives"), selection: $frecuencia) {
                        ForEach(FrecuenciaAporte.allCases) { Text($0.etiqueta).tag($0) }
                    }
                }
                Section {
                    campo(L.t("Teléfono", "Phone"), $telefono).keyboardType(.phonePad)
                    campo(L.t("Correo", "Email"), $correo)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    campo(L.t("ID fiscal", "Tax ID"), $idFiscal).textInputAutocapitalization(.characters)
                }
                Section {
                    campo(L.t("Nacimiento", "Birth"), $nacimiento)
                    campo(L.t("Dirección", "Address"), $direccion)
                    campo(L.t("Estado civil", "Marital status"), $estadoCivil)
                    campo(L.t("Congrega desde", "Attends since"), $congregaDesde)
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
        .hojaFormulario()
    }

    private func guardar() {
        let a = Aportante(
            id: existente?.id ?? "",
            nombre: nombre, estado: existente?.estado ?? .activo, rol: rol, miembroDesde: miembroDesde,
            telefono: telefono, correo: correo, nacimiento: nacimiento,
            direccion: direccion, estadoCivil: estadoCivil, idFiscal: idFiscal,
            congregaDesde: congregaDesde,
            frecuencia: frecuencia,
            aportes: existente?.aportes ?? [],
            familia: existente?.familia ?? []
        )
        onGuardar(a)
        dismiss()
    }
}
