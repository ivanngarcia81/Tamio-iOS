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

/// **El padrón que ya está en el teléfono.** Es el mismo del que salen los tres
/// selectores de Secretaría (`padronParaSelector()`), y por eso da los mismos
/// nombres que la pantalla de Membresía.
///
/// Sustituye a `SupabaseAportantesCatalogo`, que preguntaba a la red cada vez
/// que se abría la hoja de captura: sin señal el menú de aportante salía vacío
/// y el diezmo se quedaba sin persona, que es justo lo que esta app existe para
/// evitar —"el tesorero captura el sobre en el templo, con señal o sin ella"—.
/// El padrón ya baja y se guarda; no hacía falta ir a buscarlo otra vez.
struct OfflineAportantesCatalogo: AportantesCatalogo {
    func activos() async throws -> [AportanteBreve] {
        await padronParaSelector().map { AportanteBreve(id: $0.id, nombre: $0.nombre) }
    }
}

/// El catálogo contra la red. **Ya no lo usa nadie**: se conserva porque es el
/// único sitio donde está escrita la consulta a `members` para un selector, y
/// borrarlo obligaría a reescribirla el día que haga falta buscar en el padrón
/// de otra iglesia.
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
         AportanteBreve(id: "m3", nombre: "Ana Lucía Torres")]
    }
}

func catalogoAportantes() -> AportantesCatalogo {
    ModoRevision.sinLogin ? MockAportantesCatalogo() : OfflineAportantesCatalogo()
}
