import SwiftUI

/// **Añadir un parentesco, según `handoff7`.**
///
/// Dos secciones: QUIÉN y PARENTESCO. Es la hoja más corta de todas y la única
/// que **depende de que haya alguien elegido en la lista**: un parentesco une a
/// dos personas, así que sin la primera no hay nada que unir. El título lo dice
/// cuando falta, con las palabras del handoff.
///
/// **Los dos extremos son del padrón, y eso no es una limitación de la hoja**:
/// se guarda UNA fila por relación y se lee desde los dos lados, así que un
/// pariente escrito a mano solo existiría en una ficha —y media relación no es
/// una relación—. Si quien falta no viene a la iglesia, el propio handoff dice
/// qué hacer: darle ficha inactiva primero.
struct NuevoPariente: View {

    /// La persona a cuya ficha se le añade. `nil` si no hay ninguna elegida.
    let anfitrion: Miembro?
    let alGuardar: (String, Pariente) -> Void

    @State private var parienteId = ""
    @State private var tipo = "conyuge"
    @State private var intentoGuardar = false
    @State private var padron: [PersonaDelPadron] = []

    private var faltan: [String] {
        parienteId.isEmpty
            ? [L.t("elegir a alguien del padrón", "choosing from the roster")] : []
    }

    var body: some View {
        HojaMac(titulo: anfitrion.map {
                    L.t("Añadir pariente · \($0.nombre)", "Add relative · \($0.nombre)")
                } ?? L.t("Añadir pariente · elige antes a alguien de la lista",
                         "Add relative · pick someone in the list first"),
                rotuloGuardar: L.t("Guardar", "Save"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            quien
            parentesco
        }
        .task { if padron.isEmpty { padron = await padronParaSelector() } }
    }

    private var quien: some View {
        SeccionHoja(
            titulo: L.t("QUIÉN", "WHO"),
            nota: L.t("Si el pariente no se congrega, dale ficha primero: una ficha inactiva no estorba, y así la relación se ve también en su lado.",
                      "If the relative doesn’t attend, give them a profile first: an inactive profile is harmless, and the link then shows on their side too.")
        ) {
            FilaSelector(rotulo: L.t("Del padrón", "From the roster"),
                         valor: $parienteId,
                         opciones: [("", L.t("Elegir…", "Choose…"))]
                            + padron.filter { $0.id != anfitrion?.id }
                                    .map { ($0.id, $0.nombre) })
        }
    }

    private var parentesco: some View {
        SeccionHoja(
            titulo: L.t("PARENTESCO", "RELATIONSHIP"),
            nota: L.t("El parentesco se dice desde esta persona: «Hijo o hija» significa que el pariente es su hijo.",
                      "The relationship is from this person’s point of view: “Child” means the relative is their child.")
        ) {
            // Claves del catálogo, no rótulos: la fila se lee desde las dos
            // fichas y el inverso se busca por la clave.
            FilaSelector(rotulo: L.t("Parentesco", "Relationship"), valor: $tipo,
                         opciones: Parentescos.tipos.map { ($0, Parentescos.etiqueta($0)) })
        }
    }

    private func guardar() -> Bool {
        intentoGuardar = true
        guard let anfitrion, faltan.isEmpty else {
            intentoGuardar = true
            return false
        }
        let nombre = padron.first { $0.id == parienteId }?.nombre ?? ""
        alGuardar(anfitrion.id,
                  Pariente(id: UUID().uuidString, tipo: tipo,
                           parienteId: parienteId, nombre: nombre))
        return true
    }
}
