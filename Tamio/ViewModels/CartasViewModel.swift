import Foundation

@Observable
final class CartasViewModel {
    var emitidas: [CartaEmitida] = []
    var plantillaSeleccionada: TipoPlantilla = .traslado
    var carta = CartaEnEdicion()
    var cargando = false

    private let repo: CartasRepository

    init(repo: CartasRepository = repositorioCartas()) {
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

    /// **Emite la carta entera y la guarda.** Antes construía una fila de
    /// cuatro campos —id, iniciales, el nombre y el tipo— y la metía en el
    /// array: el cuerpo, el destinatario, la fecha y el lugar de emisión, el
    /// asunto, los firmantes y las notas se perdían al emitir. Y la lista se
    /// vaciaba al volver a entrar, porque `cargar()` preguntaba al repositorio
    /// y allí no había nada.
    @MainActor
    func emitirCarta() async {
        guard !carta.aportante.isEmpty else { return }
        let nueva = CartaEmitida(
            id: UUID().uuidString,
            folio: folioSiguiente(),
            tipo: carta.tipo,
            fechaEmision: Fechas.claveDia(carta.fechaEmision),
            lugarEmision: carta.lugarEmision,
            destinatarioTipo: carta.tipoDestinatario,
            destinatarioNombre: carta.aportante,
            destinatarioDireccion: carta.direccionDestinatario,
            asunto: carta.asunto.isEmpty ? carta.tipo.titulo : carta.asunto,
            saludo: carta.saludo,
            cuerpo: carta.cuerpoTexto,
            despedida: carta.cierre,
            // El editor pide una firma y el formulario largo varias: se
            // juntan sin repetir, que es lo que se imprime al pie.
            firmas: ([carta.firma] + carta.firmantes)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } },
            observaciones: carta.notasInternas,
            // Se acaba de firmar y emitir: no nace borrador.
            estado: "emitida")
        try? await repo.guardar(nueva)
        await cargar()

        carta = CartaEnEdicion()
        carta.tipo = plantillaSeleccionada
        carta.aportante = ""
        carta.iglesiaDestino = ""
        carta.miembroDesde = ""
    }

    /// **El folio se cuenta de las emitidas del año**, no de la posición en la
    /// lista. Un folio que se repite es un documento que no se puede citar.
    /// Se queda corto si dos aparatos emiten a la vez sin sincronizar; el
    /// contador de Postgres que ya usan los movimientos es lo que lo resuelve
    /// de verdad, y todavía no cubre cartas.
    private func folioSiguiente() -> String {
        let año = Calendar.current.component(.year, from: Date())
        let prefijo = "\(año)-"
        let usados = emitidas
            .filter { $0.folio.hasPrefix(prefijo) }
            .compactMap { Int($0.folio.dropFirst(prefijo.count)) }
        return String(format: "%d-%03d", año, (usados.max() ?? 0) + 1)
    }
}
