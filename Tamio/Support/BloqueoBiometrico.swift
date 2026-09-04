import LocalAuthentication
import Observation
import SwiftUI

/// **El candado de la app en este aparato.**
///
/// Tamio lleva delante las cuentas de una iglesia: cuánto entró el domingo,
/// cuánto se llevó al banco, quién aportó y cuánto. Un teléfono desbloqueado
/// encima de una mesa es todo lo que hace falta para leerlo, y cerrar sesión no
/// es una respuesta —al volver a entrar habría que teclear la contraseña, y el
/// tesorero captura movimientos varias veces al día—.
///
/// Tres decisiones, todas del lado de no dejar a nadie fuera de sus propias
/// cuentas:
///
/// - **La política es `deviceOwnerAuthentication`, no la de solo biometría.**
///   Con la de solo biometría, tres intentos fallidos —una mascarilla, una
///   venda, un gemelo— dejan el candado cerrado sin salida. Ésta cae al código
///   del aparato, que es la misma puerta que ya protege el teléfono entero.
/// - **Si el aparato no puede autenticar, NO se bloquea.** Alguien que quite el
///   código del iPhone teniendo el candado puesto se quedaría sin poder abrir
///   su contabilidad. El interruptor queda encendido y el candado se retira
///   solo hasta que vuelva a haber con qué abrirlo.
/// - **Se cierra al irse al fondo, no al pasar a inactivo.** `.inactive` salta
///   con bajar el centro de control o con una notificación, y pedir la cara
///   cada vez que aparece un aviso convierte el candado en un castigo.
@Observable
@MainActor
final class BloqueoBiometrico {

    static let compartido = BloqueoBiometrico()

    /// El interruptor de Ajustes. Va en `UserDefaults` porque es de ESTE
    /// aparato: el iPad de la oficina, que no sale de allí, no tiene por qué
    /// llevar el mismo candado que el teléfono que va en el bolsillo.
    var activo: Bool {
        didSet {
            UserDefaults.standard.set(activo, forKey: Self.clave)
            // Al apagarlo, se abre: si no, quedaría cerrado hasta el siguiente
            // arranque con el interruptor diciendo que está apagado.
            if !activo { cerrado = false }
        }
    }

    /// Si la app está tapada ahora mismo esperando la cara.
    private(set) var cerrado = false
    /// Lo que falló en el último intento, para enseñarlo en la pantalla de
    /// bloqueo en vez de dejar un botón que no hace nada aparente.
    private(set) var error: String?
    private var autenticando = false

    private static let clave = "bloqueo.biometrico"

    private init() {
        activo = UserDefaults.standard.bool(forKey: Self.clave)
    }

    // MARK: - Lo que puede el aparato

    /// Si hay con qué autenticar: cara, huella o código. `nil` en el motivo
    /// cuando sí se puede.
    static func disponible() -> (puede: Bool, motivo: String?) {
        let contexto = LAContext()
        var fallo: NSError?
        if contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fallo) {
            return (true, nil)
        }
        // El caso que de verdad pasa: el aparato no tiene código puesto. Sin
        // código no hay ni biometría, y decir solo "no disponible" deja a
        // alguien buscando un ajuste de Tamio que no existe.
        if (fallo as? LAError)?.code == .passcodeNotSet {
            return (false, L.t("Pon primero un código en los ajustes del aparato.",
                               "Set a device passcode in your device's settings first."))
        }
        return (false, L.t("Este aparato no puede pedir Face ID ni código.",
                           "This device can't ask for Face ID or a passcode."))
    }

    /// Cómo se llama aquí lo que pide el candado: no todos los aparatos tienen
    /// Face ID, y un interruptor que dice "Face ID" en un iPad con Touch ID
    /// está mintiendo con el nombre propio de otra cosa.
    static var nombreBiometria: String {
        let contexto = LAContext()
        _ = contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch contexto.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return L.t("Código del aparato", "Device passcode")
        }
    }

    // MARK: - Cerrar y abrir

    /// Al mandar la app al fondo. Solo cierra si de verdad se va a poder abrir.
    func alIrseAlFondo() {
        guard activo, Self.disponible().puede else { return }
        cerrado = true
        error = nil
    }

    /// Al arrancar. Igual que al volver del fondo, pero explícito: una app que
    /// se abre desde cero con las cuentas a la vista no está protegida.
    func alArrancar() {
        alIrseAlFondo()
    }

    func abrir() async {
        guard !autenticando else { return }
        autenticando = true
        defer { autenticando = false }

        let contexto = LAContext()
        // El botón de reserva del diálogo del sistema. Sin texto propio dice
        // "Introducir contraseña", que aquí se confundiría con la contraseña
        // de la cuenta de Tamio.
        contexto.localizedFallbackTitle = L.t("Usar el código del aparato", "Use device passcode")
        let motivo = L.t("Desbloquea Tamio para ver las cuentas de la iglesia.",
                         "Unlock Tamio to see the church's accounts.")
        do {
            let ok = try await contexto.evaluatePolicy(.deviceOwnerAuthentication,
                                                       localizedReason: motivo)
            if ok {
                cerrado = false
                error = nil
            }
        } catch {
            // Cancelar no es un fallo que haya que explicar: la persona cerró
            // el diálogo a propósito y la pantalla ya dice qué hacer.
            let codigo = (error as? LAError)?.code
            if codigo == .userCancel || codigo == .appCancel || codigo == .systemCancel {
                self.error = nil
            } else if codigo == .userFallback {
                self.error = nil
            } else {
                self.error = error.localizedDescription
            }
        }
    }
}
