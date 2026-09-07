import SwiftUI

// MARK: - Actas

/// **Siete estados aquí, cinco en el web.** Se guardan LOS SIETE en la base
/// local —por eso el `String` de respaldo— y la traducción a los cinco del web
/// se hace al subir, que es donde se traduce todo lo demás.
///
/// Guardar directamente la clave del web perdía el matiz nada más recargar:
/// firmar un acta la enseñaba como "Aprobada" al volver a entrar, porque
/// `firmada` sube como `aprobada` y volvía como `aprobada`. Lo cazó una
/// prueba, no se vio en pantalla.
enum EstadoActa: String {
    case borrador, pendienteAprobacion, aprobada, enmendada, archivada, firmada, cerrada

    var etiqueta: String {
        switch self {
        case .borrador:            return L.t("Borrador", "Draft")
        case .pendienteAprobacion: return L.t("Pendiente", "Pending approval")
        case .aprobada:            return L.t("Aprobada", "Approved")
        case .enmendada:           return L.t("Enmendada", "Amended")
        case .archivada:           return L.t("Archivada", "Archived")
        case .firmada:             return L.t("Firmada", "Signed")
        case .cerrada:             return L.t("Cerrada", "Closed")
        }
    }
    var estadoVisual: Paleta.Estado {
        switch self {
        // Las dos esperan algo de ti, y llevaban dos naranjas distintos.
        case .borrador, .pendienteAprobacion: return .pendiente
        case .aprobada, .firmada:             return .correcto
        case .enmendada:                      return .informativo
        case .archivada, .cerrada:            return .terminal
        }
    }
    var color: Color { estadoVisual.color }

    /// **La clave del web**, que solo tiene cinco estados:
    /// `borrador | pendiente | aprobada | corregida | archivada`.
    ///
    /// Aquí hay siete porque el iOS separa dos pasos que allá no son estados:
    /// `firmada` —el web guarda las firmas en su propia columna `firmas`, y
    /// un acta con firmas es una acta aprobada— y `cerrada`, que allá es
    /// archivarla. Se mandan como `aprobada` y `archivada`. Es una pérdida
    /// consciente: el matiz vive en la columna `firmas`, que es donde el web
    /// lo busca.
    var clave: String {
        switch self {
        case .borrador:            return "borrador"
        case .pendienteAprobacion: return "pendiente"
        case .aprobada, .firmada:  return "aprobada"
        case .enmendada:           return "corregida"
        case .archivada, .cerrada: return "archivada"
        }
    }

    init(clave: String) {
        switch clave {
        case "pendiente":  self = .pendienteAprobacion
        case "aprobada":   self = .aprobada
        case "corregida":  self = .enmendada
        case "archivada":  self = .archivada
        // Lo desconocido vuelve como borrador: es el estado que no afirma
        // nada, y dar por aprobada un acta que no se entendió sería peor.
        default:           self = .borrador
        }
    }
}

/// **Los tres renglones de firma de un acta**, en el orden en que se imprimen.
/// Las claves son las del web (`ROLES_FIRMA_ACTA` en `src/db.ts`).
enum RolFirmaActa: String, CaseIterable, Identifiable {
    case preside, secretario, testigo
    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .preside:    return L.t("Preside", "Chair")
        case .secretario: return L.t("Secretario de actas", "Recording secretary")
        case .testigo:    return L.t("Testigo", "Witness")
        }
    }

    init(clave: String) { self = RolFirmaActa(rawValue: clave) ?? .testigo }
}

/// Quién ha firmado un acta. **No es la imagen de una firma** —eso es
/// `FirmasLocales`, que a propósito no se sincroniza—: es la casilla de que
/// esa persona ya firmó, y el día. Igual que `ActaFirma` en el web.
struct FirmaActa: Identifiable, Hashable {
    let rol: RolFirmaActa
    var firmado: Bool
    /// `"YYYY-MM-DD"`, el día en que firmó. Nulo mientras no haya firmado.
    var fecha: String?

    var id: String { rol.rawValue }
}

struct AcuerdoActa: Identifiable {
    let id: Int
    let texto: String
}

/// **Un acta guarda sus campos, no su prosa.**
///
/// Antes tenía siete: folio, tipo, una fecha ya escrita para leer, el número
/// de acuerdos, el estado, un `cuerpo` de texto corrido y los acuerdos. El
/// formulario recogía QUINCE —lugar, horas, quién preside, quién levanta el
/// acta, presentes, ausentes, invitados, quórum, orden del día, resumen,
/// mociones, confidencial— y los fundía todos en ese `cuerpo` antes de
/// devolver el acta. Se veían en pantalla y no existían en ninguna parte:
/// no se podían editar, ni buscar, ni mandar al web, que sí tiene una columna
/// para cada uno.
///
/// Ahora se guardan como los guarda el web (`public.actas`) y `cuerpo` se
/// CALCULA de ellos. Es la regla de siempre: si dos cosas tienen que decir lo
/// mismo, una se deriva de la otra.
struct Acta: Identifiable, Hashable {
    let id: String
    let folio: String
    /// La clave del catálogo del web, no la etiqueta traducida. Ver
    /// `TipoActa`: se guardaba "Consejo" y en inglés "Council", así que la
    /// misma acta cambiaba de tipo al cambiar de idioma.
    let tipo: TipoActa
    /// `"YYYY-MM-DD"`, como en el web. Era la fecha ya escrita —"21 de
    /// agosto"— y con eso no se puede ordenar, ni filtrar, ni guardar.
    let fecha: String
    var estado: EstadoActa
    let items: [AcuerdoActa]
    var tituloPersonalizado: String? = nil

