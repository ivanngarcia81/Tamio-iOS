import Foundation
import Supabase

/// **Quién puede qué, en un solo sitio.**
///
/// Los permisos son una cuenta a dos: el ROL de quien entró (`perfiles.rol`) y
/// los interruptores de la IGLESIA (`iglesias.tesorero_*`). Ninguno de los dos
/// basta solo, y por eso no se puede preguntar "¿está encendido el permiso?"
/// desde una pantalla: apagar "eliminar movimientos" no le quita el botón al
/// administrador, y encender "ver el padrón" no se lo da a nadie que ya lo
/// tenía. Repartir esa cuenta por las vistas es cómo se acaba con dos pantallas
/// que responden distinto a la misma pregunta.
///
/// **Esto no es la barrera.** La barrera está en Supabase: el disparador
/// `frenar_borrado_tesorero` deshace la baja que hiciera un tesorero sin
/// permiso, y el RPC `fijar_permisos_tesoreria` rechaza a quien no sea
/// administrador. Lo de aquí evita enseñar botones que el servidor va a
/// rechazar, que es una cortesía, no un control.
struct Permisos {
    let rol: SesionSupabase.Perfil.Rol
    let iglesia: ConfiguracionIglesia

    /// Puede borrar movimientos. Solo se le retira al TESORERO, y solo si la
    /// iglesia lo apagó: es literalmente la condición del disparador.
    var puedeEliminarMovimientos: Bool {
        !(rol == .tesorero && !iglesia.tesoreroPuedeEliminar)
    }

    /// Entra a Membresía, el padrón de Secretaría. Al tesorero solo si la
    /// iglesia se lo abrió; a los demás siempre.
    ///
    /// Ojo con lo que esto NO hace: los miembros se sincronizan igual a todos
    /// los aparatos, porque Aportantes los necesita. Abre una pantalla.
    var vePadron: Bool {
        rol != .tesorero || iglesia.tesoreroVePadron
    }

    /// Cambia los permisos de la iglesia. Solo el administrador, igual que el
    /// RPC: enseñarle los interruptores encendidos a un tesorero que no puede
    /// moverlos es prometerle algo que el servidor le va a negar.
    var administraPermisos: Bool { rol == .administrador }

    /// Los permisos vigentes, de la sesión y de la configuración compartidas.
    @MainActor
    static func vigentes(_ sesion: SesionSupabase?) -> Permisos {
        Permisos(rol: sesion?.perfil.rol ?? .administrador,
                 iglesia: ConfiguracionIglesiaViewModel.compartido.config)
    }
}


/// **Invitar a alguien a la iglesia.**
///
/// El trabajo lo hace la Edge Function `invitar-usuario`, que ya estaba
/// desplegada y la app de iPhone no llamaba: el botón "Enviar invitación"
/// estaba apagado y los tres campos de encima no iban a ninguna parte.
///
/// Las reglas viven allí y no aquí, a propósito: **la iglesia no viaja en la
/// petición** —se lee del perfil de quien invita—, solo un administrador puede
/// invitar, y un correo que ya pertenece a otra congregación se rechaza en vez
/// de mudarlo en silencio. Repetir esas comprobaciones en el cliente daría dos
/// versiones de la misma regla y solo una mandaría.
enum Invitaciones {

    /// Lo que puede contestar la función, traducido. Se traduce **por código**
    /// y no por el texto del mensaje: el servidor responde en español y la app
    /// puede estar en inglés, y comparar contra un mensaje traducido es el
    /// error que ya documenta `Catalogos` para las categorías.
    enum Resultado {
        case invitado
        case unido
        case rolActualizado

        var mensaje: String {
            switch self {
            case .invitado:
                return L.t("Invitación enviada. Le llegará un correo para poner su contraseña.",
                           "Invitation sent. They'll get an email to set their password.")
            case .unido:
                return L.t("Ya tenía cuenta en Tamio y se ha unido a esta iglesia.",
                           "They already had a Tamio account and joined this church.")
            case .rolActualizado:
                return L.t("Ya estaba en esta iglesia; se le cambió el rol.",
                           "They were already in this church; their role was updated.")
            }
        }
    }

    private struct Peticion: Encodable {
        let email: String
        let nombre: String
        let rol: String
    }

    private struct Respuesta: Decodable {
        let ok: Bool?
        let resultado: String?
        let error: String?
        let codigo: String?
    }

    struct Fallo: LocalizedError {
        let texto: String
        var errorDescription: String? { texto }
    }

    static func invitar(correo: String, nombre: String,
                        rol: SesionSupabase.Perfil.Rol) async throws -> Resultado {
        let limpio = correo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard limpio.contains("@"), limpio.contains(".") else {
            throw Fallo(texto: L.t("Ese correo no parece válido.", "That email doesn't look valid."))
        }
        let r: Respuesta = try await supabase.functions.invoke(
            "invitar-usuario",
            options: FunctionInvokeOptions(
                body: Peticion(email: limpio,
                               nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                               rol: rol.rawValue)))

        if let codigo = r.codigo { throw Fallo(texto: explicacion(codigo)) }
        switch r.resultado {
        case "invitado":        return .invitado
        case "unido":           return .unido
        case "rol-actualizado": return .rolActualizado
        default:
            throw Fallo(texto: r.error ?? L.t("No se pudo enviar la invitación.",
                                              "The invitation couldn't be sent."))
        }
    }

    private static func explicacion(_ codigo: String) -> String {
        switch codigo {
        case "solo-admin":
            return L.t("Solo el administrador de la iglesia puede invitar.",
                       "Only the church administrator can invite people.")
        case "otra-iglesia":
            return L.t("Ese correo ya pertenece a otra iglesia. Quien lo tenga debe salir de ella primero.",
                       "That email already belongs to another church. They must leave it first.")
        case "eres-tu":
            return L.t("Ese es tu propio correo.", "That's your own email.")
        case "sin-iglesia":
            return L.t("Tu cuenta no tiene ninguna iglesia asignada.",
                       "Your account isn't assigned to a church.")
        case "correo":
            return L.t("Ese correo no parece válido.", "That email doesn't look valid.")
        case "sin-sesion":
            return L.t("Tu sesión ha caducado. Vuelve a entrar.",
                       "Your session expired. Please sign in again.")
        default:
            return L.t("No se pudo enviar la invitación.", "The invitation couldn't be sent.")
        }
    }
}
