import Foundation
import Observation

@Observable
final class MovimientosViewModel {
    private let repo: MovimientosRepository

    var tipo: TipoMovimiento {
        didSet {
            guard tipo != oldValue else { return }
            // Los filtros son del tipo que se estaba viendo: "Sin depositar"
            // no significa nada en Gastos, y una categoría de gasto no existe
            // entre los ingresos. Arrastrarlos dejaba la lista vacía sin que
            // se viera por qué.
            filtroCategoria = nil
            soloSinDepositar = false
            soloPendientes = false
            Task { await cargar() }
        }
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
    /// Estado propio del ingreso: aún no entró en un corte.
    var soloSinDepositar = false
    /// Estado propio del gasto: se marcó para que alguien lo revise.
    var soloPendientes = false
    /// Mes que se está viendo, normalizado al día 1; `nil` = todos los meses.
    /// Antes no existía: la lista traía TODO el historial mientras la barra y
    /// el chip anunciaban el mes en curso, así que el total del pie era el de
    /// siempre y no el del mes que se decía estar viendo.
    var mes: Date? = Fechas.inicioDeMes(Date())

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
        ajustarMes()
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = itemsFiltrados.first?.id
        }
    }

    // MARK: - CRUD (todo pasa por el repositorio → el motor solo cambia la impl)

    @MainActor func crear(_ m: Movimiento) async {
        await ejecutar { try await self.repo.crear(m) }
        irAlMesDe(m)
        await cargar()
        seleccionId = m.id
    }

    @MainActor func actualizar(_ m: Movimiento) async {
        await ejecutar { try await self.repo.actualizar(m) }
        irAlMesDe(m)
        await cargar()
        seleccionId = m.id
    }

    /// Capturar (o refechar) un movimiento en un mes distinto del que se está
    /// viendo lo dejaría fuera del filtro: se guarda bien y aun así desaparece
    /// de la lista, que es indistinguible de que no se haya guardado. La vista
    /// se mueve al mes del movimiento. Si se estaban viendo todos los meses no
    /// hay nada que mover.
    private func irAlMesDe(_ m: Movimiento) {
        guard mes != nil else { return }
        mes = Fechas.inicioDeMes(m.fecha)
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

    /// Si el mes elegido no tiene movimientos —al abrir en un mes sin capturas,
    /// o al pasar de Ingresos a Gastos— se cae al más reciente que sí tenga.
    /// Sin esto la pantalla abriría en blanco con todo escondido tras el chip.
    private func ajustarMes() {
        guard let mes, !mesesDisponibles.contains(mes) else { return }
        self.mes = mesesDisponibles.first
    }

    /// Folio previsto para la serie que se está viendo. Orientativo: el
    /// definitivo lo asigna el repositorio al guardar.
    func nuevoFolio() async -> String { await repo.siguienteFolio(tipo: tipo) }

    // MARK: - Derivados

    var seleccion: Movimiento? { items.first { $0.id == seleccionId } }

    /// La lista tras aplicar buscador y chips.
    var itemsFiltrados: [Movimiento] {
        items.filter { m in
            (mes == nil || Fechas.inicioDeMes(m.fecha) == mes)
            && (filtroCategoria == nil || m.categoria == filtroCategoria)
            && (!soloSinDepositar || m.sinDepositar)
            && (!soloPendientes || m.marcadoPendiente)
            && (busqueda.isEmpty
                || m.titular.localizedCaseInsensitiveContains(busqueda)
                || m.folio.contains(busqueda)
                || (m.nota?.localizedCaseInsensitiveContains(busqueda) ?? false))
        }
    }

    var total: Centavos { itemsFiltrados.reduce(0) { $0 + $1.monto } }

    /// Los meses que de verdad tienen movimientos de este tipo, del más
    /// reciente al más antiguo. Es lo que ofrece el selector: un calendario
    /// libre dejaría elegir meses vacíos.
    var mesesDisponibles: [Date] {
        Set(items.map { Fechas.inicioDeMes($0.fecha) }).sorted(by: >)
    }

    /// Las categorías que de verdad aparecen en la lista. Antes eran tres
    /// literales escritos en el código: en Gastos, donde el catálogo tiene
    /// diecinueve, dieciséis no se podían filtrar, y una categoría antigua que
    /// ya no estuviera en el catálogo tampoco. Además estaban sin `L.t`, así
    /// que en inglés no casaban con ningún movimiento y el filtro vaciaba la
    /// lista.
    var categoriasChip: [String] {
        Set(items.map(\.categoria))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
