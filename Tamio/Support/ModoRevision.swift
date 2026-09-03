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

    /// ⚠️ Ponerlo en `false` al terminar la revisión de pantallas.
    private static let activada = true

    static var sinLogin: Bool {
        #if DEBUG
        return activada
        #else
        return false
        #endif
    }
}
