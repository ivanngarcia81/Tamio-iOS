import Foundation

@Observable
final class CartasViewModel {
    var emitidas: [CartaEmitida] = []
    var plantillaSeleccionada: TipoPlantilla = .traslado
    var carta = CartaEnEdicion()
    var cargando = false

    private let repo: CartasRepository

    init(repo: CartasRepository = MockCartasRepository()) {
        self.repo = repo
    }

    func cargar() async {
        cargando = true
        emitidas = (try? await repo.emitidas()) ?? []
        cargando = false
    }

    func seleccionar(_ tipo: TipoPlantilla) {
        plantillaSeleccionada = tipo
        carta.tipo = tipo
    }

    /// Inicia un nuevo borrador a partir de los datos del formulario de creación.
    func nuevaCarta(_ datos: CartaEnEdicion) {
        plantillaSeleccionada = datos.tipo
        carta = datos
        // Si viene un miembro seleccionado del formulario, también lo ponemos en aportante
        if carta.aportante.isEmpty && !datos.miembroSeleccionado.isEmpty {
            carta.aportante = datos.miembroSeleccionado
        }
    }

    /// Emite el borrador actual, lo añade a la lista de emitidas y limpia el editor.
    func emitirCarta() {
        guard !carta.aportante.isEmpty else { return }
        let nueva = CartaEmitida(
            id: UUID().uuidString,
            iniciales: iniciales(carta.aportante),
            persona: carta.aportante,
            tipo: carta.tipo
        )
        emitidas.insert(nueva, at: 0)
        carta = CartaEnEdicion()
        carta.tipo = plantillaSeleccionada
        carta.aportante = ""
        carta.iglesiaDestino = ""
        carta.miembroDesde = ""
    }

    private func iniciales(_ nombre: String) -> String {
        nombre.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }
}
