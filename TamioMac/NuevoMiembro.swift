import SwiftUI

/// **El alta y la edición de una ficha del padrón, según `handoff5`.**
///
/// La forma es la de `HojaMac`, común a todas. Lo de aquí son las secciones y
/// los campos, y **el orden y las notas son los del handoff**: QUIÉN ES,
/// ESTADO, VIDA ESPIRITUAL, DATOS DE LA PERSONA, SERVICIO y OTROS.
///
/// Esta hoja se escribió antes con otra forma —dos columnas, cuatro secciones
/// plegables— porque hasta el quinto handoff **no había ninguna hoja dibujada**.
/// Aquella forma se tiró entera.
///
/// **Dónde se añade sobre el handoff, y por qué.** El handoff dibuja menos
/// campos de los que guarda la tabla `aportante`, que es espejo de la del web.
/// Lo que él no pide pero la columna sí tiene entra como una fila más en su
/// sección, con el mismo aspecto: una hoja que no pregunta deja esa columna
/// vacía **solo cuando se da de alta desde el Mac** —el iPhone y el web la
/// siguen llenando—, y eso es una ficha a medias que nadie pidió.
///
/// - **La baja del padrón**, con fecha y motivo. No está en el handoff y sí en
///   la tabla (`fechaBaja`, `motivoBaja`); tiene permiso propio
///   (`administraPadron`) y un disparador en Supabase que la deshace a quien no
///   lo tiene.
/// - **Los cinco catálogos de servicio.** El handoff pide UN selector de
///   ministerio; la tabla guarda cinco listas —ministerios, cargos,
///   instrumentos, habilidades e intereses— y el web las lee. Van como fichas,
///   que es el control que el propio handoff usa para las listas, en vez de un
///   selector que solo podría guardar una.
/// - **Las fechas de los dos bautismos** y el **ID fiscal**, que la tabla tiene
///   y el handoff no dibuja.
///
/// Las reglas de qué se guarda salen de `NuevoMiembroSheet` de iOS.
struct NuevoMiembro: View {

    let proximoId: String
    let miembroExistente: Miembro?
    /// **La baja es un acto de Secretaría**; a quien no le toca, ni se le
    /// enseña la sección. El mismo permiso que en iOS.
    let puedeDarDeBaja: Bool
    let alGuardar: (Miembro) -> Void

    @State private var m: Miembro

    @State private var fechaIngreso: Date
    @State private var tieneFechaNac: Bool
    @State private var fechaNacimiento: Date
    @State private var tieneCongrega: Bool
    @State private var fechaCongrega: Date
    @State private var tieneBautismoAgua: Bool
    @State private var fechaBautismoAgua: Date
    @State private var tieneBautismoEspiritu: Bool
    @State private var fechaBautismoEspiritu: Date
    @State private var deBaja: Bool
    @State private var fechaBaja: Date
    @State private var motivoBaja: String
    @State private var motivoOtro: String

    @State private var intentoGuardar = false

