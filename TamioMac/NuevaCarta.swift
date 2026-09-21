import SwiftUI

/// **Redactar una carta, según `handoff7`.**
///
/// Cuatro secciones en su orden: PLANTILLA, DESTINATARIO, CARTA y EMISIÓN. La
/// forma la pone `HojaMac`.
///
/// **Guarda un borrador, no emite.** El botón dice "Guardar el borrador" y el
/// folio que lleva es provisional; el definitivo lo pone el contador del
/// servidor al sincronizar, igual que con las actas. Emitir —firmar y dar
/// folio— es el otro paso, el que ya existe en la pantalla.
///
/// **Las `{{variables}}` se guardan resueltas.** El web da por hecho que una
/// carta guardada ya no las lleva dentro y las enseña tal cual; iOS llegó a
/// guardarlas crudas y una carta emitida desde el teléfono se leía en el
/// escritorio como *"Certificamos que {{miembro_nombre}}"*. Lo hace
/// `guardarBorrador`, que es donde está explicado.
struct NuevaCarta: View {

    let vm: CartasViewModel
    let alGuardar: (CartaEnEdicion) -> Void

    @State private var datos = CartaEnEdicion()
    @State private var intentoGuardar = false
    @State private var padron: [PersonaDelPadron] = []

    /// **Solo los dos tipos que se han visto en la base.**
    ///
    /// El handoff ofrece cuatro —miembro, otra iglesia, portador y otra
    /// persona—, pero de esa columna solo se conocen con certeza las claves
    /// `miembro` e `iglesia`, que son las que trae la tabla. Las otras dos no
    /// se inventan: escribir una clave a ojo en una columna del web es
    /// exactamente el fallo del `estado` traducido. Entran cuando se sepan.
    ///
    /// **Y son claves, no rótulos.** `CartasView` de iOS guarda aquí el texto
    /// traducido del selector —"Miembro registrado", "Registered member"—, que
    /// es el mismo fallo y sigue abierto allá.
    private let tiposDestinatario: [(String, String)] = [
        ("miembro", L.t("Un miembro", "A member")),
        ("iglesia", L.t("Otra iglesia", "Another church"))
    ]

    /// **Lo que se va a borrar del texto al guardar, con nombre y apellido.**
    ///
    /// La carta se guarda con las `{{variables}}` ya sustituidas, y desde el
    /// 21-sep una que no tiene valor se sustituye por NADA. Eso deja una carta
    /// que se lee entera —"ha sido miembro desde  y solicita su traslado"— y
    /// que nadie puede sospechar mirándola: el hueco dejó de verse justo
    /// cuando dejó de imprimirse. **Aquí es el único sitio donde todavía se
    /// sabe cuáles eran**, así que aquí se dice.
    ///
    /// Se mira lo que de verdad se guarda —asunto, saludo, cuerpo y
    /// despedida—, los cuatro que `guardarBorrador` resuelve.
    private var enBlanco: [String] {
        VariablesCarta.faltantes(
            en: [datos.asunto, datos.saludo, datos.cuerpoTexto, datos.cierre],
            contexto: datos.contextoVariables(ConfiguracionIglesiaViewModel.compartido.config))
    }

    /// Las que se arreglan rellenando un campo de esta hoja o de Configuración.
    private var enBlancoConCampo: [String] {
        enBlanco.filter { !VariablesCarta.sinOrigen.contains($0) }
    }

    /// Las que no. Ver `VariablesCarta.sinOrigen`: no es que falte rellenarlas,
    /// es que no hay dónde.
    private var enBlancoSinCampo: [String] {
        enBlanco.filter { VariablesCarta.sinOrigen.contains($0) }
    }

    private var faltan: [String] {
        var f: [String] = []
        if datos.aportante.trimmingCharacters(in: .whitespaces).isEmpty {
            f.append(L.t("a quién va dirigida", "who it is addressed to"))
        }
        return f
    }

