import Foundation

@Observable
final class CartasViewModel {
    var emitidas: [CartaEmitida] = []
    /// **Las plantillas de la iglesia.** La lista se dibujaba de
    /// `TipoPlantilla.allCases` —quince casos de un `enum`— mientras la base
    /// tenía las once de verdad: cambiar el texto de una en el web no llegaba
    /// aquí, y cinco de las quince ni existen allá.
    var plantillas: [Plantilla] = []
    /// **Las de arriba no son las de la iglesia, son los tipos genéricos**, y
    /// por qué. Pasa cuando la tabla `plantilla` está vacía; lo decide
    /// `PlantillasConRespaldo`, y la pantalla tiene que decirlo porque una
    /// plantilla de respaldo no trae texto que redactar.
    var motivoDelRespaldo: CatalogoPlantillas.MotivoDelRespaldo?
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
    /// del último `await`. `motivoDelRespaldo` ya es la tercera: sale del
    /// mismo catálogo que `plantillas` y se publica pegada a ella, que es la
    /// misma regla.
    func cargar() async {
        cargando = true
        let nuevasEmitidas = (try? await repo.emitidas()) ?? []
        let catalogo = await repositorioPlantillas().catalogo()
        emitidas = nuevasEmitidas
        plantillas = catalogo.lista
        motivoDelRespaldo = catalogo.motivo
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

    @MainActor
    /// **Guarda un borrador, que no es lo mismo que emitir.**
    ///
    /// Lo pide el Mac: su hoja dice "Guardar el borrador" y la nota del handoff
    /// lo explica —*"A saved draft carries a provisional folio. The definitive
    /// CAR-2026-… folio is assigned by the server when this Mac syncs."*—. La
    /// diferencia con `emitirCarta()` es la que hay entre redactar y firmar:
    ///
    /// - El folio es **provisional** (`P-n`) y el bueno lo pone el contador del
    ///   servidor al subir, igual que con las actas.
    /// - El estado nace `"borrador"` y no `"emitida"`.
    /// - **Las `{{variables}}` se guardan resueltas igual**, por lo mismo que
    ///   explica `emitirCarta()`: el web da por hecho que una carta guardada ya
    ///   no las tiene dentro y las enseña tal cual.
    func guardarBorrador(_ datos: CartaEnEdicion) async {
        let ctx = datos.contextoVariables(ConfiguracionIglesiaViewModel.compartido.config)
        func resuelto(_ t: String) -> String { VariablesCarta.aplicar(t, ctx) }
        let nueva = CartaEmitida(
            id: UUID().uuidString,
            folio: FolioCarta.provisional(seq: emitidas.count + 1),
            tipo: datos.tipo,
            fechaEmision: Fechas.claveDia(datos.fechaEmision),
            lugarEmision: datos.lugarEmision,
            destinatarioTipo: datos.tipoDestinatario,
            destinatarioNombre: datos.aportante,
            destinatarioDireccion: datos.direccionDestinatario,
            asunto: resuelto(datos.asunto.isEmpty ? datos.tipo.titulo : datos.asunto),
            saludo: resuelto(datos.saludo),
            cuerpo: resuelto(datos.cuerpoTexto),
            despedida: resuelto(datos.cierre),
            firmas: ([datos.firma] + datos.firmantes)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } },
            observaciones: datos.notasInternas,
            estado: "borrador")
        try? await repo.guardar(nueva)
        await cargar()
    }

    /// **Emite la carta entera y la guarda.** Antes construía una fila de
    /// cuatro campos —id, iniciales, el nombre y el tipo— y la metía en el
    /// array: el cuerpo, el destinatario, la fecha y el lugar de emisión, el
    /// asunto, los firmantes y las notas se perdían al emitir. Y la lista se
    /// vaciaba al volver a entrar, porque `cargar()` preguntaba al repositorio
    /// y allí no había nada.
    ///
    /// **Es la de REDACTAR Y EMITIR de una vez**, que es como emite el iPhone:
    /// nace una carta nueva a partir del formulario. Promover un borrador que
    /// ya existe es `emitir(_:)`, y son dos cosas distintas.
    func emitirCarta() async {
        guard !carta.aportante.isEmpty else { return }
        // **Se guarda con las `{{variables}}` ya sustituidas, no crudas.**
        //
        // El web sustituye al ELEGIR la plantilla (`CartaEditor.tsx`) y guarda
        // el texto resuelto, así que da por hecho que una carta emitida ya no
        // tiene variables dentro: las enseña tal cual. iOS las guardaba crudas
        // —comprobado contra la base, la carta CAR-2026-0006 emitida desde el
        // teléfono llegó con "We certify that {{miembro_nombre}}"—, así que esa
        // carta se lee mal en el escritorio.
        //
        // Aquí y no al elegir la plantilla, que es donde lo hace el web,
        // porque el orden de esta pantalla es el contrario: primero se abre la
        // plantilla y DESPUÉS se escribe a quién va. Al emitir ya se sabe todo.
        let ctx = carta.contextoVariables(ConfiguracionIglesiaViewModel.compartido.config)
        func resuelto(_ t: String) -> String { VariablesCarta.aplicar(t, ctx) }
        let nueva = CartaEmitida(
            id: UUID().uuidString,
            folio: await repo.siguienteFolio(fecha: carta.fechaEmision),
            tipo: carta.tipo,
            fechaEmision: Fechas.claveDia(carta.fechaEmision),
            lugarEmision: carta.lugarEmision,
            destinatarioTipo: carta.tipoDestinatario,
            destinatarioNombre: carta.aportante,
            destinatarioDireccion: carta.direccionDestinatario,
            asunto: resuelto(carta.asunto.isEmpty ? carta.tipo.titulo : carta.asunto),
            saludo: resuelto(carta.saludo),
            cuerpo: resuelto(carta.cuerpoTexto),
            despedida: resuelto(carta.cierre),
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

    /// **Emite un borrador que ya está guardado**, que no es `emitirCarta()`:
    /// esa redacta una carta nueva desde el formulario y esta firma una que ya
    /// existe. Lo pide el Mac, donde redactar y emitir son dos momentos —se
    /// guarda el borrador, se lee el papel al lado, y se emite—.
    ///
    /// **Se guarda la MISMA fila**, con el mismo `id`: lo único que cambia es
    /// el estado. Crear una carta nueva dejaría dos, el borrador y la emitida,
    /// con el mismo texto y dos folios.
    ///
    /// **El folio no se toca.** El que lleva es provisional y el definitivo lo
    /// asigna el contador del servidor al subir, que es lo que dice la banda de
    /// la pantalla y la razón por la que no se numera desde el aparato —dos
    /// aparatos sin sincronizar calculan el mismo número, y así nacieron cuatro
    /// actas con el mismo folio—.
    ///
    /// El rastro en el Registro lo anota el repositorio, no esta función: lo
    /// hace al ver el paso a `"emitida"`, venga de donde venga.
    @MainActor
    func emitir(_ carta: CartaEmitida) async {
        // Una carta ya emitida no se emite dos veces, y `guardar` lo sabe: solo
        // anota el suceso en el PASO a emitida. Aquí se para antes, para que el
        // botón no escriba una fila que no cambia nada.
        guard carta.estado == "borrador" else { return }
        var emitida = carta
        emitida.estado = "emitida"
        try? await repo.guardar(emitida)
        await cargar()
    }

    // El folio ya no se calcula aquí: lo da el repositorio, que cuenta contra
    // la base entera y con el formato del web. Ver `CartasRepository`.
}