    init(proximoId: String, miembroExistente: Miembro? = nil, puedeDarDeBaja: Bool,
         alGuardar: @escaping (Miembro) -> Void) {
        self.proximoId = proximoId
        self.miembroExistente = miembroExistente
        self.puedeDarDeBaja = puedeDarDeBaja
        self.alGuardar = alGuardar

        let base = miembroExistente ?? Miembro(id: proximoId, nombre: "")
        _m = State(initialValue: base)
        // **`diaDeCalendario` y no `desdeTextoFlexible`**: estas fechas hacen
        // IDA Y VUELTA. Se leen aquí y `construir()` las reescribe con
        // `Fechas.claveDia`, que formatea en la zona del aparato. Leerlas como
        // medianoche UTC y reescribirlas en local resta un día EN CADA GUARDADO
        // al oeste de Greenwich —que es donde está la iglesia—: `2026-09-06 →
        // 05 → 04 → 03`, medido en iOS el 10-sep. Los dos extremos hablan de
        // DÍAS.
        _fechaIngreso = State(initialValue: Fechas.diaDeCalendario(base.fechaIngreso) ?? Date())
        _tieneFechaNac = State(initialValue: !base.nacimiento.isEmpty)
        _fechaNacimiento = State(initialValue: Fechas.diaDeCalendario(base.nacimiento) ?? Date())
        _tieneCongrega = State(initialValue: !base.fechaCongregacion.isEmpty)
        _fechaCongrega = State(initialValue: Fechas.diaDeCalendario(base.fechaCongregacion) ?? Date())
        _tieneBautismoAgua = State(initialValue: !base.fechaBautismoAgua.isEmpty)
        _fechaBautismoAgua = State(initialValue: Fechas.diaDeCalendario(base.fechaBautismoAgua) ?? Date())
        _tieneBautismoEspiritu = State(initialValue: !base.fechaBautismoEspiritu.isEmpty)
        _fechaBautismoEspiritu = State(initialValue: Fechas.diaDeCalendario(base.fechaBautismoEspiritu) ?? Date())

        // La baja se lee del estado, no de `datos`: antes se guardaba como un
        // par etiqueta-valor y no se volvía a leer, así que al editar a alguien
        // dado de baja la fecha volvía a hoy y el motivo en blanco.
        let baja = base.estado.baja
        _deBaja = State(initialValue: baja != nil)
        _fechaBaja = State(initialValue: Fechas.diaDeCalendario(baja?.fecha ?? "") ?? Date())
        let delCatalogo = baja.map { Baja.motivos.contains($0.motivo) && $0.motivo != "otro" } ?? false
        _motivoBaja = State(initialValue: delCatalogo ? baja!.motivo : (baja == nil ? "traslado" : "otro"))
        _motivoOtro = State(initialValue: delCatalogo || baja == nil ? "" : baja!.motivo)
    }

    private var editando: Bool { miembroExistente != nil }

    /// Lo único obligatorio, y con las palabras del handoff (`req:'the full
    /// name'`). El aviso de arriba las usa tal cual.
    private var faltan: [String] {
        m.nombre.trimmingCharacters(in: .whitespaces).isEmpty
            ? [L.t("el nombre completo", "the full name")] : []
    }

    var body: some View {
        // El handoff titula la edición con el nombre delante: "Edit the file ·
        // Ana Torres". Con veinte fichas abiertas al cabo del día, el título es
        // lo único que dice a quién se está tocando.
        HojaMac(titulo: editando
                    ? L.t("Editar la ficha · \(m.nombre)", "Edit the file · \(m.nombre)")
                    : L.t("Nuevo miembro", "New member"),
                rotuloGuardar: editando ? L.t("Guardar los cambios", "Save the changes")
                                        : L.t("Guardar", "Save"),
                faltan: faltan,
                intentoGuardar: intentoGuardar,
                alGuardar: guardar) {
            quienEs
            estadoSeccion
            if puedeDarDeBaja { bajaSeccion }
            vidaEspiritual
            datosDeLaPersona
            servicio
            otros
        }
    }

    // MARK: - Las secciones

    private var quienEs: some View {
        SeccionHoja(
            titulo: L.t("QUIÉN ES", "WHO"),
            nota: L.t("Una ficha cuenta como completa con nombre, teléfono, correo, dirección, bautismo, fecha de nacimiento y estado civil. Lo que falte no impide guardar: sale en la tarjeta de expediente incompleto.",
                      "A record counts as complete with name, phone, email, address, baptism, birth date and marital status. Missing fields don’t block the save — they show up in the incomplete-record card.")
        ) {
            FilaTexto(rotulo: L.t("Nombre completo o de familia", "Full name or family name"),
                      valor: $m.nombre,
                      marcador: L.t("p. ej. Familia Aguilar", "e.g. Familia Aguilar"))
            FilaTexto(rotulo: L.t("Correo", "Email"), valor: $m.correo,
                      marcador: L.t("correo@ejemplo.com", "name@example.com"))
            FilaTexto(rotulo: L.t("Teléfono", "Phone"), valor: $m.telefono)
        }
    }

