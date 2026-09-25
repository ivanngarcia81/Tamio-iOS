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
    /// Correo y código de recuperación ya canjeados, para no volver a
    /// mandarlos si falla lo de después (ver `cambiarContrasena`).
    @ObservationIgnored private var codigoCanjeado: String?

    /// El rol y el nombre de quien ha entrado.
    ///
    /// El rol no es decorativo: los permisos de la iglesia se aplican SOBRE él
    /// —el disparador `frenar_borrado_tesorero` de Supabase solo frena al
    /// `tesorero`, y solo el `administrador` puede cambiar los permisos—, así
    /// que sin saberlo la app no podía respetarlos aunque quisiera. Hasta hoy
    /// no se leía: se pedía únicamente `church_id`.
    private(set) var perfil = Perfil()

    struct Perfil: Equatable {
        /// **El `auth.uid()` de esta persona.** Se añadió para poder marcar
        /// cuál de las filas del equipo eres tú en Acceso y áreas: la lista
        /// viene del servidor y no trae esa marca. No se guarda en la caché
        /// —la caché se busca POR uid, así que ya lo tienes en la mano al
        /// leerla— y en modo revisión se queda vacío, que allí no hay equipo.
        var id = ""
        var nombre = ""
        /// El correo no está en `perfiles`: sale del usuario de Auth, que es
        /// quien lo tiene. Iba escrito a mano en tres pantallas.
        var correo = ""
        var rol: Rol = .administrador

        /// Cómo se firma lo que esta persona captura: el autor de un
        /// movimiento, de un apunte del registro. Si el perfil no trae nombre
        /// se usa el correo antes que dejarlo en blanco; una auditoría sin
        /// autor no sirve para nada.
        var firma: String {
            let n = nombre.trimmingCharacters(in: .whitespaces)
            return n.isEmpty ? correo : n
        }

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
            perfil = Perfil(nombre: "Iván García", correo: "ig07644@gmail.com",
                            rol: .administrador)
            estado = .autenticada(churchId: churchIdActivo)
            return
        }
        do {
            // **Con plazo, y no es paranoia: se midió colgado.**
            //
            // `auth.session` lee el llavero, y esa lectura se puede quedar
            // ESPERANDO en vez de fallar —en el Mac, con `SecItemCopyMatching`
            // bloqueado tras un diálogo de permiso que la app no ve—. Cuando
            // se bloquea no hay `catch` que valga: el `estado` se queda en
            // `.comprobando` y `TamioMacApp` enseña un `ProgressView()` para
            // siempre, sin aviso, sin botón y sin pantalla de acceso. Le pasa
            // igual a quien tenga el llavero bloqueado o venga de restaurar
            // una copia de seguridad.
            //
            // Con el plazo, lo peor que ocurre es que se pida entrar otra vez,
            // que es una molestia con salida.
            let sesion = try await Self.conPlazo(segundos: 12) {
                try await supabase.auth.session
            }
            await adoptar(uid: sesion.user.id.uuidString,
                          correo: sesion.user.email ?? "", permitirCache: true)
        } catch is PlazoAgotado {
            // No es "no has entrado" ni es la red: es que no se pudo leer la
            // sesión guardada. Decirlo con esas palabras, porque la salida
            // —volver a entrar— no se le ocurre a nadie mirando un reloj.
            self.error = L.t("No se pudo leer la sesión guardada. Entra otra vez.",
                             "Couldn't read the saved session. Please sign in again.")
            estado = .sinSesion
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

    /// Se agotó el plazo de `conPlazo`. Tipo propio y no un `CancellationError`
    /// para poder distinguirlo del cierre normal de una tarea.
    struct PlazoAgotado: Error {}

    /// **Corre `cuerpo` con un tope de tiempo, ABANDONÁNDOLO si se pasa.**
    ///
    /// La primera versión de esto era un `withThrowingTaskGroup` que corría el
    /// cuerpo contra un `Task.sleep` y se quedaba con el que llegara antes. No
    /// sirve, y el fallo es fino: **un grupo espera a TODOS sus hijos antes de
    /// propagar el error**. Los cancela, sí, pero una llamada que no atiende la
    /// cancelación —`SecItemCopyMatching` bloqueado dentro del llavero es
    /// exactamente eso— no se entera, y el grupo se queda esperándola. O sea
    /// que el plazo se cumplía y la función se colgaba igual. Medido: la prueba
    /// se quedó parada sin imprimir nada hasta que se la mató.
    ///
    /// Con una continuación y una caja que solo deja entregar una vez, el que
    /// llega segundo no hace nada y **a la tarea perdida no la espera nadie**.
    /// Seguirá ahí hasta que el sistema la suelte, y da igual: lo que importa
    /// es que quien está delante reciba una pantalla con la que pueda hacer
    /// algo.
    private static func conPlazo<T: Sendable>(
        segundos: Double,
        _ cuerpo: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let caja = Entrega<T>()
        return try await withCheckedThrowingContinuation { cont in
            Task.detached {
                do { await caja.entregar(cont, .success(try await cuerpo())) }
                catch { await caja.entregar(cont, .failure(error)) }
            }
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
                await caja.entregar(cont, .failure(PlazoAgotado()))
            }
        }
    }

    /// Reanudar una continuación dos veces es un fallo fatal, y aquí hay dos
    /// tareas compitiendo por reanudarla. El actor serializa y la bandera deja
    /// pasar solo a la primera.
    private actor Entrega<T: Sendable> {
        private var entregado = false
        func entregar(_ cont: CheckedContinuation<T, Error>, _ r: Result<T, Error>) {
            guard !entregado else { return }
            entregado = true
            cont.resume(with: r)
        }
    }

    /// Quita el aviso del último intento en cuanto se corrige un campo: si se
    /// queda, parece que lo recién escrito también está mal.
    @MainActor
    func limpiarError() { if error != nil { error = nil } }

    @MainActor
    func iniciarSesion(correo: String, contrasena: String) async {
        guard !ocupada else { return }
        ocupada = true
        error = nil
        do {
            let sesion = try await supabase.auth.signIn(email: correo, password: contrasena)
            // En un inicio de sesión manual no se acepta la caché: el usuario
            // puede ser otro y hay que confirmar su iglesia contra el servidor.
            await adoptar(uid: sesion.user.id.uuidString,
                          correo: sesion.user.email ?? "", permitirCache: false)
        } catch {
            self.error = mensaje(error)
            estado = .sinSesion
        }
        ocupada = false
    }

    // MARK: - Recuperar la contraseña

    /// **Paso 1: que Supabase mande un código al correo** (8 cifras hoy: lo fija
    /// Auth → Email OTP Length, no la app).
    ///
    /// Es el mismo `resetPasswordForEmail` del web (`Login.tsx`), y **sin URL
    /// de redirección a propósito**: aquí no se abre ningún enlace, se teclea
    /// el código en el paso 2. Un enlace de recuperación abriría el navegador
    /// y dejaría la sesión iniciada FUERA de la app, que es justo lo contrario
    /// de lo que quiere alguien que está mirando la pantalla de acceso.
    ///
    /// Devuelve el mensaje de error, o `nil` si salió.
    @MainActor
    func enviarCodigoDeRecuperacion(correo: String) async -> String? {
        do {
            try await supabase.auth.resetPasswordForEmail(correo)
            return nil
        } catch {
            if Self.esFalloDeRed(error) { return Self.mensajeSinConexion }
            return L.t("No se pudo enviar el correo. Intenta de nuevo.",
                       "Couldn't send the email. Please try again.")
        }
    }

    /// **Paso 2: canjear el código y poner la contraseña nueva.**
    ///
    /// `verifyOTP` con `.recovery` **deja la sesión iniciada**, así que al
    /// terminar se entra directo y no se le pide la contraseña recién puesta a
    /// quien acaba de escribirla. Es el mismo camino que el web.
    ///
    /// Los dos errores se distinguen —código malo y contraseña rechazada—
    /// porque el remedio no es el mismo: uno se arregla pidiendo otro código y
    /// el otro escribiendo otra contraseña.
    ///
    /// **El código se canjea una sola vez** (24-sep, con la cuenta del
    /// revisor). Si `verifyOTP` pasa y Supabase rechaza la contraseña, el
    /// código ya está gastado: reintentar con él daba «Código inválido o
    /// vencido» y la persona creía que el fallo era el código. Ahora se
    /// recuerda que ya se canjeó y el reintento va directo a la contraseña
    /// —la sesión que abrió el código sigue viva—.
    @MainActor
    func cambiarContrasena(correo: String, codigo: String, nueva: String) async -> String? {
        guard !ocupada else { return nil }
        ocupada = true
        defer { ocupada = false }
        let canje = correo.lowercased() + "|" + codigo
        if codigoCanjeado != canje {
            do {
                _ = try await supabase.auth.verifyOTP(email: correo, token: codigo, type: .recovery)
                codigoCanjeado = canje
            } catch {
                if Self.esFalloDeRed(error) { return Self.mensajeSinConexion }
                return L.t("Código inválido o vencido.", "Invalid or expired code.")
            }
        }
        do {
            let usuario = try await supabase.auth.update(user: UserAttributes(password: nueva))
            codigoCanjeado = nil
            await adoptar(uid: usuario.id.uuidString,
                          correo: usuario.email ?? correo, permitirCache: false)
            return nil
        } catch {
            if Self.esFalloDeRed(error) { return Self.mensajeSinConexion }
            // La misma que ya tenía: el código abrió la sesión, así que se
            // entra en vez de pedirle que escriba otra.
            if let e = error as? AuthError, e.errorCode == .samePassword,
               let usuario = try? await supabase.auth.user() {
                codigoCanjeado = nil
                await adoptar(uid: usuario.id.uuidString,
                              correo: usuario.email ?? correo, permitirCache: false)
                return nil
            }
            // La política del proyecto la rechazó. Con `ReglasContrasena` la
            // pantalla ya no deja mandarla, pero si Supabase endurece la regla
            // el motivo tiene que llegar a la persona.
            if let e = error as? AuthError,
               e.errorCode == .weakPassword || e.message.localizedCaseInsensitiveContains("password should") {
                return ReglasContrasena.textoRechazo
            }
            return L.t("No se pudo cambiar la contraseña.", "Couldn't change the password.")
        }
    }

    /// **Borra la cuenta en el servidor.** Requisito 5.1.1(v) de Apple.
    ///
    /// La hace la Edge Function `borrar-cuenta`, que YA existe y es la misma
    /// que invoca el app web: no se duplica la regla en dos sitios, que es
    /// justo donde se separan. Ella identifica al usuario por su JWT, borra su
    /// perfil, borra la iglesia si se queda sin ningún perfil —el
    /// `ON DELETE CASCADE` arrastra miembros, movimientos, cartas y el resto—
    /// y elimina por último la cuenta de acceso.
    ///
    /// **Nunca desde el cliente.** Borrar una cuenta de Auth pide la clave de
    /// servicio, y esa no puede vivir en una app que se descarga: la función
    /// la tiene en el servidor y por eso el trabajo se hace allí.
    ///
    /// Lanza si el servidor no lo confirmó, para que quien llama NO limpie el
    /// aparato: dejar a alguien sin sus datos locales y con la cuenta viva es
    /// el peor de los dos fallos posibles.
    static func borrarCuentaEnElServidor() async throws {
        struct Respuesta: Decodable {
            let ok: Bool?
            let error: String?
        }
        let r: Respuesta = try await supabase.functions
            .invoke("borrar-cuenta", options: FunctionInvokeOptions(body: [String: String]()))
        if let mensaje = r.error, !mensaje.isEmpty {
            throw NSError(domain: "Tamio.BorrarCuenta", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: mensaje])
        }
        guard r.ok == true else {
            throw NSError(domain: "Tamio.BorrarCuenta", code: 2,
                          userInfo: [NSLocalizedDescriptionKey:
                            L.t("El servidor no confirmó el borrado. No se ha tocado nada en este aparato.",
                                "The server didn't confirm the deletion. Nothing on this device was touched.")])
        }
    }

    @MainActor
    func cerrarSesion() async {
        try? await supabase.auth.signOut()
        // Los datos de una iglesia no pueden quedarse en el aparato para el
        // siguiente que entre.
        try? BaseLocal.compartida.limpiar()
        Self.olvidarCache()
        // La ficha de la iglesia en memoria, también: si no, quien entre
        // después con otra cuenta la heredaría y la subiría a su iglesia.
        ConfiguracionIglesiaViewModel.compartido.olvidar()
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
    private func adoptar(uid: String, correo: String, permitirCache: Bool) async {
        let leido: (churchId: String, perfil: Perfil)?
        do {
            leido = try await leerPerfil(uid: uid)
        } catch {
            // No se pudo preguntar. La sesión sigue siendo válida.
            if permitirCache, var guardado = Self.cache(uid: uid) {
                // El correo lo tenemos aunque no se pueda preguntar al
                // servidor: viene con la sesión.
                guardado.perfil.correo = correo
                guardado.perfil.id = uid
                if guardado.churchId != churchIdActivo { ConfiguracionIglesiaViewModel.compartido.olvidar() }
                churchIdActivo = guardado.churchId
                perfil = guardado.perfil
                autorActual = guardado.perfil.firma
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
        // Otra iglesia que la de la ficha en memoria: se olvida antes de nada.
        if leido.churchId != churchIdActivo { ConfiguracionIglesiaViewModel.compartido.olvidar() }
        churchIdActivo = leido.churchId
        perfil = leido.perfil
        perfil.correo = correo
        perfil.id = uid
        // El autor de lo que se anote en el registro, ya con el correo puesto
        // por si el perfil no trae nombre: `firma` cae al correo antes que
        // dejar un apunte sin autor.
        autorActual = perfil.firma
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
            // Dice qué hacer, no solo qué pasó (25-sep): el caso de siempre es
            // una letra mal tecleada, y quien lo lee no sabe si el fallo es suyo
            // o de la cuenta.
            return L.t("El correo o la contraseña no son correctos. Revisa que estén bien escritos, o usa «¿Olvidaste tu contraseña?».",
                       "The email or password is incorrect. Check that they're typed correctly, or use \u{201C}Forgot your password?\u{201D}.")
        }
        return texto
    }
}

// MARK: - Las reglas de la contraseña

/// **Lo que Supabase exige a una contraseña nueva, escrito una sola vez.**
///
/// El proyecto pide al menos 8 caracteres con una minúscula, una mayúscula,
/// un número y un símbolo (Auth → Password requirements). Hasta el 25-sep la
/// app solo decía «al menos 6 caracteres»: la persona escribía `Iglesia2026`,
/// Supabase la rechazaba y la pantalla no explicaba por qué, así que creía
/// haberla cambiado y luego no podía entrar. Es la misma regla que ya pide
/// `tamio.church/invitacion.html`, con los mismos símbolos.
///
/// Vive en `Support` porque la usan el iPhone, el iPad y el Mac.
enum ReglasContrasena {
    static let minimo = 8
    static let simbolos = "!@#$%^&*()_+-=[]{};'\\:\"|<>?,./`~"

    static func cumple(_ s: String) -> Bool {
        s.count >= minimo
            && s.contains(where: \.isLowercase)
            && s.contains(where: \.isUppercase)
            && s.contains(where: \.isNumber)
            && s.contains(where: { simbolos.contains($0) })
    }

    /// La regla, para ponerla debajo del campo ANTES de escribir.
    static var texto: String {
        L.t("Al menos 8 caracteres, con una minúscula, una mayúscula, un número y un símbolo (como ! # $ o %).",
            "At least 8 characters, with a lowercase letter, an uppercase letter, a number and a symbol (like ! # $ or %).")
    }

    /// Lo que se dice si, aun así, el servidor la rechaza.
    static var textoRechazo: String {
        L.t("Esa contraseña no cumple las reglas: al menos 8 caracteres, con una minúscula, una mayúscula, un número y un símbolo.",
            "That password doesn't meet the rules: at least 8 characters, with a lowercase letter, an uppercase letter, a number and a symbol.")
    }

    static var textoNoCoinciden: String {
        L.t("Las dos contraseñas no son iguales.", "The two passwords don't match.")
    }
}

// MARK: - Borrar la cuenta

/// **Lo que «Borrar mi cuenta» dice y hace, escrito una sola vez.**
///
/// La regla 5.1.1(v) de Apple pide que la cuenta se pueda borrar desde dentro
/// de la app, y «dentro de la app» son DOS pantallas: `IPhoneAjustesView` en el
/// teléfono y `ConfiguracionView` en el iPad. Escrito dos veces, el día que
/// cambie el aviso —o el orden de los tres pasos— se corrige uno y el otro se
/// queda mintiendo sobre una operación que no tiene vuelta atrás.
///
/// Vive aquí y no en una de las dos vistas porque la operación es de la sesión:
/// la parte de servidor ya está arriba, en `borrarCuentaEnElServidor`.
enum BorradoDeCuenta {

    /// **El aviso dice la REGLA, no un caso.** El servidor borra la iglesia
    /// entera solo si al irte no queda ningún otro perfil en ella; con más
    /// gente dentro, la iglesia sigue y tú te vas. Y el aparato no puede saber
    /// en cuál de los dos casos está: las políticas RLS de `perfiles` no dejan
    /// a un aparato leer los perfiles de los demás, así que no hay forma de
    /// contarlos. Por eso se enuncia la condición en vez de adivinarla.
    ///
    /// El web avisa siempre con el caso fuerte —"todos los datos de tu iglesia
    /// en la nube"— sin la condición, así que exagera cuando quedan otros
    /// miembros. Apuntado para el otro repo.
    static var aviso: String {
        L.t("Tu cuenta se elimina para siempre. Si eres la única persona con acceso a tu iglesia, se borran TAMBIÉN todos sus datos en la nube: movimientos, miembros, actas y cartas. Si hay más personas, la iglesia sigue y solo se va tu acceso.\n\nPuedes volver a registrarte con el mismo correo, pero eso crea una iglesia NUEVA y vacía: no recuperas nada. Para volver a esta tendría que invitarte un administrador.",
            "Your account is permanently deleted. If you are the only person with access to your church, ALL of its cloud data goes too: transactions, members, minutes and letters. If there are other people, the church stays and only your access is removed.\n\nYou can sign up again with the same email, but that creates a NEW, empty church: nothing comes back. To return to this one, an administrator would have to invite you.")
    }

    /// **El diálogo dice menos que el pie, a propósito.** El pie está siempre a
    /// la vista y puede explicarse; el diálogo es la última pregunta antes de
    /// una acción sin vuelta, y cuatro frases ahí se leen en diagonal. Aquí van
    /// solo las dos que cambian la decisión.
    static var avisoCorto: String {
        L.t("Se elimina para siempre y no se puede deshacer. Si eres la única persona con acceso, se van también todos los datos de tu iglesia.",
            "This is permanent and cannot be undone. If you are the only person with access, all of your church's data goes too.")
    }

    /// Los tres pasos, y **el orden no es intercambiable**: el aparato se
    /// limpia solo si el servidor dijo que sí. Al revés —borrar primero aquí—
    /// dejaría a alguien sin sus datos locales y con la cuenta viva si la
    /// llamada falla, que es el peor de los dos fallos posibles.
    ///
    /// Lanza lo que venga del servidor para que la pantalla lo enseñe: quien
    /// acaba de pedir esto merece saber por qué no ocurrió.
    @MainActor
    static func ejecutar(_ sesion: SesionSupabase?) async throws {
        try await SesionSupabase.borrarCuentaEnElServidor()
        try await BorradoMasivo.reinicioDeFabrica()
        await sesion?.cerrarSesion()
    }
}
