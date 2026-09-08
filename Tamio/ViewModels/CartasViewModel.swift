import Foundation

@Observable
final class CartasViewModel {
    var emitidas: [CartaEmitida] = []
    /// **Las plantillas de la iglesia.** La lista se dibujaba de
    /// `TipoPlantilla.allCases` —quince casos de un `enum`— mientras la base
    /// tenía las once de verdad: cambiar el texto de una en el web no llegaba
    /// aquí, y cinco de las quince ni existen allá.
    var plantillas: [Plantilla] = []
    var plantillaSeleccionada: TipoPlantilla = .traslado
    var carta = CartaEnEdicion()
    var cargando = false

    private let repo: CartasRepository

    init(repo: CartasRepository = repositorioCartas()) {
        self.repo = repo
    }

    /// **Las dos listas se calculan primero y se asignan JUNTAS**, sin ningún
    /// `await` entre las dos asignaciones. No es estilo: publicarlas por
    /// separado dejaba la sección "Plantillas" **vacía para siempre** una de
    /// cada cinco veces que se abría Cartas —cabecera dibujada y ni una fila
    /// debajo, mientras "Emitidas este mes" salía entera—.
    ///
    /// Lo que pasaba: entre las dos asignaciones hay un `await`, y si la vista
    /// evalúa su cuerpo justo en ese hueco, la observación de `plantillas` que
    /// ese cuerpo en vuelo estaba registrando se pierde. El dato estaba bien
    /// —instrumentado con `NSLog`, `plantillas` valía 16 también en las
    /// corridas malas—: lo que no llegaba era el aviso a la vista.
    ///
    /// Medido con `pruebas/PlantillasDeCartaUITests.swift`, veinte aperturas
    /// por corrida y dos corridas de cada: **8 de 40 vacías antes, 0 de 40
    /// después**. Se descartaron antes, con el mismo instrumento, esconder la
    /// sección cuando está vacía (2 de 20) y un `Task.yield()` al entrar
    /// (2 de 20).
    ///
    /// **Si se añade una tercera lista aquí, va con las otras dos**, después
    /// del último `await`.
    func cargar() async {
        cargando = true
        let nuevasEmitidas = (try? await repo.emitidas()) ?? []
        let nuevasPlantillas = await repositorioPlantillas().lista()
        emitidas = nuevasEmitidas
        plantillas = nuevasPlantillas
        cargando = false
    }

    func seleccionar(_ tipo: TipoPlantilla) {
        plantillaSeleccionada = tipo
        carta.tipo = tipo
    }

    /// **Elegir una plantilla rellena la carta con su texto.** Antes solo
    /// cambiaba el tipo: el asunto, el saludo, el cuerpo y la despedida que la
    /// iglesia había redactado en el web no se usaban para nada.
    ///
    /// No pisa lo ya escrito: quien lleva media carta redactada y toca otra
    /// plantilla por error no la pierde.
    func seleccionar(_ plantilla: Plantilla) {
        plantillaSeleccionada = plantilla.tipo
        carta.tipo = plantilla.tipo
        if carta.asunto.isEmpty { carta.asunto = plantilla.asunto }
        if carta.saludo.isEmpty { carta.saludo = plantilla.saludo }
        if carta.cuerpoTexto.isEmpty { carta.cuerpoTexto = plantilla.cuerpoLlano }
        if carta.cierre.isEmpty { carta.cierre = plantilla.despedida }
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
            folio: await repo.siguienteFolio(fecha: carta.fechaEmision),
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

    // El folio ya no se calcula aquí: lo da el repositorio, que cuenta contra
    // la base entera y con el formato del web. Ver `CartasRepository`.
}