    private var estadoSeccion: some View {
        SeccionHoja(
            titulo: L.t("ESTADO", "STATUS"),
            nota: L.t("«Recibido como miembro» es el día en que la iglesia lo recibió, no el día en que empezó a venir: ese va en «Se congrega desde».",
                      "“Received as member” is the day the church received them, not the day they started attending — that one goes in “Attends since”.")
        ) {
            FilaSelector(rotulo: L.t("Estado", "Status"),
                         valor: $m.estado.registro,
                         opciones: EstadoRegistro.allCases.map { ($0, $0.etiqueta) })
            FilaFecha(rotulo: L.t("Recibido como miembro", "Received as member"),
                      valor: $fechaIngreso)
        }
    }

    /// **No está en el handoff, y va porque la tabla la tiene.** La baja no es
    /// un estado de la persona: conserva el que tenía y se le añade cuándo y
    /// por qué se fue, como en el servidor.
    private var bajaSeccion: some View {
        SeccionHoja(
            titulo: L.t("BAJA", "REMOVAL"),
            nota: deBaja
                ? L.t("La persona sale del padrón activo. Su historial y sus aportes se conservan.",
                      "The person leaves the active roster. Their history and giving are kept.")
                : nil
        ) {
            FilaInterruptor(rotulo: L.t("Dar de baja del padrón", "Remove from roster"),
                            activo: $deBaja)
            if deBaja {
                FilaFecha(rotulo: L.t("Fecha de baja", "Removal date"), valor: $fechaBaja)
                FilaSelector(rotulo: L.t("Motivo", "Reason"),
                             valor: $motivoBaja,
                             opciones: Baja.motivos.map { ($0, Baja.etiquetaMotivo($0)) })
                if motivoBaja == "otro" {
                    FilaTexto(rotulo: L.t("¿Cuál?", "Which?"), valor: $motivoOtro)
                }
            }
        }
    }

    private var vidaEspiritual: some View {
        SeccionHoja(
            titulo: L.t("VIDA ESPIRITUAL", "SPIRITUAL LIFE"),
            nota: L.t("La fecha es opcional: lo que la secretaria suele saber es si pasó, no cuándo.",
                      "The date is optional: what’s usually known is whether it happened, not when.")
        ) {
            FilaInterruptor(rotulo: L.t("Bautizado en agua", "Baptized in water"),
                            activo: $m.bautizadoAgua)
            if m.bautizadoAgua {
                FilaFechaOpcional(rotulo: L.t("Fecha del bautismo", "Baptism date"),
                                  conocida: $tieneBautismoAgua, valor: $fechaBautismoAgua)
            }
            FilaInterruptor(rotulo: L.t("Bautizado con el Espíritu Santo",
                                        "Baptized with the Holy Spirit"),
                            activo: $m.bautizadoEspiritu)
            if m.bautizadoEspiritu {
                FilaFechaOpcional(rotulo: L.t("Fecha", "Date"),
                                  conocida: $tieneBautismoEspiritu,
                                  valor: $fechaBautismoEspiritu)
            }
            FilaInterruptor(rotulo: L.t("Curso de membresía completado",
                                        "Membership course completed"),
                            activo: $m.cursoMembresia)
        }
    }

    private var datosDeLaPersona: some View {
        SeccionHoja(
            titulo: L.t("DATOS DE LA PERSONA", "PERSONAL"),
            nota: L.t("Se pueden cambiar cuando quieras: una dirección se muda y un estado civil cambia.",
                      "These can be changed anytime.")
        ) {
            FilaFechaOpcional(rotulo: L.t("Fecha de nacimiento", "Birth date"),
                              conocida: $tieneFechaNac, valor: $fechaNacimiento)
            // Claves del web. **Sin valor no es "soltero": es que no se ha
            // preguntado**, y así se guarda.
            FilaSelector(rotulo: L.t("Estado civil", "Marital status"),
                         valor: $m.estadoCivil,
                         opciones: [("", L.t("Sin especificar", "Not known"))]
                            + Padron.estadosCiviles.map { ($0, Padron.etiqueta($0)) })
            FilaTexto(rotulo: L.t("Dirección", "Address"), valor: $m.direccion,
                      marcador: L.t("Opcional", "Optional"))
        }
    }