    var body: some View {
        HojaMac(titulo: L.t("Nueva carta", "New letter"),
                rotuloGuardar: L.t("Guardar el borrador", "Save the draft"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            plantilla
            destinatario
            cuerpoDeLaCarta
            emision
        }
        .task {
            if padron.isEmpty { padron = await padronParaSelector() }
            // **La plantilla de arriba se aplica también al ABRIR.**
            //
            // El selector nace con una elegida, así que la hoja salía con su
            // nombre puesto y el asunto, el saludo y el cuerpo en blanco: el
            // rótulo prometía un texto que no estaba. `aplicarPlantilla` solo
            // corría al cambiar de opción.
            aplicarPlantilla(datos.tipo)
        }
    }

    // MARK: - Las secciones

    private var plantilla: some View {
        SeccionHoja(
            titulo: L.t("PLANTILLA", "TEMPLATE"),
            nota: L.t("Elegir una plantilla rellena el asunto, el saludo, el cuerpo y la despedida con el texto que la iglesia escribió en el web. Nunca pisa lo que ya hayas escrito.",
                      "Picking a template fills the subject, greeting, body and closing with the text the church wrote in the web app. It never overwrites what you already typed.")
        ) {
            FilaSelector(rotulo: L.t("Plantilla de la iglesia", "Church template"),
                         valor: Binding(
                            get: { datos.tipo },
                            set: { nuevo in aplicarPlantilla(nuevo) }),
                         opciones: opcionesDePlantilla)
            // **Si las plantillas son de respaldo, hay que decirlo.** Una
            // plantilla de respaldo trae el nombre del tipo y nada más —sin
            // asunto, sin saludo, sin cuerpo—, así que redactar con ella da una
            // carta en blanco con pinta de plantilla de la iglesia. Es la
            // lección de §0.-19 metida en la hoja.
            if let motivo = vm.motivoDelRespaldo {
                // **Y el aviso dice CUÁL de los dos vacíos es.** Mandar a mirar
                // la red cuando lo que pasa es que la iglesia no tiene
                // plantillas propias es mandar a buscar donde no está, y pasó
                // de verdad. Las palabras son las mismas que en iOS.
                FilaAviso(texto: {
                    switch motivo {
                    case .noHanBajado:
                        return L.t("Tipos genéricos: las plantillas de la iglesia no han bajado todavía",
                                   "Generic types: the church's templates haven't synced yet")
                    case .laIglesiaNoTiene:
                        return L.t("Tipos genéricos: esta iglesia no tiene plantillas propias",
                                   "Generic types: this church has no templates of its own")
                    }
                }())
            }
        }
    }

    /// Las de la iglesia si las hay; si no, los tipos genéricos. La lista sale
    /// del ViewModel y no de `TipoPlantilla.allCases`: cambiar el texto de una
    /// en el web tiene que llegar aquí.
    private var opcionesDePlantilla: [(TipoPlantilla, String)] {
        vm.plantillas.isEmpty
            ? TipoPlantilla.allCases.map { ($0, $0.titulo) }
            : vm.plantillas.map { ($0.tipo, $0.nombre) }
    }

    private func aplicarPlantilla(_ tipo: TipoPlantilla) {
        datos.tipo = tipo
        // Rellena sin pisar, que es lo que pide la nota del handoff. La regla
        // ya está escrita en el ViewModel; aquí solo se le da la plantilla.
        guard let p = vm.plantillas.first(where: { $0.tipo == tipo }) else { return }
        if datos.asunto.isEmpty { datos.asunto = p.asunto }
        if datos.saludo.isEmpty { datos.saludo = p.saludo }
        if datos.cuerpoTexto.isEmpty { datos.cuerpoTexto = p.cuerpoLlano }
        if datos.cierre.isEmpty { datos.cierre = p.despedida }
    }

    private var destinatario: some View {
        SeccionHoja(titulo: L.t("DESTINATARIO", "RECIPIENT")) {
            FilaSelector(rotulo: L.t("Va dirigida a", "Addressed to"),
                         valor: $datos.tipoDestinatario,
                         opciones: [("", L.t("Elegir…", "Choose…"))] + tiposDestinatario)
            FilaSelector(rotulo: L.t("Miembro", "Member"),
                         valor: $datos.aportante,
                         opciones: [("", L.t("Elegir a alguien", "Pick someone"))]
                            + padron.map { ($0.nombre, $0.nombre) })
            FilaTexto(rotulo: L.t("Iglesia de destino", "Receiving church"),
                      valor: $datos.iglesiaDestino,
                      marcador: L.t("Solo para un traslado", "Only for a transfer"))
            FilaTexto(rotulo: L.t("Dirección", "Address"),
                      valor: $datos.direccionDestinatario,
                      marcador: L.t("Opcional", "Optional"))
        }
    }

    private var cuerpoDeLaCarta: some View {
        SeccionHoja(
            titulo: L.t("CARTA", "LETTER"),
            nota: L.t("Las variables se escriben así: {{miembro_nombre}}. Se sustituyen por sus valores al guardar — una carta nunca se queda con ellas crudas dentro.",
                      "Variables are written as {{miembro_nombre}}. They are replaced with the real values when you issue the letter — a letter is never stored with them raw inside.")
        ) {
            FilaTexto(rotulo: L.t("Asunto", "Subject"), valor: $datos.asunto)
            FilaTexto(rotulo: L.t("Saludo", "Greeting"), valor: $datos.saludo)
            FilaArea(rotulo: L.t("Cuerpo", "Body"), valor: $datos.cuerpoTexto,
                     marcador: "{{miembro_nombre}}", lineas: 5...12)
            FilaTexto(rotulo: L.t("Despedida", "Closing"), valor: $datos.cierre)
            // **No bloquea: informa.** Una carta a la que le falta la fecha de
            // membresía se puede querer emitir igual, y decidirlo es de quien
            // firma. Lo que no puede pasar es que se firme sin saberlo, que es
            // lo que pasaba desde que el hueco dejó de imprimirse.
            if !enBlancoConCampo.isEmpty {
                FilaAviso(texto: enBlancoConCampo.count == 1
                          ? L.t("Al guardar, \(VariablesCarta.frase(enBlancoConCampo)) se sustituye por nada y el hueco no se verá. Se rellena arriba o en Configuración.",
                                "When saved, \(VariablesCarta.frase(enBlancoConCampo)) will be replaced by nothing and the gap won't show. Fill it in above or in Settings.")
                          : L.t("Al guardar, \(VariablesCarta.frase(enBlancoConCampo)) se sustituyen por nada y los huecos no se verán. Se rellenan arriba o en Configuración.",
                                "When saved, \(VariablesCarta.frase(enBlancoConCampo)) will be replaced by nothing and the gaps won't show. Fill them in above or in Settings."))
            }
            if !enBlancoSinCampo.isEmpty {
                FilaAviso(texto: enBlancoSinCampo.count == 1
                          ? L.t("No hay de dónde sacar \(VariablesCarta.frase(enBlancoSinCampo)): quítala del cuerpo o escribe el dato a mano.",
                                "There is nowhere to take \(VariablesCarta.frase(enBlancoSinCampo)) from: remove it from the body or type the value by hand.")
                          : L.t("No hay de dónde sacar \(VariablesCarta.frase(enBlancoSinCampo)): quítalas del cuerpo o escribe los datos a mano.",
                                "There is nowhere to take \(VariablesCarta.frase(enBlancoSinCampo)) from: remove them from the body or type the values by hand."))
            }
        }
    }

    private var emision: some View {
        SeccionHoja(
            titulo: L.t("EMISIÓN", "ISSUE"),
            nota: L.t("Un borrador guardado lleva folio provisional. El definitivo —CAR-2026-…— lo asigna el servidor cuando este Mac sincroniza.",
                      "A saved draft carries a provisional folio. The definitive CAR-2026-… folio is assigned by the server when this Mac syncs.")
        ) {
            FilaFecha(rotulo: L.t("Fecha de emisión", "Issue date"),
                      valor: $datos.fechaEmision)
            FilaTexto(rotulo: L.t("Lugar de emisión", "Place of issue"),
                      valor: $datos.lugarEmision)
            FilaFichas(rotulo: L.t("Firmas", "Signatures"), valores: $datos.firmantes,
                       marcador: L.t("Añadir quien firma", "Add signer"))
            FilaArea(rotulo: L.t("Notas internas", "Internal notes"),
                     valor: $datos.notasInternas,
                     marcador: L.t("No se imprimen", "Not printed"), lineas: 2...5)
        }
    }

    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        alGuardar(datos)
        return true
    }
}
