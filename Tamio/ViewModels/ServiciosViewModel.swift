import Foundation

@Observable
final class ServiciosViewModel {
    var lista: [Servicio] = []
    var seleccionId: String? = nil
    var cargando = false


    private let repo: ServiciosRepository

    init(repo: ServiciosRepository = repositorioServicios()) {
        self.repo = repo
    }

    var seleccion: Servicio? { lista.first { $0.id == seleccionId } }

    /// El culto cuya lista se va a tomar: **el que está seleccionado**. Antes
    /// esto era un puente que cogía el más reciente de la tabla, porque los
    /// servicios de esta pantalla eran de maqueta y no tenían fila propia. Ya
    /// la tienen.
    var cultoDeLaSeleccion: CultoConLista? {
        guard let s = seleccion else { return nil }
        return CultoConLista(id: s.id, fecha: s.fecha, tipo: s.tipo,
                             presentes: s.historial.last?.presentes ?? 0,
                             enLista: s.historial.last?.total ?? 0)
    }
    var proximoId: String { UUID().uuidString }

    @MainActor
    func agregarServicio(_ nuevo: Servicio) {
        lista.insert(nuevo, at: 0)
        seleccionId = nuevo.id
        Task { try? await repo.guardar(nuevo) }
    }

    /// Reemplaza los nombres del roster. `estadoRoster` NO se toca: se deduce
    /// de los puestos, así que no hay dos verdades que mantener a la par.
    @MainActor
    func actualizarRoster(servicioId: String, personas: [String: String]) {
        guard let idx = lista.firstIndex(where: { $0.id == servicioId }) else { return }
        lista[idx].puestos = lista[idx].puestos.map { p in
            var x = p
            x.nombre = personas[p.id]?.trimmingCharacters(in: .whitespaces) ?? p.nombre
            return x
        }
        let s = lista[idx]
        Task { try? await repo.guardar(s) }
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


// MARK: - Tomar lista

/// El estado de la lista de un culto: el padrón agrupado en familias y quién
/// está marcado.
///
/// **Todos arrancan ausentes y la secretaria marca a los que vinieron**, que
/// es como lo hace el app web. Al revés —todos presentes y desmarcar— parece
/// más rápido y no lo es: el domingo normal viene la mitad, y sobre todo
/// convierte el olvido en una mentira, porque quien no se toca queda contado
/// como presente.
@Observable
final class ListaAsistenciaViewModel {
    private let padron: MembresiaRepository
    private let asistencia: AsistenciaRepository
    let culto: CultoConLista

    private(set) var familias: [Familia] = []
    /// Por id de persona. Lo que se guarda.
    private(set) var marcas: [String: MarcaAsistencia] = [:]
    /// Familias abiertas. Plegadas por omisión: el atajo es el grupo.
    var desplegadas: Set<String> = []
    var busqueda = ""
    private(set) var cargando = true

    init(culto: CultoConLista,
         padron: MembresiaRepository = repositorioMembresia(),
         asistencia: AsistenciaRepository = repositorioAsistencia()) {
        self.culto = culto
        self.padron = padron
        self.asistencia = asistencia
    }

    @MainActor
    func cargar() async {
        // **Quién entra en la lista.** Los del padrón que no están de baja:
        // activos, visitantes y los que están en proceso, como el roster de
        // asistencia del web. A quien se fue no se le toma lista.
        let todos = ((try? await padron.lista()) ?? []).filter { !$0.estado.esBaja }
        let previas = (try? await asistencia.lista(culto: culto.id)) ?? []
        let porId = Dictionary(previas.map { ($0.miembroId, $0) }, uniquingKeysWith: { a, _ in a })

        familias = Familias.agrupar(todos)
        marcas = Dictionary(uniqueKeysWithValues: todos.map { m in
            (m.id, porId[m.id] ?? MarcaAsistencia(miembroId: m.id, nombre: m.nombre, presente: false))
        })
        cargando = false
    }

    // MARK: Lo que se enseña

    var familiasVisibles: [Familia] {
        guard !busqueda.isEmpty else { return familias }
        // Se busca por persona, pero se enseña la familia: escribir "Sofía"
        // tiene que dejar marcar a Sofía, no esconder a su familia entera.
        return familias.compactMap { f in
            let dentro = f.integrantes.filter { $0.nombre.localizedCaseInsensitiveContains(busqueda) }
            guard !dentro.isEmpty else { return nil }
            return dentro.count == f.integrantes.count
                ? f
                : Familia(id: f.id, apellido: f.apellido, integrantes: dentro)
        }
    }

    var presentes: Int { marcas.values.filter(\.presente).count }
    var total: Int { marcas.count }
    var pct: Double { total > 0 ? Double(presentes) / Double(total) : 0 }

    /// Cuántos de la familia están marcados. Con `nil` la familia no tiene a
    /// nadie; con el total, están todos.
    func presentesDe(_ f: Familia) -> Int {
        f.integrantes.filter { marcas[$0.id]?.presente == true }.count
    }

    func estaPresente(_ id: String) -> Bool { marcas[id]?.presente == true }

    // MARK: Marcar

    /// La familia entera de un toque. Si falta alguien, marca a todos; si ya
    /// están todos, los quita. **Y después se puede desmarcar a uno**: el
    /// grupo es un atajo, no una afirmación.
    @MainActor
    func alternarFamilia(_ f: Familia) {
        let todos = presentesDe(f) == f.integrantes.count
        for m in f.integrantes { marcar(m.id, presente: !todos) }
    }

    @MainActor
    func alternar(_ id: String) { marcar(id, presente: !estaPresente(id)) }

    @MainActor
    private func marcar(_ id: String, presente: Bool) {
        guard var m = marcas[id] else { return }
        m.presente = presente
        // Presente borra la razón y el seguimiento: no se puede estar aquí y
        // tener un motivo para no estar.
        if presente { m.razon = ""; m.razonOtra = ""; m.seguimiento = false }
        marcas[id] = m
    }

    @MainActor
    func ponerRazon(_ id: String, _ razon: String) {
        guard var m = marcas[id], !m.presente else { return }
        m.razon = razon
        marcas[id] = m
    }

    @MainActor
    func alternarSeguimiento(_ id: String) {
        guard var m = marcas[id], !m.presente else { return }
        m.seguimiento.toggle()
        marcas[id] = m
    }

    func guardar() async {
        // En el orden del padrón, no en el del diccionario: así el archivo
        // que se sube no baila entre guardados.
        let ordenadas = familias.flatMap(\.integrantes).compactMap { marcas[$0.id] }
        try? await asistencia.guardarLista(culto: culto.id, ordenadas)
    }
}
