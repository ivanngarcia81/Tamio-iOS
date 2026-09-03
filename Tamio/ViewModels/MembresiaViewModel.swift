import Foundation
import Observation

/// Los dos indicadores de la ficha que exigen una acción y ahora filtran la
/// lista. Antes los ocho números eran solo texto: ninguno llevaba a ningún
/// lado, así que la tesorera veía "21 incompletos" y tenía que ir a buscarlos
/// a mano.
enum FiltroAccion {
    case ausencias, incompletos
}

@Observable
final class MembresiaViewModel {
    private let repo: MembresiaRepository

    private(set) var items: [Miembro] = []
    private(set) var resumen: MembresiaResumen?
    private(set) var asistencia: AsistenciaResumen?
    var seleccionId: String?
    var busqueda = ""
    var filtroAño: Int? = nil
    var filtroEstado: EstadoMiembro? = nil
    var filtroMinisterio: String? = nil
    /// Filtro que llega desde los indicadores de la ficha del miembro.
    var filtroAccion: FiltroAccion? = nil

    init(repo: MembresiaRepository = MockMembresiaRepository()) {
        self.repo = repo
    }

    /// ID disponible para el siguiente miembro que se cree en memoria.
    var proximoId: String { UUID().uuidString }

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
    func agregarSeguimiento(miembroId: String, nota: SeguimientoNota) {
        guard let idx = items.firstIndex(where: { $0.id == miembroId }) else { return }
        items[idx].seguimientoNotas.append(nota)
    }

    @MainActor
    func agregarPariente(miembroId: String, pariente: Pariente) {
        guard let idx = items.firstIndex(where: { $0.id == miembroId }) else { return }
        items[idx].familia.append(pariente)
    }

    @MainActor
    func quitarPariente(miembroId: String, parienteId: String) {
        guard let idx = items.firstIndex(where: { $0.id == miembroId }) else { return }
        items[idx].familia.removeAll { $0.id == parienteId }
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

    /// La pestaña Seguimiento muestra un subconjunto del padrón. Si la selección
    /// vigente no está en él, la lista no resaltaba ninguna fila mientras el
    /// panel derecho mostraba a otra persona (su `?? listActiva.first`), así que
    /// el preseleccionado parecía cambiar solo. Se reajusta al cambiar de vista.
    @MainActor
    func sincronizarSeleccion(enSeguimiento: Bool) {
        let lista = enSeguimiento ? itemsSeguimiento : itemsFiltrados
        if !lista.contains(where: { $0.id == seleccionId }) {
            seleccionId = lista.first?.id
        }
    }

    var itemsFiltrados: [Miembro] {
        items.filter { m in
            (busqueda.isEmpty || m.nombre.localizedCaseInsensitiveContains(busqueda))
            && (filtroAño == nil || m.miembroDesde.contains(String(filtroAño!)))
            && (filtroEstado == nil || m.estado == filtroEstado)
            && (filtroMinisterio == nil || m.area.localizedCaseInsensitiveContains(filtroMinisterio!))
            && cumpleAccion(m)
        }
    }

    /// La misma regla que ya usaba `itemsAusentes` para las ausencias, y el
    /// expediente con algún campo pendiente para los incompletos.
    private func cumpleAccion(_ m: Miembro) -> Bool {
        switch filtroAccion {
        case nil: return true
        case .ausencias:
            return m.estado != .baja && m.rachaSinAsistir != L.t("0 servicios", "0 services")
        case .incompletos:
            return m.expediente.contains { !$0.completo }
        }
    }

    /// Etiqueta del filtro vigente, para el chip que permite quitarlo. Sin ella
    /// la lista quedaría filtrada sin decir por qué.
    var etiquetaFiltroAccion: String? {
        switch filtroAccion {
        case nil: return nil
        case .ausencias: return L.t("Con ausencias", "With absences")
        case .incompletos: return L.t("Expediente incompleto", "Incomplete record")
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
