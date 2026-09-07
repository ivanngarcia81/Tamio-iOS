import Foundation

@Observable
final class ActasViewModel {
    var lista: [Acta] = []
    var seleccionId: String? = nil
    var cargando = false

    private let repo: ActasRepository

    init(repo: ActasRepository = repositorioActas()) {
        self.repo = repo
    }

    var seleccion: Acta? { lista.first { $0.id == seleccionId } }
    var proximoId: String { UUID().uuidString }

    /// **El subtítulo de la pantalla, contado.** Iba escrito a mano —"Acta
    /// 2026-08 en borrador"— y por eso nombraba esa acta con las que hubiera y
    /// en el estado que estuvieran: una iglesia sin ninguna en borrador leía
    /// que tenía una, y con el folio de otro año.
    ///
    /// Un borrador manda sobre el recuento porque es lo accionable: si hay algo
    /// a medias, eso es lo que hay que saber al abrir la pantalla.
    var subtitulo: String {
        let borradores = lista.filter { $0.estado == .borrador }
        if borradores.count == 1, let a = borradores.first {
            return L.t("Acta \(a.folio) en borrador", "Minutes \(a.folio) in draft")
        }
        if borradores.count > 1 {
            return L.t("\(borradores.count) actas en borrador",
                       "\(borradores.count) minutes in draft")
        }
        if lista.isEmpty { return L.t("Todavía no hay ninguna", "None yet") }
        return lista.count == 1 ? L.t("1 acta", "1 minutes")
                                : L.t("\(lista.count) actas", "\(lista.count) minutes")
    }

    /// **Las tres escriben y recargan.** Antes solo tocaban el array: un acta
    /// nueva se veía hasta salir de la pantalla, y firmarla o cerrarla se
    /// deshacía solo al volver a entrar, porque `cargar()` volvía a pedirle la
    /// lista al repositorio y allí nunca se había escrito nada.
    @MainActor
    func agregarActa(_ nueva: Acta) async {
        try? await repo.guardar(nueva)
        await cargar()
        seleccionId = nueva.id
    }

    @MainActor
    func cerrarActa(id: String) async {
        await cambiarEstado(id: id, a: .cerrada)
    }

    /// **Guarda quién firmó, no solo que se firmó.** Recibía únicamente el id
    /// y ponía el estado en "Firmada": el acta lo decía y no constaba nadie.
    @MainActor
    func firmarActa(id: String, firmas: [FirmaActa]) async {
        guard var acta = lista.first(where: { $0.id == id }) else { return }
        acta.firmas = firmas
        acta.estado = .firmada
        try? await repo.guardar(acta)
        await cargar()
        seleccionId = id
    }

    @MainActor
    private func cambiarEstado(id: String, a estado: EstadoActa) async {
        guard var acta = lista.first(where: { $0.id == id }) else { return }
        acta.estado = estado
        try? await repo.guardar(acta)
        await cargar()
        seleccionId = id
    }

    func cargar() async {
        cargando = true
        lista = (try? await repo.lista()) ?? []
        // Si lo que estaba seleccionado ya no está —se borró en otro
        // aparato—, no se deja el detalle apuntando a un id fantasma.
        if seleccionId == nil || !lista.contains(where: { $0.id == seleccionId }) {
            seleccionId = lista.first?.id
        }
        cargando = false
    }
}
