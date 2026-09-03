import Foundation
import Observation

@Observable
final class MiembrosViewModel {
    private let repo: MiembrosRepository

    var filtro: FiltroMiembro = .activos {
        didSet { if filtro != oldValue { Task { await cargar() } } }
    }
    private(set) var items: [Aportante] = []
    var seleccionId: String?
    var busqueda = ""

    init(repo: MiembrosRepository = MockMiembrosRepository()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        items = (try? await repo.lista(filtro: filtro)) ?? []
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = itemsFiltrados.first?.id
        }
    }

    // MARK: - CRUD (vía repositorio → el motor solo cambia la impl)

    @MainActor func crear(_ a: Aportante) async {
        try? await repo.crear(a)
        await cargar()
    }
    @MainActor func actualizar(_ a: Aportante) async {
        try? await repo.actualizar(a)
        await cargar()
        seleccionId = a.id
    }
    @MainActor func eliminar(_ a: Aportante) async {
        try? await repo.eliminar(id: a.id)
        if seleccionId == a.id { seleccionId = nil }
        await cargar()
    }

    var seleccion: Aportante? { items.first { $0.id == seleccionId } }

    var itemsFiltrados: [Aportante] {
        let base = busqueda.isEmpty ? items
            : items.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda)
                || $0.correo.localizedCaseInsensitiveContains(busqueda)
                || $0.idFiscal.localizedCaseInsensitiveContains(busqueda) }
        return base.sorted { $0.nombre < $1.nombre }
    }

    /// Suma de aportes de la lista visible (pie de la columna).
    var total: Centavos { itemsFiltrados.reduce(0) { $0 + $1.aportesTotal } }

    var activosCount: Int { items.filter { $0.estado != .baja }.count }
    var bajasCount: Int { items.filter { $0.estado == .baja }.count }
}
