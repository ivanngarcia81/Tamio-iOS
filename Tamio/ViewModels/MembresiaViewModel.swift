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
    /// Una de `EstadoMiembro.claves`: los cuatro del registro o `baja`. Se
    /// filtra por la clave y no por el estado entero porque dos bajas con
    /// distinta fecha son el mismo filtro.
    var filtroEstado: String? = nil
    var filtroMinisterio: String? = nil
    /// Filtro que llega desde los indicadores de la ficha del miembro.
    var filtroAccion: FiltroAccion? = nil

    init(repo: MembresiaRepository = repositorioMembresia()) {
        self.repo = repo
    }

    /// ID disponible para el siguiente miembro que se cree en memoria.
    var proximoId: String { UUID().uuidString }

    // Cada cambio se aplica en memoria al momento —la pantalla no espera al
    // disco— y se persiste detrás. Antes se quedaba solo en memoria, que es
    // por lo que la maqueta olvidaba todo al cerrar.

    @MainActor
    func agregarMiembro(_ nuevo: Miembro) {
        items.insert(nuevo, at: 0)
        seleccionId = nuevo.id
        Task { try? await repo.guardar(nuevo) }
    }

    @MainActor
    func editarMiembro(_ nuevo: Miembro) {
        guard let idx = items.firstIndex(where: { $0.id == nuevo.id }) else { return }
        // Los parentescos viven en su tabla y la hoja no los edita: se
        // conservan los que la ficha ya tenía.
        var editado = nuevo
        editado.familia = items[idx].familia
        items[idx] = editado
        seleccionId = nuevo.id
        Task { try? await repo.guardar(editado) }
    }

    @MainActor
    func agregarSeguimiento(miembroId: String, nota: SeguimientoNota) {
        guard let idx = items.firstIndex(where: { $0.id == miembroId }) else { return }
        items[idx].seguimientoNotas.append(nota)
        let m = items[idx]
        Task { try? await repo.guardar(m) }
    }

    @MainActor
    func agregarPariente(miembroId: String, pariente: Pariente) {
        guard let idx = items.firstIndex(where: { $0.id == miembroId }) else { return }
        items[idx].familia.append(pariente)
        // La misma fila, vista desde la otra ficha si está en la lista.
        if let otro = items.firstIndex(where: { $0.id == pariente.parienteId }) {
            items[otro].familia.append(Pariente(id: pariente.id,
                                                tipo: Parentescos.inverso[pariente.tipo] ?? pariente.tipo,
                                                parienteId: miembroId, nombre: items[idx].nombre))
        }
        Task { try? await repo.agregarPariente(miembroId: miembroId, pariente) }
    }

    @MainActor
    func quitarPariente(miembroId: String, parienteId: String) {
        for i in items.indices { items[i].familia.removeAll { $0.id == parienteId } }
        Task { try? await repo.quitarPariente(id: parienteId) }
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
            (busqueda.isEmpty || coincideBusqueda(m))
            && (filtroAño == nil || m.añoIngreso == filtroAño)
            && (filtroEstado == nil || m.estado.clave == filtroEstado)
            // Por clave, no por etiqueta: "ninos" es el mismo ministerio en
            // español y en inglés.
            && (filtroMinisterio == nil || m.ministerios.contains(filtroMinisterio!))
            && cumpleAccion(m)
        }
    }

    /// **El campo decía "nombre o correo" y solo buscaba por nombre.** El
    /// correo está en `datos`, que es donde la ficha guarda todo lo que no
    /// tiene columna propia, así que buscarlo cuesta una línea; dejar el
    /// buscador prometiendo algo que no hacía costaba más.
    private func coincideBusqueda(_ m: Miembro) -> Bool {
        m.nombre.localizedCaseInsensitiveContains(busqueda)
            || m.correo.localizedCaseInsensitiveContains(busqueda)
    }

    /// La misma regla que ya usaba `itemsAusentes` para las ausencias, y el
    /// expediente con algún campo pendiente para los incompletos.
    private func cumpleAccion(_ m: Miembro) -> Bool {
        switch filtroAccion {
        case nil: return true
        case .ausencias:
            return !m.estado.esBaja && m.tieneAusencias
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
        Array(Set(items.compactMap(\.añoIngreso))).sorted().reversed()
    }

    /// Las CLAVES de los ministerios que alguien tiene, ordenadas por su
    /// etiqueta. El filtro guarda la clave; la hoja enseña la etiqueta.
    var ministeriosDisponibles: [String] {
        Array(Set(items.flatMap(\.ministerios)))
            .sorted { Padron.etiqueta($0).localizedCompare(Padron.etiqueta($1)) == .orderedAscending }
    }

    /// Solo miembros que necesitan seguimiento pastoral.
    var itemsSeguimiento: [Miembro] {
        items.filter { $0.seguimientoRazon != nil }
    }

    /// Miembros con racha de ausencias (para la sección "Sin asistir últimamente").
    var itemsAusentes: [Miembro] {
        items.filter { m in
            guard !m.estado.esBaja else { return false }
            return m.tieneAusencias
        }
    }

    /// Top 5 por porcentaje de asistencia (excluye bajas).
    var masConstantes: [Miembro] {
        items.filter { !$0.estado.esBaja }
            .sorted { $0.asistenciaPct > $1.asistenciaPct }
            .prefix(5)
            .map { $0 }
    }
}
