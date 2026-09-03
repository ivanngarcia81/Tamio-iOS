import Foundation
import Observation
import Supabase

/// Sesión de Supabase de la app. Las políticas RLS de `transactions` y
/// `members` exigen `auth.uid()` resuelto contra la tabla `perfiles`, así que
/// sin sesión iniciada el backend no devuelve ninguna fila ni acepta escrituras.
/// De ahí que la sesión sea un requisito para que los repositorios reales
/// funcionen, no un extra.
@Observable
final class SesionSupabase {

    enum Estado: Equatable {
        /// Comprobando si hay sesión guardada del arranque anterior.
        case comprobando
        case sinSesion
        case autenticada(churchId: String)
    }

    private(set) var estado: Estado = .comprobando
    /// Último fallo de autenticación, para mostrarlo en la pantalla de acceso.
    private(set) var error: String?
    private(set) var ocupada = false

    /// La iglesia del perfil autenticado. `perfiles.church_id` es la fuente de
    /// verdad; la constante de `Supabase.swift` solo sirve de arranque.
    private struct PerfilDTO: Decodable {
        let churchId: String?
        enum CodingKeys: String, CodingKey { case churchId = "church_id" }
    }

    /// Restaura la sesión persistida, si la hay. La SDK la guarda en el
    /// llavero, así que sobrevive a cerrar la app.
    @MainActor
    func restaurar() async {
        do {
            let sesion = try await supabase.auth.session
            await adoptar(uid: sesion.user.id.uuidString)
        } catch {
            estado = .sinSesion
        }
    }

    @MainActor
    func iniciarSesion(correo: String, contrasena: String) async {
        guard !ocupada else { return }
        ocupada = true
        error = nil
        do {
            let sesion = try await supabase.auth.signIn(email: correo, password: contrasena)
            await adoptar(uid: sesion.user.id.uuidString)
        } catch {
            self.error = mensaje(error)
            estado = .sinSesion
        }
        ocupada = false
    }

    @MainActor
    func cerrarSesion() async {
        try? await supabase.auth.signOut()
        estado = .sinSesion
    }

    /// Lee el perfil para saber a qué iglesia pertenece el usuario y deja el
    /// `churchIdActivo` listo para los repositorios.
    @MainActor
    private func adoptar(uid: String) async {
        let perfil: PerfilDTO? = try? await supabase
            .from("perfiles")
            .select("church_id")
            .eq("id", value: uid)
            .single()
            .execute()
            .value

        guard let id = perfil?.churchId, !id.isEmpty else {
            // Usuario válido sin perfil: RLS le negaría todo, así que es más
            // honesto tratarlo como sesión fallida que dejar pantallas vacías.
            error = L.t("Tu usuario no tiene perfil asignado a ninguna iglesia.",
                        "Your user has no profile assigned to a church.")
            try? await supabase.auth.signOut()
            estado = .sinSesion
            return
        }
        churchIdActivo = id
        estado = .autenticada(churchId: id)
    }

    private func mensaje(_ e: Error) -> String {
        let texto = e.localizedDescription
        if texto.localizedCaseInsensitiveContains("invalid login") {
            return L.t("Correo o contraseña incorrectos.", "Wrong email or password.")
        }
        return texto
    }
}