    // Lo que el formulario recogía y se perdía.
    var lugar: String = ""
    var horaInicio: String? = nil
    var horaCierre: String? = nil
    var preside: String = ""
    var secretario: String = ""
    var presentes: [String] = []
    var ausentes: [String] = []
    var invitados: [String] = []
    var quorum: Bool = false
    var agenda: String = ""
    var resumen: String = ""
    var mociones: [String] = []
    var confidencial: Bool = false
    /// **Quién ha firmado.** La hoja de firmas las recogía en un `Set` en
    /// memoria y al terminar solo cambiaba el estado a "Firmada": el acta
    /// decía que estaba firmada y no constaba nadie. La columna del web
    /// llevaba tiempo viajando vacía.
    var firmas: [FirmaActa] = []

    /// **Se cuentan, no se guardan.** Iba como un `Int` propio al lado de
    /// `items`: dos números sobre lo mismo que podían discrepar, que es
    /// exactamente lo que ya pasó en los informes de membresía.
    var acuerdos: Int { items.count }

    var titulo: String {
        if let t = tituloPersonalizado, !t.isEmpty { return t }
        return L.t("Acta \(folio) · \(tipo.etiqueta)", "Minutes \(folio) · \(tipo.etiqueta)")
    }

    /// **Sin el estado**: lo dice la pastilla de la fila, al lado, y repetirlo
    /// cortaba el título —"Minutes 2026-07 · Asse…"—. Lo que queda es lo que la
    /// pastilla NO dice: cuándo fue y cuántos acuerdos salieron.
    var subtitulo: String {
        let ac = acuerdos > 0 ? " · \(acuerdos) \(L.t("acuerdos", "agreements"))" : ""
        return "\(fechaLegible)\(ac)"
    }

    /// `"21 de agosto"` · `"August 21"`. En UTC como el resto de fechas
    /// guardadas; ver `Fechas.diaLegible`.
    var fechaLegible: String {
        guard let d = Fechas.desdeTexto(fecha) else { return fecha }
        let f = L.formateador(L.t("d 'de' MMMM", "MMMM d"))
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d)
    }

    /// El acta redactada. **Se arma de los campos cada vez**, así que corregir
    /// el lugar o añadir un ausente cambia el texto; antes el `cuerpo` se
    /// escribía una vez al crear el acta y se quedaba con lo de aquel día.
    var cuerpo: String {
        let fmtLargo = L.formateador(L.t("d 'de' MMMM 'de' yyyy", "MMMM d, yyyy"))
        fmtLargo.timeZone = TimeZone(identifier: "UTC")
        let fechaLarga = Fechas.desdeTexto(fecha).map { fmtLargo.string(from: $0) } ?? fecha

        let horaTxt = horaInicio.map {
            L.t(", a las \($0) horas", ", at \($0)")
        } ?? ""
        let cierreTxt = horaCierre.map {
            L.t(" Cierre: \($0) h.", " Close: \($0).")
        } ?? ""
        let donde = lugar.isEmpty ? "" : L.t(" en \(lugar)", " at \(lugar)")
        let pres = presentes.isEmpty
            ? L.t("los miembros convocados", "the members convened")
            : presentes.joined(separator: ", ")

        var partes: [String] = []
        partes.append(L.t(
            """
            El \(fechaLarga)\(horaTxt) se celebró \(tipo.fraseEnActa)\(donde).\(cierreTxt)
            Presidió: \(preside.isEmpty ? "—" : preside). Secretaria de actas: \(secretario.isEmpty ? "—" : secretario).
            Miembros presentes: \(pres).
            """,
            """
            On \(fechaLarga)\(horaTxt), \(tipo.fraseEnActa) was held\(donde).\(cierreTxt)
            Presided by: \(preside.isEmpty ? "—" : preside). Recording secretary: \(secretario.isEmpty ? "—" : secretario).
            Members present: \(pres).
            """
        ))
        if !ausentes.isEmpty {
            partes.append(L.t("Ausentes: \(ausentes.joined(separator: ", ")).",
                              "Absent: \(ausentes.joined(separator: ", "))."))
        }
        if !invitados.isEmpty {
            partes.append(L.t("Invitados: \(invitados.joined(separator: ", ")).",
                              "Guests: \(invitados.joined(separator: ", "))."))
        }
        if !agenda.isEmpty {
            partes.append(L.t("Orden del día:\n\(agenda)", "Agenda:\n\(agenda)"))
        }
        if !resumen.isEmpty { partes.append(resumen) }
        if !mociones.isEmpty {
            let lista = mociones.map { "· \($0)" }.joined(separator: "\n")
            partes.append(L.t("Mociones y propuestas:\n\(lista)",
                              "Motions and proposals:\n\(lista)"))
        }
        return partes.joined(separator: "\n\n")
    }

    static func == (l: Acta, r: Acta) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// El catálogo de tipos de acta del web (`Acta.tipo` en `src/db.ts`). Se
