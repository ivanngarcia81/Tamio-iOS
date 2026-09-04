import Foundation
import Observation

/// Cómo ordenar la lista de cortes.
enum OrdenCorte: String, CaseIterable, Identifiable {
    case reciente, monto
    var id: String { rawValue }
    var etiqueta: String {
        switch self {
        case .reciente: return L.t("Más recientes", "Most recent")
        case .monto: return L.t("Mayor monto", "Highest amount")
        }
    }
}

@Observable
final class DepositosViewModel {
    private let repo: DepositosRepository

    var estado: EstadoDeposito = .pendiente {
        didSet { if estado != oldValue { Task { await cargar() } } }
    }
    var orden: OrdenCorte = .reciente {
        didSet { if orden != oldValue { items = Self.ordenar(items, por: orden) } }
    }
    private(set) var items: [Corte] = []
    private(set) var pendientesTotal: Int = 0   // siempre refleja los pendientes reales
    /// Cuánto dinero está sin depositar ahora mismo. Es el dato que justifica
    /// que la pantalla exista, así que viaja con el conteo: un número de cortes
    /// no dice si lo que espera en caja son $300 o $15,000.
    private(set) var pendientesMonto: Centavos = 0
    var seleccionId: String?

    /// Cuentas bancarias donde se puede depositar. **Vienen del repositorio**,
    /// no de un literal en el ViewModel: estaban escritas a mano aquí, así que
    /// una iglesia con otro banco no tenía forma de nombrarlo y el corte se
    /// quedaba "Sin asignar" para siempre. Su sitio definitivo es Ajustes.
    private(set) var cuentas: [String] = []

