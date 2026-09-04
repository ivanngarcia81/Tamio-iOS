import Foundation
import Observation

@Observable
final class RegistroViewModel {
    private let repo: RegistroRepository

    /// **Solo los apuntes de las áreas que este rol puede ver.**
    ///
    /// El recorte va aquí y no en la vista, a propósito: `todos` alimenta
    /// también los conteos de las pestañas y la selección del detalle, así que
    /// filtrar solo la lista dejaría a la secretaria viendo "Tesorería 14" en
    /// una pestaña vacía —y contando movimientos de dinero que la navegación le
    /// cierra por delante—. La bitácora no puede ser la puerta de atrás.
    private(set) var todos: [Apunte] = []
    /// Las áreas permitidas. Las pone la vista con los permisos vigentes; por
    /// omisión están las dos, que es lo que ve un administrador.
    var areas: [ApunteArea] = [.tesoreria, .secretaria] {
        didSet { if areas != oldValue { aplicarAreas() } }
    }
    private var sinFiltrar: [Apunte] = []
    var filtro: FiltroRegistro = .todo
    var seleccionId: String?

    init(repo: RegistroRepository = MockRegistroRepository()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        sinFiltrar = await repo.apuntes()
        aplicarAreas()
    }

    private func aplicarAreas() {
        todos = sinFiltrar.filter { areas.contains($0.area) }
        // La selección puede haber quedado fuera: un detalle abierto de un
        // apunte que ya no se ve seguiría enseñándolo.
        if let id = seleccionId, !todos.contains(where: { $0.id == id }) {
            seleccionId = nil
        }
    }

    /// Los filtros que tiene sentido ofrecer. Con una sola área, la pestaña de
    /// esa área dice lo mismo que "Todo" y sobra.
    func filtrosVisibles() -> [FiltroRegistro] {
        guard areas.count > 1 else { return [.todo, .notas] }
        return FiltroRegistro.allCases
    }

    var seleccion: Apunte? { todos.first { $0.id == seleccionId } }

    /// Apuntes que pasan el filtro activo.
    var visibles: [Apunte] {
        switch filtro {
        case .todo: return todos
        case .tesoreria: return todos.filter { $0.area == .tesoreria && !$0.esNota }
        case .secretaria: return todos.filter { $0.area == .secretaria && !$0.esNota }
        case .notas: return todos.filter { $0.esNota }
        }
    }

    /// Apuntes visibles agrupados por día, en el orden en que aparecen.
    var grupos: [(titulo: String, apuntes: [Apunte])] {
        var orden: [String] = []
        var mapa: [String: [Apunte]] = [:]
        for a in visibles {
            if mapa[a.grupo] == nil { orden.append(a.grupo) }
            mapa[a.grupo, default: []].append(a)
        }
        return orden.map { ($0, mapa[$0] ?? []) }
    }

    // Conteos para las pestañas y las tarjetas del estado vacío.
    var totalCount: Int { todos.count }
    var tesoreriaCount: Int { todos.filter { $0.area == .tesoreria && !$0.esNota }.count }
    var secretariaCount: Int { todos.filter { $0.area == .secretaria && !$0.esNota }.count }
    var notasCount: Int { todos.filter { $0.esNota }.count }

    func count(_ f: FiltroRegistro) -> Int {
        switch f {
        case .todo: return totalCount
        case .tesoreria: return tesoreriaCount
        case .secretaria: return secretariaCount
        case .notas: return notasCount
        }
    }

    /// Escribe una nota a mano (aparece arriba, en HOY).
    @MainActor
    func escribirNota(texto: String, area: ApunteArea, autor: String) async {
        let nuevo = Apunte(
            id: UUID().uuidString,
            area: area,
            texto: texto,
            // De la sesión, no escrito a mano: un apunte del registro sin el
            // autor de verdad no vale como apunte.
            autor: autor,
            hora: L.t("ahora", "now"),
            grupo: L.t("HOY", "TODAY"),
            fecha: L.t("Hoy · 30 de agosto", "Today · Aug 30"),
            esNota: true
        )
        await repo.escribirNota(nuevo)
        await cargar()
        seleccionId = nuevo.id
    }
}