/// guardaba la ETIQUETA traducida —"Consejo", y en inglés "Council"—, así que
/// la misma acta cambiaba de tipo al cambiar de idioma y ninguno de los dos
/// valores era el que el web sabe leer.
enum TipoActa: String, CaseIterable {
    case administrativa, lideres, asamblea, pastoral, eleccion
    case nombramiento, recepcion, compraventa, presupuesto, disciplina, otra

    var etiqueta: String {
        switch self {
        case .administrativa: return L.t("Administrativa", "Administrative")
        case .lideres:        return L.t("Consejo", "Council")
        case .asamblea:       return L.t("Asamblea", "Assembly")
        case .pastoral:       return L.t("Pastoral", "Pastoral")
        case .eleccion:       return L.t("Elección", "Election")
        case .nombramiento:   return L.t("Nombramiento", "Appointment")
        case .recepcion:      return L.t("Recepción", "Reception")
        case .compraventa:    return L.t("Compraventa", "Purchase or sale")
        case .presupuesto:    return L.t("Presupuesto", "Budget")
        case .disciplina:     return L.t("Disciplina", "Discipline")
        case .otra:           return L.t("Extraordinaria", "Extraordinary")
        }
    }

    /// **El tipo dicho dentro de la frase del acta, con su artículo.**
    ///
    /// El cuerpo decía "se reunió el \(tipo.lowercased())", que funcionaba
    /// cuando los tipos eran "Consejo" o "Directiva". Con el catálogo del web
    /// —administrativa, pastoral, elección— salió "se reunió el
    /// administrativa": el artículo no concuerda y varias etiquetas son
    /// adjetivos, no sustantivos. Se dice entero aquí en vez de pegar un
    /// artículo fijo a una etiqueta que no se sabe cómo es.
    var fraseEnActa: String {
        switch self {
        case .administrativa: return L.t("la reunión administrativa", "the administrative meeting")
        case .lideres:        return L.t("el consejo", "the council")
        case .asamblea:       return L.t("la asamblea", "the assembly")
        case .pastoral:       return L.t("la reunión pastoral", "the pastoral meeting")
        case .eleccion:       return L.t("la elección", "the election")
        case .nombramiento:   return L.t("el nombramiento", "the appointment")
        case .recepcion:      return L.t("la recepción de miembros", "the reception of members")
        case .compraventa:    return L.t("la sesión de compraventa", "the purchase or sale session")
        case .presupuesto:    return L.t("la reunión de presupuesto", "the budget meeting")
        case .disciplina:     return L.t("la sesión de disciplina", "the discipline session")
        case .otra:           return L.t("la sesión extraordinaria", "the extraordinary session")
        }
    }

    /// Lo que no se reconoce cae en `otra` en vez de tumbar la lista.
    init(clave: String) { self = TipoActa(rawValue: clave) ?? .otra }
}

// MARK: - Servicios

/// Cuánto del roster está cubierto. **Se deduce de los puestos**, no se
/// guarda: un estado escrito a mano y una lista de puestos son dos verdades
/// sobre lo mismo.
enum EstadoRoster {
    case completo, parcial, sinAsignar

    var etiqueta: String {
        switch self {
        case .completo:   return L.t("roster completo", "full roster")
        case .parcial:    return L.t("roster parcial", "partial roster")
        case .sinAsignar: return L.t("sin asignar", "unassigned")
        }
    }
    var estadoVisual: Paleta.Estado {
        switch self {
        case .completo:   return .correcto
        case .parcial:    return .pendiente
        case .sinAsignar: return .terminal
        }
    }
    var color: Color { estadoVisual.color }
}

/// Un culto pasado con lo que se contó, para la gráfica del detalle.
struct AsistenciaServicio: Identifiable {
    let id: String
    let fecha: String
    let presentes: Int
    let total: Int
    var pct: Double { total > 0 ? Double(presentes) / Double(total) : 0 }
}

/// Quién hace qué en un culto. Espejo de `servicio_puestos`.
///
/// `miembroId` es opcional a propósito, como allí: quien toca el bajo un
/// domingo puede no tener ficha. `nombre` se guarda igual, y es el que la
/// persona tenía ese día.
struct PuestoServicio: Identifiable, Hashable {
    let id: String
    var puesto: String          // clave de `Puestos`
    var nombre: String
    var miembroId: String?

    var asignado: Bool { !nombre.trimmingCharacters(in: .whitespaces).isEmpty }
    var etiqueta: String { Puestos.etiqueta(puesto) }
    var display: String { asignado ? nombre : L.t("Asignar encargado", "Assign person") }
}

/// Los puestos habituales de un culto. Catálogo ABIERTO como los del padrón:
/// una iglesia con "Proyección" la escribe y se guarda tal cual.
enum Puestos {
    static let habituales = ["predicacion", "alabanza", "ujieres", "ofrenda",
                             "sonido", "ninos", "oracion"]

