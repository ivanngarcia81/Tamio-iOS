import Foundation

@Observable
final class ActasViewModel {
    var lista: [Acta] = []
    var seleccionId: String? = nil
    var cargando = false

    private let repo: ActasRepository

    init(repo: ActasRepository = repositorioActas()) {
        self.repo = repo
    }

    var seleccion: Acta? { lista.first { $0.id == seleccionId } }
    var proximoId: String { UUID().uuidString }

    /// **Las tres escriben y recargan.** Antes solo tocaban el array: un acta
    /// nueva se veía hasta salir de la pantalla, y firmarla o cerrarla se
    /// deshacía solo al volver a entrar, porque `cargar()` volvía a pedirle la
    /// lista al repositorio y allí nunca se había escrito nada.
    @MainActor
    func agregarActa(_ nueva: Acta) async {
        try? await repo.guardar(nueva)
        await cargar()
        seleccionId = nueva.id
    }

    @MainActor
    func cerrarActa(id: String) async {
        await cambiarEstado(id: id, a: .cerrada)
    }

    @MainActor
    func firmarActa(id: String) async {
        await cambiarEstado(id: id, a: .firmada)
    }

    @MainActor
    private func cambiarEstado(id: String, a estado: EstadoActa) async {
        guard var acta = lista.first(where: { $0.id == id }) else { return }
        acta.estado = estado
        try? await repo.guardar(acta)
        await cargar()
        seleccionId = id
    }

    func cargar() async {
        cargando = true
        lista = (try? await repo.lista()) ?? []
        // Si lo que estaba seleccionado ya no está —se borró en otro
        // aparato—, no se deja el detalle apuntando a un id fantasma.
        if seleccionId == nil || !lista.contains(where: { $0.id == seleccionId }) {
            seleccionId = lista.first?.id
        }
        cargando = false
    }
}
