import Foundation
import Observation

@Observable
final class MembresiaViewModel {
    private let repo: MembresiaRepository

    private(set) var items: [Miembro] = []
    private(set) var resumen: MembresiaResumen?
    private(set) var asistencia: AsistenciaResumen?
    var seleccionId: Int?
    var busqueda = ""
    var filtroAño: Int? = nil
    var filtroEstado: EstadoMiembro? = nil
    var filtroMinisterio: String? = nil

    init(repo: MembresiaRepository = MockMembresiaRepository()) {
        self.repo = repo
    }

    /// ID disponible para el siguiente miembro que se cree en memoria.
    var proximoId: Int { (items.map(\.id).max() ?? 0) + 1 }

    @MainActor
    func agregarMiembro(_ nuevo: Miembro) {
        items.insert(nuevo, at: 0)
        seleccionId = nuevo.id
    }

    @MainActor
    func editarMiembro(_ nuevo: Miembro) {
        guard let idx = items.firstIndex(where: { $0.id == nuevo.id }) else { return }
        items[idx] = nuevo
        seleccionId = nuevo.id
    }

    @MainActor
    func agregarSeguimiento(miembroId: Int, nota: SeguimientoNota) {
        guard let idx = items.firstIndex(where: { $0.id == miembroId }) else { return }
        items[idx].seguimientoNotas.append(nota)
    }

    @MainActor
    func cargar() async {
        resumen    = await repo.resumen()
        asistencia = await repo.asistenciaResumen()
        items = (try? await repo.lista()) ?? []
        if seleccionId == nil || !items.contains(where: { $0.id == seleccionId }) {
            seleccionId = itemsFiltrados.first?.id
        }
    }

    var seleccion: Miembro? { items.first { $0.id == seleccionId } }

    var itemsFiltrados: [Miembro] {
        items.filter { m in
            (busqueda.isEmpty || m.nombre.localizedCaseInsensitiveContains(busqueda))
            && (filtroAño == nil || m.miembroDesde.contains(String(filtroAño!)))
            && (filtroEstado == nil || m.estado == filtroEstado)
            && (filtroMinisterio == nil || m.area.localizedCaseInsensitiveContains(filtroMinisterio!))
        }
    }

    var añosDisponibles: [Int] {
        let años = items.compactMap { m -> Int? in
            guard let r = m.miembroDesde.range(of: "\\d{4}", options: .regularExpression),
                  let año = Int(m.miembroDesde[r]) else { return nil }
            return año
        }
        return Array(Set(años)).sorted().reversed()
    }

    var ministeriosDisponibles: [String] {
        let sin = L.t("Sin área", "No area")
        let todos = items.flatMap { m -> [String] in
            guard m.area != sin else { return [] }
            return m.area.components(separatedBy: ", ")
        }
        return Array(Set(todos)).sorted()
    }

    /// Solo miembros que necesitan seguimiento pastoral.
    var itemsSeguimiento: [Miembro] {
        items.filter { $0.seguimientoRazon != nil }
    }

    /// Miembros con racha de ausencias (para la sección "Sin asistir últimamente").
    var itemsAusentes: [Miembro] {
        items.filter { m in
            guard m.estado != .baja else { return false }
            return m.rachaSinAsistir != L.t("0 servicios", "0 services")
        }
    }

    /// Top 5 por porcentaje de asistencia (excluye bajas).
    var masConstantes: [Miembro] {
        items.filter { $0.estado != .baja }
            .sorted { $0.asistenciaPct > $1.asistenciaPct }
            .prefix(5)
            .map { $0 }
    }
}
