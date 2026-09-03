import Foundation
import Supabase

/// Un aportante tal y como lo necesita la hoja de captura: quién es y cómo se
/// llama. Deliberadamente más pequeño que `Aportante`, que arrastra historial
/// de aportes y datos fiscales que aquí no pintan nada.
struct AportanteBreve: Identifiable, Hashable {
    let id: String      // members.uid
    let nombre: String
}

/// De dónde salen los nombres del selector de aportante.
protocol AportantesCatalogo {
    func activos() async throws -> [AportanteBreve]
}

struct SupabaseAportantesCatalogo: AportantesCatalogo {
    func activos() async throws -> [AportanteBreve] {
        struct Fila: Decodable { let uid: String; let nombre: String? }
        let filas: [Fila] = try await supabase
            .from("members")
            .select("uid,nombre")
            .eq("church_id", value: churchIdActivo)
            .eq("deleted", value: false)
            .order("nombre")
            .execute()
            .value
        // Una ficha sin nombre no se puede ofrecer en un menú.
        return filas.compactMap { fila in
            guard let nombre = fila.nombre,
                  !nombre.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return AportanteBreve(id: fila.uid, nombre: nombre)
        }
    }
}

struct MockAportantesCatalogo: AportantesCatalogo {
    func activos() async throws -> [AportanteBreve] {
        [AportanteBreve(id: "m1", nombre: "María Hernández Ríos"),
         AportanteBreve(id: "m2", nombre: "Pedro Salas Aguirre"),
         AportanteBreve(id: "m3", nombre: "Ana Lucía Torres"),
         AportanteBreve(id: "m4", nombre: "Familia Ruvalcaba")]
    }
}

func catalogoAportantes() -> AportantesCatalogo {
    ModoRevision.sinLogin ? MockAportantesCatalogo() : SupabaseAportantesCatalogo()
}
