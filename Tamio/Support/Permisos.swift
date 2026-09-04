import Foundation

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
