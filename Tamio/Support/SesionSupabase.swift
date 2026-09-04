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
    /// La sesión se restauró desde la caché porque no se pudo consultar el
    /// perfil. Se sigue dentro, pero los repositorios que hablan con la red
    /// fallarán hasta que vuelva la conexión.
    private(set) var modoSinConexion = false

    /// El rol y el nombre de quien ha entrado.
    ///
    /// El rol no es decorativo: los permisos de la iglesia se aplican SOBRE él
    /// —el disparador `frenar_borrado_tesorero` de Supabase solo frena al
    /// `tesorero`, y solo el `administrador` puede cambiar los permisos—, así
    /// que sin saberlo la app no podía respetarlos aunque quisiera. Hasta hoy
    /// no se leía: se pedía únicamente `church_id`.
    private(set) var perfil = Perfil()

    struct Perfil: Equatable {
        var nombre = ""
        var rol: Rol = .administrador

        /// Los tres valores de `perfiles.rol`. Se cae a `administrador` cuando
        /// no se reconoce el texto: es el rol sin restricciones, y quitarle
        /// permisos a alguien por no entender su rol lo dejaría fuera de su
        /// propia app. Los controles de verdad están en el servidor.
        enum Rol: String {
            case tesorero, secretaria, administrador
        }

        /// Iniciales para el cuadrito del perfil. Iba escrito "IG" a mano en
        /// cuatro sitios, junto a un nombre y un correo también escritos a mano.
        var iniciales: String {
            let palabras = nombre.split(separator: " ").filter { $0.count > 1 }
            let letras = palabras.prefix(2).compactMap { $0.first }
            return letras.isEmpty ? "—" : String(letras).uppercased()
        }
    }

    /// La iglesia del perfil autenticado. `perfiles.church_id` es la fuente de
    /// verdad; la constante de `Supabase.swift` solo sirve de arranque.
    private struct PerfilDTO: Decodable {
        let churchId: String?
        let nombre: String?
        let rol: String?
        enum CodingKeys: String, CodingKey { case churchId = "church_id", nombre, rol }
    }

    /// Restaura la sesión persistida, si la hay. La SDK la guarda en el
    /// llavero, así que sobrevive a cerrar la app.
    @MainActor
    func restaurar() async {
        // Modo revisión: se entra sin credenciales. Sin sesión real, RLS
        // devolvería cero filas, así que los repositorios sirven datos de
        // ejemplo (ver `repositorioMovimientos`).
        if ModoRevision.sinLogin {
            // Un perfil de ejemplo, como el resto de los datos del modo: sin
            // él la cabecera de Ajustes saldría sin nombre y no se podría
            // recorrer la pantalla.
            perfil = Perfil(nombre: "Iván García", rol: .administrador)
            estado = .autenticada(churchId: churchIdActivo)
            return
        }
        do {
            let sesion = try await supabase.auth.session
            await adoptar(uid: sesion.user.id.uuidString, permitirCache: true)
        } catch {
            // Sin sesión guardada, o el refresco del token no llegó al
            // servidor. En ninguno de los dos casos hay nada que restaurar,
            // pero el mensaje distingue el fallo de red del "no has entrado".
            if Self.esFalloDeRed(error) {
                self.error = Self.mensajeSinConexion
            }
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
            // En un inicio de sesión manual no se acepta la caché: el usuario
            // puede ser otro y hay que confirmar su iglesia contra el servidor.
            await adoptar(uid: sesion.user.id.uuidString, permitirCache: false)
        } catch {
            self.error = mensaje(error)
            estado = .sinSesion
        }
        ocupada = false
    }

    @MainActor
    func cerrarSesion() async {
        try? await supabase.auth.signOut()
        // Los datos de una iglesia no pueden quedarse en el aparato para el
        // siguiente que entre.
        try? BaseLocal.compartida.limpiar()
        Self.olvidarCache()
        perfil = Perfil()
        modoSinConexion = false
        estado = .sinSesion
    }

    /// Lee el perfil para saber a qué iglesia pertenece el usuario y deja el
    /// `churchIdActivo` listo para los repositorios.
    ///
    /// La distinción que importa: que el servidor conteste "este usuario no
    /// tiene perfil" es motivo para cerrar la sesión, pero que no se pueda
    /// preguntar no lo es. Antes ambos casos caían en la misma rama, así que
    /// un fallo de red pasajero echaba al usuario de la app diciéndole que no
    /// tenía perfil asignado.
    @MainActor
    private func adoptar(uid: String, permitirCache: Bool) async {
        let leido: (churchId: String, perfil: Perfil)?
        do {
            leido = try await leerPerfil(uid: uid)
        } catch {
            // No se pudo preguntar. La sesión sigue siendo válida.
            if permitirCache, let guardado = Self.cache(uid: uid) {
                churchIdActivo = guardado.churchId
                perfil = guardado.perfil
                modoSinConexion = true
                self.error = nil
                estado = .autenticada(churchId: guardado.churchId)
            } else {
                self.error = Self.mensajeSinConexion
                estado = .sinSesion
            }
            return
        }

        guard let leido else {
            // El servidor respondió y de verdad no hay perfil: RLS le negaría
            // todo, así que es más honesto tratarlo como sesión fallida que
            // dejar pantallas vacías.
            error = L.t("Tu usuario no tiene perfil asignado a ninguna iglesia.",
                        "Your user has no profile assigned to a church.")
            try? await supabase.auth.signOut()
            Self.olvidarCache()
            estado = .sinSesion
            return
        }
        churchIdActivo = leido.churchId
        perfil = leido.perfil
        Self.guardarCache(uid: uid, churchId: leido.churchId, perfil: leido.perfil)
        modoSinConexion = false
        error = nil
        estado = .autenticada(churchId: leido.churchId)
    }

    /// `nil` significa "el servidor contestó y este usuario no tiene perfil".
    /// Se usa `limit(1)` en vez de `single()` a propósito: `single()` convierte
    /// las cero filas en un error, que es justo lo que hay que poder separar
    /// de un fallo de conexión.
    private func leerPerfil(uid: String) async throws -> (churchId: String, perfil: Perfil)? {
        let filas: [PerfilDTO] = try await supabase
            .from("perfiles")
            .select("church_id, nombre, rol")
            .eq("id", value: uid)
            .limit(1)
            .execute()
            .value
        guard let fila = filas.first, let id = fila.churchId, !id.isEmpty else { return nil }
        return (id, Perfil(nombre: fila.nombre ?? "",
                           rol: Perfil.Rol(rawValue: fila.rol ?? "") ?? .administrador))
    }

    // MARK: - Caché del perfil

    // El `church_id` se guarda junto al uid del dueño para no reutilizar la
    // iglesia de un usuario con la sesión de otro.
    private static let claveUid = "sesion.perfil.uid"
    private static let claveChurch = "sesion.perfil.churchId"
    private static let claveNombre = "sesion.perfil.nombre"
    private static let claveRol = "sesion.perfil.rol"

    private static func guardarCache(uid: String, churchId: String, perfil: Perfil) {
        let d = UserDefaults.standard
        d.set(uid, forKey: claveUid)
        d.set(churchId, forKey: claveChurch)
        d.set(perfil.nombre, forKey: claveNombre)
        d.set(perfil.rol.rawValue, forKey: claveRol)
    }

    private static func cache(uid: String) -> (churchId: String, perfil: Perfil)? {
        let d = UserDefaults.standard
        guard d.string(forKey: claveUid) == uid,
              let id = d.string(forKey: claveChurch), !id.isEmpty else { return nil }
        return (id, Perfil(nombre: d.string(forKey: claveNombre) ?? "",
                           rol: Rol(d.string(forKey: claveRol)) ))
    }

    private static func Rol(_ texto: String?) -> Perfil.Rol {
        Perfil.Rol(rawValue: texto ?? "") ?? .administrador
    }

    private static func olvidarCache() {
        let d = UserDefaults.standard
        for clave in [claveUid, claveChurch, claveNombre, claveRol] {
            d.removeObject(forKey: clave)
        }
    }

    // MARK: - Mensajes

    private static var mensajeSinConexion: String {
        L.t("No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.",
            "Couldn't reach the server. Check your connection and try again.")
    }

    private static func esFalloDeRed(_ e: Error) -> Bool {
        if e is URLError { return true }
        let ns = e as NSError
        return ns.domain == NSURLErrorDomain
    }

    private func mensaje(_ e: Error) -> String {
        if Self.esFalloDeRed(e) { return Self.mensajeSinConexion }
        let texto = e.localizedDescription
        if texto.localizedCaseInsensitiveContains("invalid login") {
            return L.t("Correo o contraseña incorrectos.", "Wrong email or password.")
        }
        return texto
    }
}
