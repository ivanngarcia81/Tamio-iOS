import Foundation

/// **Sube de clase los archivos de la app**, que es la mitad barata de lo que
/// `docs/CIFRADO-LOCAL.md` llama opción A.
///
/// Data Protection cifra los archivos con una clave ligada al código del
/// aparato, y la clase decide CUÁNDO se puede leer. Por omisión iOS pone
/// `completeUntilFirstUserAuthentication`: con el teléfono apagado nadie saca
/// nada, pero desde el primer desbloqueo tras encenderlo la clave se queda en
/// memoria hasta el siguiente apagado. Medido en el iPhone de Iván el 7 de
/// septiembre de 2026 — hasta entonces era una suposición, porque el simulador
/// no implementa Data Protection.
///
/// `completeUnlessOpen` sube un escalón: un archivo YA abierto se puede seguir
/// usando aunque el aparato se bloquee, pero **no se puede abrir uno nuevo con
/// el aparato bloqueado**. Es la clase más fuerte compatible con una base que
/// vive abierta toda la sesión.
///
/// **Por qué no la siguiente (`complete`):** con esa, al bloquearse el teléfono
/// el archivo abierto deja de poder leerse y la app se queda escribiendo en el
/// vacío. `completeUnlessOpen` existe exactamente para este caso.
///
/// **Y por qué se puede hacer aquí sin romper nada:** Tamio no trabaja en
/// segundo plano. No declara `UIBackgroundModes` ni usa `BGTaskScheduler`; la
/// sincronización corre al arrancar, al volver al frente, al tirar de la lista
/// y tras guardar un depósito — siempre con la app delante y el aparato
/// desbloqueado. Si algún día se añade una tarea de fondo, esta clase es lo
/// primero que hay que revisar.
enum ProteccionArchivos {

    static let clase = FileProtectionType.completeUnlessOpen

    /// Aplica la clase a todo lo que la app guarda: la base con sus dos
    /// archivos de apoyo, y las carpetas de recibos, firmas y logo.
    ///
    /// **También a las carpetas**, y no es adorno: lo que se cree dentro
    /// después hereda la clase del directorio. Sin eso, el `-wal` que SQLite
    /// crea en la siguiente apertura volvería a nacer con la clase por omisión
    /// y el WAL es donde están los últimos movimientos escritos.
    @discardableResult
    static func aplicar() -> Int {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: false) else { return 0 }

        var rutas: [URL] = [base]
        for nombre in ["tamio.sqlite", "tamio.sqlite-wal", "tamio.sqlite-shm"] {
            rutas.append(base.appendingPathComponent(nombre))
        }
        for carpeta in ["recibos", "firmas", "logo"] {
            let dir = base.appendingPathComponent(carpeta, isDirectory: true)
            rutas.append(dir)
            if let dentro = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                rutas.append(contentsOf: dentro)
            }
        }

        var puestas = 0
        for ruta in rutas where fm.fileExists(atPath: ruta.path) {
            // Si ya la tiene, no se toca: `setAttributes` sobre un archivo
            // abierto es barato, pero hacerlo en cada arranque sobre cientos de
            // recibos no lo sería.
            let actual = (try? fm.attributesOfItem(atPath: ruta.path)[.protectionKey]) as? FileProtectionType
            guard actual != clase else { continue }
            do {
                try fm.setAttributes([.protectionKey: clase], ofItemAtPath: ruta.path)
                puestas += 1
            } catch {
                // **No se interrumpe nada.** Un archivo que no acepta la clase
                // —en un simulador, en un volumen sin Data Protection— no puede
                // impedir que la app arranque: se queda como estaba, que es lo
                // que había hasta hoy.
                continue
            }
        }
        return puestas
    }
}
