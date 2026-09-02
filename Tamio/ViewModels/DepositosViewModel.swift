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
    var seleccionId: Int?

    /// Cuentas bancarias disponibles para "Asignar cuenta".
    let cuentas = ["Banorte ··4821", "BBVA ··7730", L.t("Efectivo en caja", "Cash on hand")]

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
    }

    var seleccion: Corte? { items.first { $0.id == seleccionId } }
    var pendientesCount: Int { pendientesTotal }

    /// Corte por id (para el detalle en la ruta compacta, siempre fresco).
    func corte(_ id: Int) -> Corte? { items.first { $0.id == id } }

    // MARK: - Acciones

    /// Marca/desmarca un movimiento del corte y recalcula los totales.
    @MainActor
    func toggleMovimiento(corteId: Int, movId: Int) async {
        guard let ci = items.firstIndex(where: { $0.id == corteId }),
              let mi = items[ci].movimientos.firstIndex(where: { $0.id == movId }) else { return }
        items[ci].movimientos[mi].seleccionado.toggle()
        items[ci] = Self.recomputar(items[ci])
        try? await repo.actualizar(items[ci])
    }

    /// Asigna la cuenta bancaria del depósito.
    @MainActor
    func asignarCuenta(corteId: Int, cuenta: String) async {
        guard let ci = items.firstIndex(where: { $0.id == corteId }) else { return }
        items[ci].registro.cuenta = cuenta
        try? await repo.actualizar(items[ci])
    }

    /// Adjunta (registra el nombre de) la ficha del banco.
    @MainActor
    func adjuntarFicha(corteId: Int, nombre: String) async {
        guard let ci = items.firstIndex(where: { $0.id == corteId }) else { return }
        items[ci].fichaAdjunta = nombre
        try? await repo.actualizar(items[ci])
    }

    /// Marca el corte como depositado; sale de la pestaña Pendientes.
    @MainActor
    func marcarDepositado(corteId: Int) async {
        try? await repo.marcarDepositado(id: corteId)
        await cargar()
    }

    /// Crea un corte nuevo (pendiente) con la cuenta y monto dados.
    @MainActor
    func crearCorte(titulo: String, cuenta: String, monto: Centavos) async {
        let nuevo = Corte(
            id: (Self.maxId(items) + 1),
            titulo: titulo.isEmpty ? L.t("Corte sin título", "Untitled cut") : titulo,
            subtitulo: L.t("0 movimientos · \(cuenta)", "0 entries · \(cuenta)"),
            descripcion: L.t("Corte creado hoy · agrega los movimientos en caja",
                             "Cut created today · add the cash entries"),
            montoTotal: monto, estado: .pendiente,
            efectivoSeleccionado: monto, efectivoEstimado: monto,
            chequesMonto: 0, chequesCount: 0,
            listoParaDepositar: monto, seleccionados: 0, totalSeleccionables: 0,
            chequeos: [
                Chequeo(id: 1, tipo: .duda,
                        titulo: L.t("Corte nuevo", "New cut"),
                        detalle: L.t("Agrega los movimientos en caja y revisa antes de depositar.",
                                     "Add the cash entries and review before depositing."),
                        enlace: nil)
            ],
            movimientos: [],
            registro: RegistroDeposito(cuenta: cuenta,
                                       fecha: L.t("Hoy", "Today"),
                                       periodo: periodoActual, monto: monto)
        )
        try? await repo.crear(nuevo)
        estado = .pendiente
        await cargar()
        seleccionId = nuevo.id
    }

    // MARK: - Cálculo

    /// Recalcula los chips (efectivo, cheques, listo, contadores) desde la
    /// selección actual de movimientos. Es lo que hace "vivos" los totales.
    private static func recomputar(_ c: Corte) -> Corte {
        var c = c
        let sel = c.movimientos.filter { $0.seleccionado }
        let efectivo = sel.filter { !$0.esCheque }.reduce(0) { $0 + $1.monto }
        let cheques = sel.filter { $0.esCheque }
        c.efectivoSeleccionado = efectivo
        c.chequesMonto = cheques.reduce(0) { $0 + $1.monto }
        c.chequesCount = cheques.count
        c.seleccionados = sel.count
        c.totalSeleccionables = c.movimientos.count
        c.listoParaDepositar = efectivo + c.chequesMonto
        c.montoTotal = c.listoParaDepositar
        c.registro.monto = c.listoParaDepositar
        return c
    }

    private static func ordenar(_ cortes: [Corte], por orden: OrdenCorte) -> [Corte] {
        switch orden {
        case .reciente: return cortes.sorted { $0.id > $1.id }
        case .monto: return cortes.sorted { $0.montoTotal > $1.montoTotal }
        }
    }

    private var periodoActual: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: Date()).capitalized
    }

    private static func maxId(_ cortes: [Corte]) -> Int {
        max(cortes.map(\.id).max() ?? 0, 1000)
    }
}
