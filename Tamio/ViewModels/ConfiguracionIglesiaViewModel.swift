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
        didSet { if config != oldValue { programarGuardado() } }
    }
    private(set) var cargada = false

    private let repo = repositorioConfiguracionIglesia()
    private var tareaGuardado: Task<Void, Never>?

    private init() {}

    @MainActor
    func cargar() async {
        guard !cargada else { return }
        if let c = try? await repo.cargar() { config = c }
        cargada = true
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

    /// Fuerza el guardado al salir de la pantalla, sin esperar al temporizador.
    @MainActor
    func guardarYa() async {
        tareaGuardado?.cancel()
        try? await repo.guardar(config)
    }
}
