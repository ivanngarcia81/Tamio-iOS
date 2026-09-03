import Foundation

@Observable
final class ServiciosViewModel {
    var lista: [Servicio] = []
    var seleccionId: String? = nil
    var cargando = false

    private let repo: ServiciosRepository

    init(repo: ServiciosRepository = MockServiciosRepository()) {
        self.repo = repo
    }

    var seleccion: Servicio? { lista.first { $0.id == seleccionId } }
    var proximoId: String { UUID().uuidString }

    @MainActor
    func agregarServicio(_ nuevo: Servicio) {
        lista.insert(nuevo, at: 0)
        seleccionId = nuevo.id
    }

    /// Reemplaza el roster con las asignaciones editadas y recalcula estadoRoster.
    @MainActor
    func actualizarRoster(servicioId: String, personas: [Int: String]) {
        guard let idx = lista.firstIndex(where: { $0.id == servicioId }) else { return }
        lista[idx].roster = lista[idx].roster.map { item in
            let txt = personas[item.id]?.trimmingCharacters(in: .whitespaces)
            let p = (txt?.isEmpty ?? true) ? nil : txt
            return AsignacionRoster(id: item.id, rol: item.rol, persona: p, extras: item.extras)
        }
        let asignados = lista[idx].roster.filter(\.asignado).count
        let total     = lista[idx].roster.count
        lista[idx].estadoRoster = asignados == total ? .completo
                                : asignados == 0    ? .sinAsignar
                                : .parcial
    }

    /// Añade una entrada de asistencia al historial del servicio.
    @MainActor
    func registrarAsistencia(servicioId: String, presentes: Int, total: Int, fecha: String) {
        guard let idx = lista.firstIndex(where: { $0.id == servicioId }) else { return }
        lista[idx].historial.append(
            AsistenciaServicio(id: UUID().uuidString, fecha: fecha, presentes: presentes, total: total)
        )
    }

    func cargar() async {
        cargando = true
        lista = (try? await repo.proximos()) ?? []
        if seleccionId == nil { seleccionId = lista.first?.id }
        cargando = false
    }
}
