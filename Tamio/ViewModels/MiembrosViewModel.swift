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
    /// Deja en la lista solo a quien lleva tres periodos o más sin aportar.
    var soloAtrasados = false

    init(repo: MiembrosRepository = repositorioMiembros()) {
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
    /// Aplica una importación ya confirmada. Los que traen id van a
    /// actualizar; los que no, a crear.
    @MainActor func importar(_ lista: [Aportante]) async {
        for a in lista {
            if a.id.isEmpty { try? await repo.crear(a) } else { try? await repo.actualizar(a) }
        }
        await cargar()
    }

    /// Añade los aportes importados a cada persona y recalcula su total.
    @MainActor func importarAportes(_ porAportante: [String: [Aporte]]) async {
        for (id, nuevos) in porAportante {
            guard let actual = items.first(where: { $0.id == id }) else { continue }
            let combinados = (actual.aportes + nuevos).sorted { $0.fecha > $1.fecha }
            var copia = actual
            copia = Aportante(
                id: actual.id, nombre: actual.nombre, estado: actual.estado,
                rol: actual.rol, miembroDesde: actual.miembroDesde,
                telefono: actual.telefono, correo: actual.correo,
                nacimiento: actual.nacimiento, direccion: actual.direccion,
                estadoCivil: actual.estadoCivil, idFiscal: actual.idFiscal,
                congregaDesde: actual.congregaDesde, frecuencia: actual.frecuencia,
                // El total ya no hay que recalcularlo: sale del historial.
                aportes: combinados,
                familia: actual.familia
            )
            try? await repo.actualizar(copia)
        }
        await cargar()
    }

    @MainActor func actualizar(_ a: Aportante) async {
        try? await repo.actualizar(a)
        await cargar()
        seleccionId = a.id
    }
    // Sin `eliminar`: sacar a alguien del padrón es de Secretaría, que lo hace
    // dándole de baja (conservando su historial) en vez de borrando la ficha.
    // El repositorio mantiene la operación para quien sí deba usarla.

    var seleccion: Aportante? { items.first { $0.id == seleccionId } }

    var itemsFiltrados: [Aportante] {
        let base = busqueda.isEmpty ? items
            : items.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda)
                || $0.correo.localizedCaseInsensitiveContains(busqueda)
                || $0.idFiscal.localizedCaseInsensitiveContains(busqueda) }
        let porConstancia = soloAtrasados ? base.filter(\.atrasadoEnAportes) : base
        return porConstancia.sorted { $0.nombre < $1.nombre }
    }

    /// Cuántos aportantes llevan tres periodos o más sin aportar. Es el número
    /// que justifica el chip de la lista: si es cero, no se enseña.
    var atrasadosCount: Int { items.filter(\.atrasadoEnAportes).count }

    /// El año que enseñan la lista y su pie. El mismo que encabeza la ficha:
    /// si la lista sumara de siempre y la ficha el año, serían dos cifras
    /// distintas para la misma persona a un toque de distancia.
    var anio: Int { Calendar.current.component(.year, from: Date()) }

    /// Suma de aportes del año de la lista visible (pie de la columna).
    var total: Centavos { itemsFiltrados.reduce(0) { $0 + $1.total(anio: anio) } }

    var activosCount: Int { items.filter { $0.estado != .baja }.count }
    var bajasCount: Int { items.filter { $0.estado == .baja }.count }
}