    static func etiqueta(_ clave: String) -> String {
        switch clave {
        case "predicacion": return L.t("Predicación", "Preaching")
        case "alabanza":    return L.t("Alabanza", "Worship")
        case "ujieres":     return L.t("Ujieres", "Ushers")
        case "ofrenda":     return L.t("Ofrenda", "Offering")
        case "sonido":      return L.t("Sonido", "Sound")
        case "ninos":       return L.t("Niños", "Children")
        case "oracion":     return L.t("Oración", "Prayer")
        default:            return clave
        }
    }
}

struct PuntoOrden: Identifiable, Hashable {
    let id: String
    var posicion: Int
    var hora: String
    var titulo: String
    var encargado: String
}

/// Una persona que vino sin tener ficha. Viaja dentro de
/// `servicios.visitantes` como JSON, que es donde el web la guarda.
struct VisitanteServicio: Codable, Hashable, Identifiable {
    var id: String { nombre }
    var nombre: String
    var telefono: String?
    var correo: String?
    var invitadoPor: String?
    var primeraVisita: Bool = false
    var notas: String?

    enum CodingKeys: String, CodingKey {
        case nombre, telefono, correo, notas
        case invitadoPor   = "invitado_por"
        case primeraVisita = "primera_visita"
    }
}

/// Un culto: **la fila, con forma de fila.**
///
/// Antes tenía forma de pantalla —`diaSemana`, `numDia`, `hora`, `lugar`,
/// `titulo`— y ninguno de esos cinco existe en `servicios`. Lo que hay allí es
/// la fecha y el tipo; el titular y el día se calculan. `hora` y `lugar` se
/// van: el servidor no los tiene, y la hora de verdad está en el orden del
/// culto, punto por punto.
struct Servicio: Identifiable, Hashable {
    let id: String
    var fecha: String = ""        // "YYYY-MM-DD"
    var tipo: String = "dominical"
    var dirige = ""
    var predica = ""
    var tituloMensaje = ""
    var textoBiblico = ""
    var resumenMensaje = ""
    var participaciones: [String] = []
    var temaEscuela = ""
    var maestroEscuela = ""
    var visitantes: [VisitanteServicio] = []
    var ninos = 0
    var jovenes = 0
    var adultos = 0
    var eventos = ""
    /// De `servicioPuesto` y `servicioOrden`.
    var puestos: [PuestoServicio] = []
    var orden: [PuntoOrden] = []
    /// Lo que se contó, para la gráfica del detalle. Se cuenta, no se guarda.
    var historial: [AsistenciaServicio] = []

    // MARK: Derivados

    var titulo: String { Cultos.etiqueta(tipo) }

    /// "DOM" · "SUN". Del formateador y no de una tabla: el día de la semana
    /// de una fecha no se traduce a mano.
    ///
    /// **Y en UTC.** Las dos leían la fecha con el calendario del aparato
    /// mientras el subtítulo la leía con `diaLegible`, que fija UTC: la
    /// pastilla decía "SAT 5" al lado de "Sep 6, 2026", que es domingo. Un día
    /// entero de diferencia dentro de la misma fila, y en la pantalla que
    /// justamente sirve para saber qué culto es cuál.
    var diaSemana: String { Fechas.diaSemanaCorto(fecha) }
    var numDia: String { Fechas.numeroDeDia(fecha) }
    var fechaLegible: String { fecha.isEmpty ? "" : Fechas.diaLegible(fecha) }

    var estadoRoster: EstadoRoster {
        let asignados = puestos.filter(\.asignado).count
        if puestos.isEmpty || asignados == 0 { return .sinAsignar }
        return asignados == puestos.count ? .completo : .parcial
    }

    /// **Sin el estado del roster.** Lo dice la pastilla de la fila, a dos
    /// centímetros, y repetirlo aquí gastaba el ancho que necesita el título:
    /// "Culto dominical" se cortaba para dejar sitio a un dato que ya estaba
    /// puesto al lado. La fecha sí, que la pastilla no la dice.
    var subtitulo: String { fechaLegible }

    static func == (l: Servicio, r: Servicio) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Cartas

enum TipoPlantilla: String, CaseIterable, Identifiable {
    // Ordered to match web app screenshot
    case recomendacion, certificadoMiembro, buenaConducta, presentacion
    case invitacion, agradecimiento, autorizacion, solicitud
    case nombramiento, reconocimiento, certificadoServicio
    case traslado, personalizada
    /// **Del catálogo del web y no estaba aquí.** Lo destapó la primera
    /// sincronización con la cuenta real: dos de las cinco cartas de la
    /// iglesia son de tipo `certificacion` y salían como "Personalizada",
    /// porque el `rawValue` no existía. Ver `clave`.
    case certificacion
    // Legacy — kept for existing mock data
    case bautismo, bienvenida
    var id: String { rawValue }

