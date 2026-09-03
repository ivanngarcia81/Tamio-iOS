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
    /// Último fallo del repositorio. Antes `cargar()` usaba `try?` y devolvía
    /// una lista vacía: si RLS negaba el acceso o se caía la red, la pantalla
    /// se quedaba en blanco sin decir por qué, que es el fallo más difícil de
    /// diagnosticar. Ahora el mensaje sube a la vista.
    private(set) var error: String?
    private(set) var cargando = false

    // Filtros de la lista.
    var busqueda = ""
    var filtroCategoria: String? = nil
    var soloSinDepositar = false

    init(tipo: TipoMovimiento, repo: MovimientosRepository = repositorioMovimientos()) {
        self.tipo = tipo
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        cargando = true
        do {
            items = try await repo.lista(tipo: tipo)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        cargando = false
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = itemsFiltrados.first?.id
        }
    }

    // MARK: - CRUD (todo pasa por el repositorio → el motor solo cambia la impl)

    @MainActor func crear(_ m: Movimiento) async {
        await ejecutar { try await self.repo.crear(m) }
        await cargar()
        seleccionId = m.id
    }

    @MainActor func actualizar(_ m: Movimiento) async {
        await ejecutar { try await self.repo.actualizar(m) }
        await cargar()
        seleccionId = m.id
    }

    @MainActor func eliminar(_ m: Movimiento) async {
        await ejecutar { try await self.repo.eliminar(id: m.id) }
        if seleccionId == m.id { seleccionId = nil }
        await cargar()
    }

    /// Una escritura que falla en silencio hace creer que el registro se
    /// guardó. Se recoge el error para que la vista pueda avisar.
    @MainActor
    private func ejecutar(_ operacion: () async throws -> Void) async {
        do { try await operacion(); error = nil }
        catch { self.error = error.localizedDescription }
    }

    @MainActor func descartarError() { error = nil }

    /// Folio previsto para la serie que se está viendo. Orientativo: el
    /// definitivo lo asigna el repositorio al guardar.
    func nuevoFolio() async -> String { await repo.siguienteFolio(tipo: tipo) }

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
