import Foundation

/// Interruptor del modo revisión: salta el inicio de sesión y sirve datos de
/// ejemplo, para poder recorrer todas las pantallas sin credenciales.
///
/// Está encerrado en `#if DEBUG` a propósito. Una compilación de Release
/// devuelve `false` aunque `activada` se quede en `true`, así que un olvido no
/// puede llegar a la App Store. Aun así, mientras esté encendido la app pinta
/// un aviso fijo en pantalla: el modo tiene que ser visible, no silencioso.
// El nombre lleva el prefijo `Modo` porque `Revision` ya es el modelo de la
// bandeja «Por revisar»: dos tipos con el mismo nombre serían un choque real.
enum ModoRevision {

    /// **Apagado desde el 6 de septiembre de 2026.** Es lo que este mismo
    /// comentario llevaba pidiendo —"ponerlo en `false` al terminar la revisión
    /// de pantallas"— y la revisión terminó: las seis de Secretaría están
    /// enchufadas a la base.
    ///
    /// Encendido, la app **no ejercita nada de Supabase**: ni sesión, ni
    /// folios, ni sincronización, y los repositorios que se inyectan son los
    /// `Mock*`. Con cuatro entidades nuevas —`evento`, `acta`, `carta`,
    /// `apunte`— cuya subida y bajada no ha corrido nunca, dejarlo encendido
    /// es no poder probar lo único que falta por probar.
    ///
    /// Para recorrer pantallas sin credenciales se vuelve a poner en `true`.
    private static let activada = false

    /// **Y también se enciende por argumento de lanzamiento**, sin recompilar:
    /// `-modoRevision YES`.
    ///
    /// Lo pide la suite. Media docena de pruebas de interfaz se escribieron
    /// contra la semilla de las maquetas —"Ana Lucía Torres Beltrán",
    /// "Ofrenda misionera", "Building fund"— y el 6-sep, al apagar esta
    /// bandera, la app pasó a leer la base de verdad y esas pruebas se
    /// quedaron **sin sus datos**. Llevaban rojas desde entonces sin que nadie
    /// lo supiera, porque nadie había corrido la suite de interfaz entera
    /// contra una iglesia real hasta el 22-sep.
    ///
    /// Con el argumento, esas pruebas recuperan su entorno: **los `Mock*`, que
    /// son la iglesia de usar y tirar que ya teníamos escrita**. Y de paso
    /// dejan de escribir en la contabilidad de verdad — las maquetas guardan
    /// en memoria.
    ///
    /// Se resuelve UNA vez: `sinLogin` lo consultan los repositorios cada vez
    /// que se construye uno, y no tiene sentido volver a `UserDefaults` en
    /// cada llamada.
    private static let porArgumento = UserDefaults.standard.bool(forKey: "modoRevision")

    static var sinLogin: Bool {
        #if DEBUG
        return activada || porArgumento
        #else
        // En Release no hay manera de encenderlo, ni por argumento: lo que se
        // publica no puede servir datos de maqueta por una bandera.
        return false
        #endif
    }
}
