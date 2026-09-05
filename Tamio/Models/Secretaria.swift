import SwiftUI

// MARK: - Actas

enum EstadoActa {
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
}

struct AcuerdoActa: Identifiable {
    let id: Int
    let texto: String
}

struct Acta: Identifiable, Hashable {
    let id: String
    let folio: String
    let tipo: String
    let fecha: String
    let acuerdos: Int
    var estado: EstadoActa
    let cuerpo: String
    let items: [AcuerdoActa]
    var tituloPersonalizado: String? = nil

    var titulo: String {
        if let t = tituloPersonalizado, !t.isEmpty { return t }
        return L.t("Acta \(folio) · \(tipo)", "Minutes \(folio) · \(tipo)")
    }
    var subtitulo: String {
        let ac = acuerdos > 0 ? " · \(acuerdos) \(L.t("acuerdos", "agreements"))" : ""
        return "\(fecha)\(ac) · \(estado.etiqueta.lowercased())"
    }

    static func == (l: Acta, r: Acta) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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

    private var fechaDate: Date? { Fechas.desdeTextoFlexible(fecha) }

    /// "DOM" · "SUN". Del formateador y no de una tabla: el día de la semana
    /// de una fecha no se traduce a mano.
    var diaSemana: String {
        guard let d = fechaDate else { return "" }
        return L.formateador("EEE").string(from: d).uppercased()
    }
    var numDia: String { fechaDate.map { String(Calendar.current.component(.day, from: $0)) } ?? "" }
    var fechaLegible: String { fecha.isEmpty ? "" : Fechas.diaLegible(fecha) }

    var estadoRoster: EstadoRoster {
        let asignados = puestos.filter(\.asignado).count
        if puestos.isEmpty || asignados == 0 { return .sinAsignar }
        return asignados == puestos.count ? .completo : .parcial
    }

    var subtitulo: String { "\(fechaLegible) · \(estadoRoster.etiqueta)" }

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
    // Legacy — kept for existing mock data
    case bautismo, bienvenida
    var id: String { rawValue }

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
        case .traslado:            return "arrow.right.doc.on.clipboard"
        case .personalizada:       return "doc.badge.plus"
        case .bautismo:            return "drop.circle"
        case .bienvenida:          return "hand.wave"
        }
    }
}

struct CartaEmitida: Identifiable {
    let id: String
    let iniciales: String
    let persona: String
    let tipo: TipoPlantilla
}

struct CartaEnEdicion {
    // Campos existentes (usados por el editor de detalle)
    var tipo: TipoPlantilla = .traslado
    var aportante: String = "Javier Medina Cruz"
    var iglesiaDestino: String = "Iglesia El Buen Pastor"
    var miembroDesde: String = "2018"
    var firma: String = "Pastor Abel Ramos"

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
}

struct EventoAgenda: Identifiable {
    let id: String
    let dia: Int
    let hora: String?
    let titulo: String
    let descripcion: String
    let tipo: TipoEvento
    let completado: Bool
    // Campos extendidos (con defaults para no romper mock existente)
    var todoDia: Bool = false
    var horaFin: String? = nil
    var lugar: String = ""
    var responsable: String = ""
    var ministerio: String = ""
    var presupuesto: String = ""
    var notaPie: String = ""
    var repeticion: String = ""
    var estadoEvento: String = ""
    var esFechaImportante: Bool = false
    var recordatorios: [String] = []
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