    /// **La clave del web** (`TIPOS_INICIALES` en
    /// `services/cartas/plantillas.ts`), que no es el nombre del `case` en
    /// tres de ellas: allá se llaman `constanciaActivo` y `constanciaServicio`
    /// —aquí `certificadoMiembro` y `certificadoServicio`— y existe
    /// `certificacion`, que aquí no existía.
    ///
    /// Sin esto, una carta bajada del web con cualquiera de esos tres tipos
    /// se leía como `personalizada`: se veía bien en la lista porque la fila
    /// enseña el nombre del destinatario, y el tipo equivocado solo salía al
    /// abrirla. Los cinco que no están en su catálogo —autorizacion,
    /// solicitud, reconocimiento, bautismo, bienvenida— viajan con su propio
    /// nombre, que es lo que ya hacían.
    var clave: String {
        switch self {
        case .certificadoMiembro:  return "constanciaActivo"
        case .certificadoServicio: return "constanciaServicio"
        default:                   return rawValue
        }
    }

    /// Lo que no se reconoce vuelve como `personalizada`, que es como el web
    /// llama a una carta que no sigue plantilla.
    init(clave: String) {
        self = TipoPlantilla.allCases.first { $0.clave == clave } ?? .personalizada
    }

    var titulo: String {
        switch self {
        case .recomendacion:        return L.t("Carta de recomendación", "Recommendation letter")
        case .certificadoMiembro:   return L.t("Constancia de membresía activa", "Active member certificate")
        case .buenaConducta:        return L.t("Carta de buena conducta", "Good conduct letter")
        case .presentacion:         return L.t("Carta de presentación", "Introduction letter")
        case .invitacion:           return L.t("Carta de invitación", "Invitation")
        case .agradecimiento:       return L.t("Carta de agradecimiento", "Thank you letter")
        case .autorizacion:         return L.t("Carta de autorización", "Authorization")
        case .solicitud:            return L.t("Solicitud", "Request")
        case .nombramiento:         return L.t("Nombramiento ministerial", "Ministerial appointment")
        case .reconocimiento:       return L.t("Reconocimiento", "Recognition")
        case .certificadoServicio:  return L.t("Constancia de servicio", "Certificate of service")
        case .traslado:             return L.t("Carta de traslado", "Transfer letter")
        case .certificacion:        return L.t("Certificación", "Certification")
        case .personalizada:        return L.t("Personalizada", "Custom")
        case .bautismo:             return L.t("Constancia de bautismo", "Baptism certificate")
        case .bienvenida:           return L.t("Carta de bienvenida", "Welcome letter")
        }
    }
    var subtitulo: String {
        switch self {
        case .recomendacion:       return L.t("Buena conducta y membresía", "Good conduct & membership")
        case .certificadoMiembro:  return L.t("Con folio y datos de membresía", "With membership number and data")
        case .buenaConducta:       return L.t("Para gestiones externas", "For external procedures")
        case .presentacion:        return L.t("Ante otra congregación o institución", "To another congregation")
        case .invitacion:          return L.t("Para evento o actividad", "For an event or activity")
        case .agradecimiento:      return L.t("Donativo o servicio recibido", "For a donation or service rendered")
        case .autorizacion:        return L.t("Permiso o delegación de funciones", "Permission or delegation")
        case .solicitud:           return L.t("Petición formal a institución", "Formal request to an institution")
        case .nombramiento:        return L.t("Cargo pastoral o ministerial", "Pastoral or ministerial role")
        case .reconocimiento:      return L.t("Años de servicio o logro", "Years of service or achievement")
        case .certificadoServicio: return L.t("Historial de participación", "Participation record")
        case .certificacion:       return L.t("Certificación general", "General certification")
        case .traslado:            return L.t("Aportante que cambia de iglesia", "Member changing church")
        case .personalizada:       return L.t("Sin plantilla predefinida", "No predefined template")
        case .bautismo:            return L.t("Con fecha y oficiante", "With date and officiant")
        case .bienvenida:          return L.t("Nuevo miembro recibido", "New member received")
        }
    }
    var icono: String {
        switch self {
        // `doc.badge.checkmark` NO existe en SF Symbols, así que la primera
        // plantilla de la lista salía con el cuadro en blanco. Comprobados los
        // 104 nombres de símbolo del proyecto contra el catálogo del sistema:
        // era el único inválido.
        case .recomendacion:       return "text.badge.checkmark"
        case .certificadoMiembro:  return "checkmark.circle"
        case .buenaConducta:       return "checkmark.seal"
        case .presentacion:        return "hand.raised"
        case .invitacion:          return "envelope.badge"
        case .agradecimiento:      return "heart.text.clipboard"
        case .autorizacion:        return "pencil.circle"
        case .solicitud:           return "doc.text"
        case .nombramiento:        return "star.circle"
        case .reconocimiento:      return "star.fill"
        case .certificadoServicio: return "list.bullet.rectangle"
        case .certificacion:       return "rosette"
        case .traslado:            return "arrow.right.doc.on.clipboard"
        case .personalizada:       return "doc.badge.plus"
        case .bautismo:            return "drop.circle"
        case .bienvenida:          return "hand.wave"
        }
    }
}

/// **Una carta emitida guarda la carta, no un renglón de lista.**
///
/// Tenía cuatro campos: id, iniciales, un texto "Javier Medina · traslado" y
/// el tipo. El editor recogía la fecha y el lugar de emisión, el
/// destinatario y su dirección, el asunto, el saludo, el cuerpo, la despedida,
/// los firmantes y las notas internas, y `emitirCarta()` los tiraba todos para
/// quedarse con el nombre. Emitir una carta no dejaba la carta en ninguna
/// parte: dejaba una fila que decía que se había emitido.
///
/// Los campos son los de `public.cartas`. `iniciales` y `persona` se derivan,
/// que es lo que siempre fueron.
struct CartaEmitida: Identifiable {
    let id: String
    let folio: String
    let tipo: TipoPlantilla
    /// `"YYYY-MM-DD"`, como en el web.
    let fechaEmision: String
    var lugarEmision: String = ""
    var destinatarioTipo: String = ""
    var destinatarioNombre: String = ""
    var destinatarioDireccion: String = ""
    var asunto: String = ""
    var saludo: String = ""
    var cuerpo: String = ""
    var despedida: String = ""
    var firmas: [String] = []
    var observaciones: String = ""
    /// `borrador | emitida | entregada`, como allá.
    var estado: String = "borrador"
    var entregadaA: String = ""
    var fechaEntrega: String? = nil

