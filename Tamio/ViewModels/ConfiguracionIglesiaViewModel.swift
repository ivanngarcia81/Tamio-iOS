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
    /// **De qué iglesia es la ficha que hay en memoria.** Sin esto, cerrar
    /// sesión y entrar con otra cuenta sin cerrar la app dejaba aquí la ficha
    /// de la iglesia anterior —`cargar()` no vuelve a leer—, y el primer
    /// guardado la subía ENTERA a la iglesia nueva (`guardar` escribe bajo
    /// `churchIdActivo`, sea de quien sea la ficha). Pasó de verdad: el
    /// 23-sep la iglesia del revisor de Apple amaneció con el nombre, la
    /// ciudad, la moneda y los cargos vacíos de la iglesia de prueba.
    private var iglesiaLeida: String?
    /// Solo se guarda una ficha en la iglesia de la que se leyó.
    private var puedeGuardar: Bool { iglesiaLeida == churchIdActivo }

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

    /// **Olvida la ficha**: al cerrar sesión y al entrar en otra iglesia. Se
    /// cancela lo que estuviera por guardarse y la siguiente `cargar()` vuelve
    /// a leer de verdad.
    @MainActor
    func olvidar() {
        tareaGuardado?.cancel()
        tareaGuardado = nil
        cargando = true
        config = ConfiguracionIglesia()
        cargando = false
        cargada = false
        iglesiaLeida = nil
    }

    @MainActor
    private func releer() async {
        let iglesia = churchIdActivo
        guard let c = try? await repo.cargar() else { return }
        // Si entre tanto cambió la iglesia, esto ya no es de nadie.
        guard iglesia == churchIdActivo else { return }
        cargando = true
        config = c
        cargando = false
        iglesiaLeida = iglesia

        // El logo va aparte porque lo que se guarda aquí es su RUTA, no la
        // imagen. Sin red, `sincronizar` no hace nada y se sigue viendo la que
        // ya está en el aparato. En una `Task` para no dejar la pantalla
        // esperando a una descarga: el resto de la configuración ya está.
        Task { await LogoIglesia.compartido.sincronizar(con: c.logoPath) }
    }

    /// Se guarda sola poco después de dejar de escribir. Un botón "Guardar" en
    /// una pantalla de ajustes con treinta campos se olvida, y entonces el
    /// membrete de los documentos se queda a medias sin que nadie sepa por qué.
    private func programarGuardado() {
        tareaGuardado?.cancel()
        guard puedeGuardar, let iglesia = iglesiaLeida else { return }
        let aGuardar = config
        tareaGuardado = Task { [repo] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, iglesia == churchIdActivo else { return }
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

    /// **La ruta del logo se guarda YA, sin esperar al temporizador.**
    ///
    /// El resto de la configuración se guarda sola 800 ms después de dejar de
    /// escribir, que para treinta campos de texto es lo correcto. El logo no es
    /// un campo que se teclea letra a letra: es un suceso único, y esos 800 ms
    /// eran una ventana con la ruta puesta en pantalla y no en la base. Si
    /// dentro de esa ventana entraba una sincronización —o el usuario cambiaba
    /// de pantalla—, la configuración se releía sin la ruta y el logo recién
    /// puesto se borraba solo. Visto en el aparato el 7 de septiembre de 2026.
    @MainActor
    func fijarLogo(_ ruta: String) async {
        config.logoPath = ruta
        await guardarYa()
    }

    /// Fuerza el guardado al salir de la pantalla, sin esperar al temporizador.
    @MainActor
    func guardarYa() async {
        tareaGuardado?.cancel()
        guard puedeGuardar else { return }
        try? await repo.guardar(config)
    }
}