    init(repo: DepositosRepository = MockDepositosRepository()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        let traidos = (try? await repo.cortes(estado: estado)) ?? []
        items = Self.ordenar(traidos, por: orden)
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = items.first?.id
        }
        // Carga los pendientes por separado para que el subtítulo siempre sea correcto,
        // independientemente de la pestaña activa (pendientes vs. depositados).
        let todosLospendientes = (try? await repo.cortes(estado: .pendiente)) ?? []
        pendientesTotal = todosLospendientes.count
        pendientesMonto = todosLospendientes.reduce(0) { $0 + $1.montoTotal }
        cuentas = (try? await repo.cuentas()) ?? []
    }

    var seleccion: Corte? { items.first { $0.id == seleccionId } }
    var pendientesCount: Int { pendientesTotal }

    /// Corte por id (para el detalle en la ruta compacta, siempre fresco).
    func corte(_ id: String) -> Corte? { items.first { $0.id == id } }

    /// La cuenta que enseña el subtítulo de la barra. Era "Banorte ··4821"
    /// escrito a mano: la barra nombraba una cuenta aunque ningún corte
    /// pendiente fuera a ella.
    var cuentaResumen: String? {
        let cuentasPendientes = Set(items.filter(\.sinDepositar).map(\.registro.cuenta))
            .filter { $0 != Corte.sinAsignar && !$0.isEmpty }
        return cuentasPendientes.count == 1 ? cuentasPendientes.first : nil
    }

    // MARK: - Acciones

    /// Marca/desmarca un movimiento del corte. Los totales ya no se
    /// "recalculan": son propiedades calculadas del corte.
    @MainActor
    func toggleMovimiento(corteId: String, movId: Int) async {
        await editar(corteId) { c in
            guard let mi = c.movimientos.firstIndex(where: { $0.id == movId }) else { return }
            c.movimientos[mi].seleccionado.toggle()
        }
    }

    /// Marca o desmarca todos de golpe. Un corte de catorce movimientos se
    /// vaciaba a mano, toque por toque.
    @MainActor
    func marcarTodos(corteId: String, _ valor: Bool) async {
        await editar(corteId) { c in
            for i in c.movimientos.indices { c.movimientos[i].seleccionado = valor }
        }
    }

    /// Agrega dinero en caja al corte. **Antes no existía**: un corte nuevo
    /// nacía vacío y no había forma de meterle un solo movimiento, así que el
    /// importe que se tecleaba al crearlo no tenía nada detrás.
    @MainActor
    func agregarMovimiento(corteId: String, _ mov: MovimientoCaja) async {
        await editar(corteId) { c in
            var nuevo = mov
            // Id local del corte: el siguiente libre, para no chocar con los
            // que ya están aunque se borre uno de en medio.
            nuevo.id = (c.movimientos.map(\.id).max() ?? 0) + 1
            c.movimientos.append(nuevo)
        }
    }

    @MainActor
    func quitarMovimiento(corteId: String, movId: Int) async {
        await editar(corteId) { c in
            c.movimientos.removeAll { $0.id == movId }
        }
    }

    /// Asigna la cuenta bancaria del depósito.
    @MainActor
    func asignarCuenta(corteId: String, cuenta: String) async {
        await editar(corteId) { $0.registro.cuenta = cuenta }
    }

    /// Da de alta una cuenta y se la asigna al corte.
    @MainActor
    func agregarCuenta(_ nombre: String, aCorte corteId: String?) async {
        let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        try? await repo.agregarCuenta(limpio)
        cuentas = (try? await repo.cuentas()) ?? cuentas
        if let corteId { await asignarCuenta(corteId: corteId, cuenta: limpio) }
    }

    /// Cambia el periodo contable al que suma el depósito. El checklist decía
    /// "cambia el periodo al registrar el depósito" y no había dónde cambiarlo.
    @MainActor
    func cambiarPeriodo(corteId: String, _ periodo: String) async {
        await editar(corteId) { $0.registro.periodo = periodo }
    }

    /// Cambia la fecha del depósito. Un corte podía quedarse en "Por definir".
    @MainActor
    func cambiarFecha(corteId: String, _ fecha: Date) async {
        await editar(corteId) { $0.registro.fecha = Self.textoFecha(fecha) }
    }

    /// Adjunta (registra el nombre de) la ficha del banco.
    @MainActor
    func adjuntarFicha(corteId: String, nombre: String) async {
        await editar(corteId) { $0.fichaAdjunta = nombre }
    }

    /// Marca el corte como depositado; sale de la pestaña Pendientes.
    @MainActor
    func marcarDepositado(corteId: String) async {
        try? await repo.marcarDepositado(id: corteId)
        await cargar()
    }

    /// Crea un corte nuevo (pendiente). **Sin importe tecleado**: el monto de
    /// un corte es la suma de sus movimientos, así que un número escrito aquí
    /// era una cifra sin nada detrás que además desaparecía al primer toque.
    @MainActor
    func crearCorte(titulo: String, cuenta: String, efectivoEstimado: Centavos?) async {
        let nuevo = Corte(
            id: UUID().uuidString,
            titulo: titulo.trimmingCharacters(in: .whitespaces).isEmpty
                ? L.t("Corte sin título", "Untitled cut")
                : titulo.trimmingCharacters(in: .whitespaces),
            descripcion: L.t("Corte creado hoy · agrega el dinero en caja que va en este depósito",
                             "Cut created today · add the cash entries this deposit covers"),
            estado: .pendiente,
            movimientos: [],
            registro: RegistroDeposito(cuenta: cuenta.isEmpty ? Corte.sinAsignar : cuenta,
                                       fecha: Self.textoFecha(Date()),
                                       periodo: Self.periodoActual),
            efectivoEstimado: efectivoEstimado
        )
        try? await repo.crear(nuevo)
        estado = .pendiente
        await cargar()
        seleccionId = nuevo.id
    }

    // MARK: - Interno

    /// Aplica un cambio al corte en memoria y lo persiste. Los ocho métodos de
    /// arriba repetían este mismo `firstIndex` + `actualizar`.
    @MainActor
    private func editar(_ corteId: String, _ cambio: (inout Corte) -> Void) async {
        guard let ci = items.firstIndex(where: { $0.id == corteId }) else { return }
        cambio(&items[ci])
        try? await repo.actualizar(items[ci])
    }

    private static func ordenar(_ cortes: [Corte], por orden: OrdenCorte) -> [Corte] {
        switch orden {
        case .reciente: return cortes
        case .monto: return cortes.sorted { $0.montoTotal > $1.montoTotal }
        }
    }

    static func textoFecha(_ fecha: Date) -> String {
        let formato = L.esEspanol ? "EEEE d 'de' MMMM" : "EEEE, MMM d"
        return L.formateador(formato).string(from: fecha).capitalized
    }

    static var periodoActual: String { periodo(Date()) }

    static func periodo(_ fecha: Date) -> String {
        L.formateador("LLLL yyyy").string(from: fecha).capitalized
    }

    /// Los doce meses alrededor de hoy, para el menú de periodo contable.
    static var periodosCercanos: [String] {
        let cal = Calendar.current
        return (-6...5).compactMap { cal.date(byAdding: .month, value: $0, to: Date()) }
            .map { periodo($0) }
    }
}