    /// Lo que la fila enseña: "Javier Medina · traslado". Se armaba a mano al
    /// emitir y se guardaba ya escrito, así que en inglés seguía diciendo
    /// "traslado".
    var persona: String {
        destinatarioNombre.isEmpty
            ? tipo.titulo
            : "\(destinatarioNombre) · \(tipo.titulo.lowercased())"
    }

    var iniciales: String {
        destinatarioNombre.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// **Nace VACÍA.** Traía cuatro valores de maqueta escritos dentro —"Javier
/// Medina Cruz", "Iglesia El Buen Pastor", "2018", "Pastor Abel Ramos"—, y esos
/// cuatro son exactamente los tres que cuenta `camposCompletos` más la firma:
/// con ellos puestos, la comprobación de "faltan campos por completar" se
/// cumplía sola y se podía firmar y emitir una carta **sin haber escrito
/// nada**, a nombre de una persona que no existe y firmada por un pastor que
/// tampoco.
///
/// No es teoría: el 7 de septiembre aparecieron en el registro de la iglesia
/// tres cartas emitidas a Javier Medina Cruz con veinte minutos de diferencia,
/// y no hay ninguna persona con ese nombre en el padrón. Iván lo confirmó —"las
/// tres cartas son maquetas"— y de ahí salió esto.
///
/// La firma la propone la iglesia de Ajustes, que es de donde salen el membrete
/// y los cargos: proponer un dato de la iglesia es ayudar, inventarlo es otra
/// cosa.
struct CartaEnEdicion {
    // Campos existentes (usados por el editor de detalle)
    var tipo: TipoPlantilla = .traslado
    var aportante: String = ""
    var iglesiaDestino: String = ""
    var miembroDesde: String = ""
    var firma: String = ConfiguracionIglesiaViewModel.compartido.config.pastorNombre

    var camposCompletos: Int {
        [aportante, iglesiaDestino, miembroDesde].filter { !$0.isEmpty }.count
    }
    var camposTotales: Int { 3 }

    // Campos del formulario de creación
    var fechaEmision: Date = Date()
    var lugarEmision: String = ""
    var tipoDestinatario: String = ""
    var miembroSeleccionado: String = ""
    var direccionDestinatario: String = ""
    var asunto: String = ""
    var saludo: String = ""
    var cuerpoTexto: String = ""
    var cierre: String = ""
    var firmantes: [String] = []
    var estadoCarta: String = ""
    var notasInternas: String = ""
}

// MARK: - Agenda

enum TipoEvento: CaseIterable {
    // Originales (mantenidos para mock existente)
    case culto, reunion, deposito, carta, tarea
    // Nuevos — coinciden con la app web
    case cultoEspecial, reunionLideres, reunionAdministrativa
    case asamblea, cenaPascual, bautismo, dedicacionNino
    case boda, vigilia, campana, conferencia, retiro
    case ensayo, actividadJovenes, actividadHombres, actividadDamas
    case actividadNinos, actividadComunitaria, fechaLimite, otro

    var titulo: String {
        switch self {
        case .culto:                 return L.t("Culto regular", "Regular service")
        case .cultoEspecial:         return L.t("Culto especial", "Special service")
        case .reunionLideres:        return L.t("Reunión de líderes", "Leaders' meeting")
        case .reunionAdministrativa: return L.t("Reunión administrativa", "Administrative meeting")
        case .reunion:               return L.t("Reunión", "Meeting")
        case .asamblea:              return L.t("Asamblea", "Assembly")
        case .cenaPascual:           return L.t("Cena del Señor", "Lord's Supper")
        case .bautismo:              return L.t("Bautismo", "Baptism")
        case .dedicacionNino:        return L.t("Dedicación de niño", "Child dedication")
        case .boda:                  return L.t("Boda", "Wedding")
        case .vigilia:               return L.t("Vigilia", "Vigil")
        case .campana:               return L.t("Campaña", "Campaign")
        case .conferencia:           return L.t("Conferencia", "Conference")
        case .retiro:                return L.t("Retiro", "Retreat")
        case .ensayo:                return L.t("Ensayo", "Rehearsal")
        case .actividadJovenes:      return L.t("Actividad de jóvenes", "Youth activity")
        case .actividadHombres:      return L.t("Actividad de hombres", "Men's activity")
        case .actividadDamas:        return L.t("Actividad de damas", "Women's activity")
        case .actividadNinos:        return L.t("Actividad de niños", "Children's activity")
        case .actividadComunitaria:  return L.t("Actividad comunitaria", "Community activity")
        case .deposito:              return L.t("Depósito", "Deposit")
        case .carta:                 return L.t("Carta", "Letter")
        case .fechaLimite:           return L.t("Fecha límite", "Deadline")
        case .tarea:                 return L.t("Tarea", "Task")
        case .otro:                  return L.t("Otra actividad", "Other activity")
        }
    }

    var color: Color {
        switch self {
        case .culto, .cultoEspecial, .cenaPascual, .bautismo,
             .dedicacionNino, .boda, .vigilia, .campana:
            return Paleta.brand
        case .reunion, .reunionLideres, .reunionAdministrativa, .asamblea:
            return Color(hex: 0x7C3AED)
        case .conferencia, .retiro, .ensayo, .actividadJovenes, .actividadHombres,
             .actividadDamas, .actividadNinos, .actividadComunitaria:
            return Color(hex: 0x3B82F6)
        case .deposito:
            return Color(hex: 0xF97316)
        case .carta:
            return Color(hex: 0x06B6D4)
        case .tarea, .fechaLimite, .otro:
            return Color(.secondaryLabel)
        }
    }

    /// **La clave con la que se guarda, que es la del web** (`TIPOS_ACTIVIDAD`
    /// en `src/db.ts`). No es el nombre del `case`: el web lleva años con
    /// `cultoRegular`, `santaCena` o `actividadJuvenil` escritos en su tabla y
    /// quien manda en el esquema es él. Un `enum` sin `rawValue` no puede
    /// viajar, y ponerle uno derivado del nombre habría escrito `culto` donde
    /// el web espera `cultoRegular`.
    ///
    /// Las cuatro de abajo —`reunion`, `deposito`, `carta`, `tarea`— no existen
    /// en el catálogo del web: vienen de la semilla de la maqueta, que mezclaba
    /// actividades de verdad con recordatorios derivados de otras tablas (un
    /// depósito pendiente, una carta sin firmar, la bandeja por revisar). Se
    /// guardan como `otra` para no meter en `agenda` un tipo que el web no
    /// sabría dibujar, y por eso no sobreviven a un viaje de ida y vuelta.
    var clave: String {
        switch self {
        case .culto:                 return "cultoRegular"
        case .cultoEspecial:         return "cultoEspecial"
        case .reunionLideres:        return "reunionLideres"
        case .reunionAdministrativa: return "reunionAdministrativa"
        case .asamblea:              return "asamblea"
        case .cenaPascual:           return "santaCena"
        case .bautismo:              return "bautismo"
        case .dedicacionNino:        return "presentacionNinos"
        case .boda:                  return "boda"
        case .vigilia:               return "vigilia"
        case .campana:               return "campana"
        case .conferencia:           return "congreso"
        case .retiro:                return "retiro"
        case .ensayo:                return "ensayo"
        case .actividadJovenes:      return "actividadJuvenil"
        case .actividadHombres:      return "actividadCaballeros"
        case .actividadDamas:        return "actividadDamas"
        case .actividadNinos:        return "actividadInfantil"
        case .actividadComunitaria:  return "actividadComunitaria"
        case .fechaLimite:           return "fechaLimite"
        case .reunion, .deposito, .carta, .tarea, .otro: return "otra"
        }
    }

    /// De vuelta. Lo que no se reconoce cae en `otro` en vez de tumbar la
    /// lectura: el web tiene `escuelaBiblica` y `funeral`, que aquí no existen
    /// todavía, y una agenda que no abre por un tipo desconocido es peor que
    /// una que dibuja un icono genérico.
    init(clave: String) {
        // `otra` primero: cinco casos comparten esa clave —las cuatro de la
        // maqueta y `otro`— y buscar por clave devolvería `reunion`, que es la
        // primera del `allCases`. Lo genérico tiene que volver como genérico.
        guard clave != "otra" else { self = .otro; return }
        self = TipoEvento.allCases.first { $0.clave == clave } ?? .otro
    }
}

struct EventoAgenda: Identifiable {
    let id: String
    /// **`"YYYY-MM-DD"`, la fecha entera.** Era solo el día del mes, y con eso
    /// la agenda no podía guardarse: un evento del 21 valía para el 21 de
    /// cualquier mes de cualquier año. El formulario ya recogía la fecha
    /// completa —`fechaEvento` es un `Date`— y `guardar()` la tiraba para
    /// quedarse con el número. El web guarda `fecha` y lo dice en su tipo:
    /// "YYYY-MM-DD (fecha local, nunca UTC)".
    let fecha: String
    let hora: String?
    let titulo: String
    let descripcion: String
    let tipo: TipoEvento
    let completado: Bool
    // Campos extendidos (con defaults para no romper mock existente)
    var todoDia: Bool = false
    var horaFin: String? = nil
    var lugar: String = ""
    /// **El nombre de quien responde, para leer.** Cuando es alguien del
    /// padrón lo rellena el repositorio a partir de `responsableId`, así que
    /// una persona que se case y cambie de apellido no deja actividades
    /// hablando de quien ya no se llama así.
    var responsable: String = ""
    /// **Y su id, que es lo que se guarda.** El web tiene las dos columnas y
    /// son EXCLUYENTES: si el responsable es del padrón guarda el id y deja el
    /// nombre en nulo; si es de fuera, al revés. Aquí faltaba el id entero, así
    /// que una actividad creada en el web con responsable del padrón llegaba al
    /// teléfono sin responsable ninguno —el nombre venía vacío—, y una creada
    /// aquí subía un texto que el web no podía enlazar con nadie.
    var responsableId: String? = nil
    var ministerio: String = ""
    var presupuesto: String = ""
    var notaPie: String = ""
    var repeticion: String = ""
    var estadoEvento: String = ""
    var esFechaImportante: Bool = false
    var recordatorios: [String] = []

    /// El día del mes, para la rejilla. **Se calcula de `fecha`**: el mes lo
    /// filtra el repositorio, así que dentro de una pantalla de agenda dos
    /// eventos con el mismo `dia` son del mismo mes.
    ///
    /// En UTC como el resto de fechas guardadas, por la razón de
    /// `Fechas.diaSemanaCorto`: "2026-09-21" se parsea como medianoche UTC y
    /// leerlo con el calendario del aparato lo corre al 20 en cualquier huso
    /// al oeste de Greenwich, que es donde está la iglesia.
    var dia: Int {
        guard let d = Fechas.desdeTexto(fecha) else { return 1 }
        return Fechas.calendarioUTC.component(.day, from: d)
    }

    /// **Para la semilla de la maqueta, que va por día del mes.** Sus eventos
    /// no tienen año ni mes a propósito —así valen para el mes que se esté
    /// mirando, ver `AgendaViewModel`—, y este init les pone el mes que se les
    /// pida. No lo use código nuevo: un evento de verdad tiene fecha.
    init(id: String, dia: Int, hora: String?, titulo: String, descripcion: String,
         tipo: TipoEvento, completado: Bool, en mes: Date = Date(),
         todoDia: Bool = false, horaFin: String? = nil, lugar: String = "",
         responsable: String = "", responsableId: String? = nil,
         ministerio: String = "", presupuesto: String = "",
         notaPie: String = "", repeticion: String = "", estadoEvento: String = "",
         esFechaImportante: Bool = false, recordatorios: [String] = []) {
        var comps = Calendar.current.dateComponents([.year, .month], from: mes)
        comps.day = dia
        let fecha = Calendar.current.date(from: comps) ?? mes
        self.init(id: id, fecha: Fechas.claveDia(fecha), hora: hora, titulo: titulo,
                  descripcion: descripcion, tipo: tipo, completado: completado,
                  todoDia: todoDia, horaFin: horaFin, lugar: lugar,
                  responsable: responsable, responsableId: responsableId,
                  ministerio: ministerio,
                  presupuesto: presupuesto, notaPie: notaPie, repeticion: repeticion,
                  estadoEvento: estadoEvento, esFechaImportante: esFechaImportante,
                  recordatorios: recordatorios)
    }

    init(id: String, fecha: String, hora: String?, titulo: String, descripcion: String,
         tipo: TipoEvento, completado: Bool,
         todoDia: Bool = false, horaFin: String? = nil, lugar: String = "",
         responsable: String = "", responsableId: String? = nil,
         ministerio: String = "", presupuesto: String = "",
         notaPie: String = "", repeticion: String = "", estadoEvento: String = "",
         esFechaImportante: Bool = false, recordatorios: [String] = []) {
        self.id = id; self.fecha = fecha; self.hora = hora
        self.titulo = titulo; self.descripcion = descripcion
        self.tipo = tipo; self.completado = completado
        self.todoDia = todoDia; self.horaFin = horaFin; self.lugar = lugar
        self.responsable = responsable; self.responsableId = responsableId
        self.ministerio = ministerio
        self.presupuesto = presupuesto; self.notaPie = notaPie
        self.repeticion = repeticion; self.estadoEvento = estadoEvento
        self.esFechaImportante = esFechaImportante; self.recordatorios = recordatorios
    }
}

// MARK: - Informes

struct MesAlta: Identifiable {
    let id: Int
    let mes: String
    let altas: Int
}

struct MovimientoTraslado: Identifiable {
    let id: Int
    let folio: String
    let tipoTraslado: String
    let persona: String
    let iglesia: String
    let fecha: String
    let estado: String
}

struct InformeResumen {
    let totalMiembros: Int
    let periodo: String
    let porEstado: [(String, Int)]
    let porMinisterio: [(String, Int)]
    let expedienteCompleto: Int
    let expedienteIncompleto: Int
    let altasPorMes: [MesAlta]
    let traslados: [MovimientoTraslado]
}