    private var servicio: some View {
        SeccionHoja(
            titulo: L.t("SERVICIO", "SERVICE"),
            nota: L.t("Los ministerios y los cargos se pueden escribir aunque no estén en la lista: se guardan igual y la iglesia los reutiliza.",
                      "Ministries and roles can be typed even if they aren’t on the list: they are saved all the same and the church reuses them.")
        ) {
            FilaFichas(rotulo: L.t("Ministerios en los que sirve", "Ministries they serve in"),
                       valores: $m.ministerios,
                       marcador: L.t("Ministerio", "Ministry"))
            FilaFichas(rotulo: L.t("Cargos y funciones", "Roles & functions"),
                       valores: $m.cargos, marcador: L.t("Cargo", "Role"))
            FilaFichas(rotulo: L.t("Instrumentos que toca", "Instruments played"),
                       valores: $m.instrumentos, marcador: L.t("Instrumento", "Instrument"))
            FilaFichas(rotulo: L.t("Oficios y habilidades", "Trades & skills"),
                       valores: $m.habilidades, marcador: L.t("Habilidad", "Skill"))
            FilaFichas(rotulo: L.t("Ministerios de interés", "Ministries of interest"),
                       valores: $m.ministeriosInteres,
                       marcador: L.t("Ministerio", "Ministry"))
            FilaTexto(rotulo: L.t("Disponibilidad para servir", "Availability to serve"),
                      valor: $m.disponibilidad,
                      marcador: L.t("Opcional", "Optional"))
            FilaInterruptor(rotulo: L.t("Interés en servir en algún ministerio",
                                        "Interested in serving"),
                            activo: $m.interesServir)
        }
    }

    private var otros: some View {
        SeccionHoja(
            titulo: L.t("OTROS", "OTHER"),
            nota: L.t("Con iglesia anterior, la ficha se lee como recibida por traslado. El ID fiscal hace falta para constancias deducibles.",
                      "With a previous church, the profile reads as received by transfer. The tax ID is needed for deductible receipts.")
        ) {
            FilaTexto(rotulo: L.t("Iglesia anterior", "Previous church"),
                      valor: $m.iglesiaAnterior,
                      marcador: L.t("Si aplica", "If applicable"))
            FilaTexto(rotulo: L.t("ID fiscal", "Tax ID"), valor: $m.idFiscal,
                      marcador: L.t("Opcional", "Optional"))
            FilaFechaOpcional(rotulo: L.t("Se congrega desde", "Attends since"),
                              conocida: $tieneCongrega, valor: $fechaCongrega)
            FilaArea(rotulo: L.t("Notas", "Notes"), valor: $m.notas,
                     marcador: L.t("Opcional", "Optional"), lineas: 3...6)
        }
    }

    // MARK: - Guardar

    private func guardar() -> Bool {
        intentoGuardar = true
        guard faltan.isEmpty else { return false }
        alGuardar(construir())
        return true
    }

    /// La copia editada, con las fechas y la baja puestas en su sitio. Nada
    /// más: lo que la ficha enseña lo calcula `Miembro`.
    private func construir() -> Miembro {
        var r = m
        r.nombre = m.nombre.trimmingCharacters(in: .whitespaces)
        r.fechaIngreso = Fechas.claveDia(fechaIngreso)
        r.nacimiento = tieneFechaNac ? Fechas.claveDia(fechaNacimiento) : ""
        r.fechaCongregacion = tieneCongrega ? Fechas.claveDia(fechaCongrega) : ""
        r.fechaBautismoAgua = (m.bautizadoAgua && tieneBautismoAgua)
            ? Fechas.claveDia(fechaBautismoAgua) : ""
        r.fechaBautismoEspiritu = (m.bautizadoEspiritu && tieneBautismoEspiritu)
            ? Fechas.claveDia(fechaBautismoEspiritu) : ""
        if deBaja {
            let motivo = motivoBaja == "otro"
                ? motivoOtro.trimmingCharacters(in: .whitespaces) : motivoBaja
            r.estado.baja = Baja(fecha: Fechas.claveDia(fechaBaja), motivo: motivo)
        } else {
            r.estado.baja = nil
        }
        return r
    }
}
