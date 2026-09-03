import Foundation
import Observation

@Observable
final class MovimientosViewModel {
    private let repo: MovimientosRepository

    var tipo: TipoMovimiento {
        didSet { if tipo != oldValue { filtroCategoria = nil; Task { await cargar() } } }
    }
    private(set) var items: [Movimiento] = []
    var seleccionId: String?

    // Filtros de la lista.
    var busqueda = ""
    var filtroCategoria: String? = nil
    var soloSinDepositar = false

    init(tipo: TipoMovimiento, repo: MovimientosRepository = MockMovimientosRepository()) {
        self.tipo = tipo
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        items = (try? await repo.lista(tipo: tipo)) ?? []
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = itemsFiltrados.first?.id
        }
    }

    // MARK: - CRUD (todo pasa por el repositorio → el motor solo cambia la impl)

    @MainActor func crear(_ m: Movimiento) async {
        try? await repo.crear(m)
        await cargar()
        seleccionId = m.id
    }

    @MainActor func actualizar(_ m: Movimiento) async {
        try? await repo.actualizar(m)
        await cargar()
        seleccionId = m.id
    }

    @MainActor func eliminar(_ m: Movimiento) async {
        try? await repo.eliminar(id: m.id)
        if seleccionId == m.id { seleccionId = nil }
        await cargar()
    }

    func nuevoFolio() async -> String { await repo.siguienteFolio() }

    // MARK: - Derivados

    var seleccion: Movimiento? { items.first { $0.id == seleccionId } }

    /// La lista tras aplicar buscador y chips.
    var itemsFiltrados: [Movimiento] {
        items.filter { m in
            (filtroCategoria == nil || m.categoria == filtroCategoria)
            && (!soloSinDepositar || m.sinDepositar)
            && (busqueda.isEmpty
                || m.titular.localizedCaseInsensitiveContains(busqueda)
                || m.folio.contains(busqueda)
                || (m.nota?.localizedCaseInsensitiveContains(busqueda) ?? false))
        }
    }

    var total: Centavos { itemsFiltrados.reduce(0) { $0 + $1.monto } }

    /// Categorías para los chips de filtro, según el tipo actual.
    var categoriasChip: [String] {
        tipo == .ingreso
            ? ["Diezmo", "Ofrenda", "Misiones"]
            : ["Utilidades", "Mantenimiento", "Músicos"]
    }

    var grupos: [(encabezado: String, items: [Movimiento])] {
        let cal = Calendar.current
        let porDia = Dictionary(grouping: itemsFiltrados) { cal.startOfDay(for: $0.fecha) }
        return porDia.keys.sorted(by: >).map { dia in
            (encabezado: encabezado(dia), items: porDia[dia]!.sorted { $0.hora > $1.hora })
        }
    }

    private func encabezado(_ dia: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE d"
        let s = f.string(from: dia).uppercased()
        return Calendar.current.isDateInToday(dia) ? L.t("HOY · ", "TODAY · ") + s : s
    }
}
