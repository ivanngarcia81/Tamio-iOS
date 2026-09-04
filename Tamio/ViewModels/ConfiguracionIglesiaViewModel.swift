import Foundation
import Observation

/// Estado de la configuración institucional, compartido por iPhone, iPad y los
/// documentos.
///
/// Es un singleton a propósito: antes cada pantalla tenía sus propios `@State`,
/// así que la iglesia configurada en el teléfono no era la del iPad ni la que
/// salía impresa. Un dato con tres dueños no tiene ninguno.
@Observable
final class ConfiguracionIglesiaViewModel {

    static let compartido = ConfiguracionIglesiaViewModel()

    var config = ConfiguracionIglesia() {
        // `cargando` es la diferencia entre "alguien escribió en un campo" y
        // "acabamos de leer lo que ya estaba guardado". Sin él, cada arranque
        // encolaba una subida de la iglesia recién leída: nada cambiaba, pero
        // el contador de "sin subir" de Ajustes decía 1 desde el primer
        // segundo, y el motor mandaba al servidor lo que el servidor le acababa
        // de dar.
        didSet { if !cargando, config != oldValue { programarGuardado() } }
    }
    private(set) var cargada = false
    private var cargando = false

    private let repo = repositorioConfiguracionIglesia()
    private var tareaGuardado: Task<Void, Never>?

    private init() {}

    @MainActor
    func cargar() async {
        guard !cargada else { return }
        await releer()
        cargada = true
    }

    /// Vuelve a leer aunque ya estuviera cargada. Se usa después de
    /// sincronizar: un permiso que le quitaron al tesorero desde otro aparato
    /// tiene que notarse sin relanzar la app.
    @MainActor
    func recargar() async {
        await releer()
    }

    @MainActor
    private func releer() async {
        guard let c = try? await repo.cargar() else { return }
        cargando = true
        config = c
        cargando = false
    }

    /// Se guarda sola poco después de dejar de escribir. Un botón "Guardar" en
    /// una pantalla de ajustes con treinta campos se olvida, y entonces el
    /// membrete de los documentos se queda a medias sin que nadie sepa por qué.
    private func programarGuardado() {
        tareaGuardado?.cancel()
        let aGuardar = config
        tareaGuardado = Task { [repo] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            try? await repo.guardar(aGuardar)
        }
    }

    /// Cambia los dos permisos del rol Tesorería. Devuelve el motivo si el
    /// servidor lo rechaza —"solo el administrador cambia los permisos" es una
    /// respuesta suya, no un fallo—, o `nil` si quedó puesto.
    ///
    /// El interruptor de la pantalla se mueve DESPUÉS y solo si esto devuelve
    /// `nil`: pintar el cambio antes y deshacerlo luego deja a quien lo tocó
    /// creyendo que lo dejó hecho.
    @MainActor
    func fijarPermisos(vePadron: Bool, puedeEliminar: Bool) async -> String? {
        do {
            try await repo.fijarPermisos(vePadron: vePadron, puedeEliminar: puedeEliminar)
        } catch {
            return error.localizedDescription
        }
        // Bajo `cargando`: el repositorio YA escribió el espejo local, así
        // que dejar que el `didSet` programe el guardado normal solo serviría
        // para encolar una subida de la iglesia entera que no lleva estas dos
        // columnas. Aquí solo se refresca lo que ven las pantallas.
        cargando = true
        config.tesoreroVePadron = vePadron
        config.tesoreroPuedeEliminar = puedeEliminar
        cargando = false
        return nil
    }

    /// Fuerza el guardado al salir de la pantalla, sin esperar al temporizador.
    @MainActor
    func guardarYa() async {
        tareaGuardado?.cancel()
        try? await repo.guardar(config)
    }
}
