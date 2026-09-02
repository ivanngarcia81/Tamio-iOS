import Foundation
import Observation

@Observable
final class RegistroViewModel {
    private let repo: RegistroRepository

    private(set) var todos: [Apunte] = []
    var filtro: FiltroRegistro = .todo
    var seleccionId: Int?

    init(repo: RegistroRepository = MockRegistroRepository()) {
        self.repo = repo
    }

    @MainActor
    func cargar() async {
        todos = await repo.apuntes()
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
    func escribirNota(texto: String, area: ApunteArea) async {
        let nuevo = Apunte(
            id: (todos.map(\.id).max() ?? 0) + 1,
            area: area,
            texto: texto,
            autor: "Iván García",
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
