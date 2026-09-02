import Foundation

@Observable
final class ActasViewModel {
    var lista: [Acta] = []
    var seleccionId: Int? = 1
    var cargando = false

    private let repo: ActasRepository

    init(repo: ActasRepository = MockActasRepository()) {
        self.repo = repo
    }

    var seleccion: Acta? { lista.first { $0.id == seleccionId } }
    var proximoId: Int { (lista.map(\.id).max() ?? 0) + 1 }

    @MainActor
    func agregarActa(_ nueva: Acta) {
        lista.insert(nueva, at: 0)
        seleccionId = nueva.id
    }

    @MainActor
    func cerrarActa(id: Int) {
        guard let idx = lista.firstIndex(where: { $0.id == id }) else { return }
        lista[idx].estado = .cerrada
    }

    @MainActor
    func firmarActa(id: Int) {
        guard let idx = lista.firstIndex(where: { $0.id == id }) else { return }
        lista[idx].estado = .firmada
    }

    func cargar() async {
        cargando = true
        lista = (try? await repo.lista()) ?? []
        if seleccionId == nil { seleccionId = lista.first?.id }
        cargando = false
    }
}
