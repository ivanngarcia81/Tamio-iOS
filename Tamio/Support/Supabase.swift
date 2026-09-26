import Foundation
import Supabase
#if os(macOS)
import Security
#endif

/// Singleton del cliente Supabase. Todas las capas de repositorio lo usan.
///
/// La clave es la `anon key` del proyecto: no concede acceso por sí misma. Las
/// políticas RLS de `transactions`, `members` y `perfiles` exigen `auth.uid()`,
/// así que sin sesión iniciada el backend devuelve cero filas y rechaza las
/// escrituras. Ver `SesionSupabase`.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hkpbkpojeierxqtbmagh.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrcGJrcG9qZWllcnhxdGJtYWdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjE0NzUsImV4cCI6MjA5OTYzNzQ3NX0.z0SGP_XB16wYNFVygqZ8WY2Xev4bfd2J5hR1-2edcso",
    options: SupabaseClientOptions(auth: .init(storage: almacenDeSesion))
)

/// En el iPhone y el iPad, el de la librería: allí solo hay un llavero y ya es
/// el bueno. En el Mac, `LlaveroMac`.
private var almacenDeSesion: any AuthLocalStorage {
    #if os(macOS)
    LlaveroMac()
    #else
    AuthClient.Configuration.defaultLocalStorage
    #endif
}

#if os(macOS)
/// **La sesión del Mac, en el llavero de protección de datos.**
///
/// El de la librería (`KeychainLocalStorage`) no pide
/// `kSecUseDataProtectionKeychain`, así que en el Mac cae en el llavero
/// ANTIGUO, el de archivo, donde cada elemento lleva una lista de las apps que
/// pueden leerlo atada a la FIRMA de la que lo creó. Visto el 25-sep: una app
/// firmada de otra manera —un build de desarrollo, y mañana la de la Mac App
/// Store para quien venga del DMG— pedía «Tamio quiere usar información
/// confidencial… supabase.gotrue.swift» y la contraseña del Mac en cada
/// lectura. El de protección de datos es el del iPhone: se ata al
/// identificador de la app y del equipo, no a la firma, y nunca pregunta.
///
/// **Sin mudanza desde el llavero antiguo, a propósito** (26-sep). Leer allí
/// la sesión vieja es justo lo que saca el aviso, y `kSecUseAuthenticationUIFail`
/// no lo impide: se probó y el aviso salió igual. Así que quien venga de un
/// build anterior entra otra vez, una vez, y ya. Entrar de nuevo no borra la
/// base del Mac (eso solo lo hace `cerrarSesion`). El elemento viejo se queda
/// huérfano en el llavero antiguo: esta app ya no lo lee.
struct LlaveroMac: AuthLocalStorage {
    private let servicio = "supabase.gotrue.swift"

    func store(key: String, value: Data) throws {
        var nuevo = consulta(key)
        nuevo[kSecValueData as String] = value
        nuevo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        var estado = SecItemAdd(nuevo as CFDictionary, nil)
        if estado == errSecDuplicateItem {
            estado = SecItemUpdate(consulta(key) as CFDictionary,
                                   [kSecValueData as String: value] as CFDictionary)
        }
        try comprobar(estado)
    }

    func retrieve(key: String) throws -> Data? {
        var q = consulta(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var dato: AnyObject?
        let estado = SecItemCopyMatching(q as CFDictionary, &dato)
        if estado == errSecItemNotFound { return nil }
        try comprobar(estado)
        return dato as? Data
    }

    func remove(key: String) throws {
        let estado = SecItemDelete(consulta(key) as CFDictionary)
        if estado != errSecItemNotFound { try comprobar(estado) }
    }

    // MARK: -

    private func consulta(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servicio,
         kSecAttrAccount as String: key,
         kSecUseDataProtectionKeychain as String: true]
    }

    private func comprobar(_ estado: OSStatus) throws {
        guard estado == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(estado))
        }
    }
}
#endif

/// Iglesia activa, por la que filtran todas las queries. La fuente de verdad es
/// `perfiles.church_id` del usuario autenticado: `SesionSupabase` lo reescribe
/// al iniciar sesión. El valor inicial solo cubre el arranque previo a la sesión.
var churchIdActivo = "84c92ad0-5362-49f8-8962-0c7b8c34b858"

/// **Quién está usando la app**, para firmar lo que se anota en el registro.
///
/// Va aquí y no se pasa por parámetro por lo mismo que `churchIdActivo`: quien
/// anota un suceso es un repositorio —"lo llaman las funciones que hacen la
/// cosa, no la interfaz", como lo dice el web—, y un repositorio no tiene, ni
/// debe tener, la sesión a mano. `SesionSupabase` lo reescribe al adoptar el
/// perfil, igual que la iglesia.
///
/// Es una INSTANTÁNEA del nombre: el registro guarda copias, no referencias, y
/// si esa persona se da de baja el apunte tiene que seguir diciendo quién fue.
var autorActual = ""
